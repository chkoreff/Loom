package sloop_client;
use strict;
use archive;
use context;
use dttm;
use file;
use html;
use http;
use loom_config;
use notify;
use page;
use page_archive_api;
use page_archive_tutorial;
use page_data;
use page_folder;
use page_grid_api;
use page_grid_tutorial;
use page_test;
use page_tool;
use page_view;
use page_wallet;
use random;
use sloop_io;
use sloop_top;
use trans;

my $g_transaction_in_progress;

sub showing_maintenance_page
	{
	return 0 if !notify::in_maintenance_mode();

	http::put("error_system","maintenance");

	my $system_name = loom_config::get("system_name");

	my $page = <<EOM;
Content-Type: text/html

<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<HTML><HEAD>
<TITLE>503 Service Unavailable</TITLE>
</HEAD><BODY>
<H1>Service Unavailable</H1>
$system_name is currently down for maintenance.
</BODY></HTML>
EOM

	page::ok($page);
	return 1;
	}

sub loom_dispatch
	{
	page::clear();

	return if showing_maintenance_page();

	# LATER 1205 Adapt to mobile devices by looking at the User-Agent header.
	# For example when coming from iPhone we see something like this:
	#
	#   Mozilla/5.0 (iPhone; U; CPU iPhone OS 4_1 like Mac OS X; en-us)
	#   AppleWebKit/532.9 (KHTML, like Gecko) Version/4.0.5 Mobile/8B117
	#   Safari/6531.22.7
	#
	# But when coming from an ordinary browser we might see:
	#
	#   Mozilla/5.0 (X11; U; Linux x86_64; en-US; rv:1.9.2.12)
	#   Gecko/20101027
	#   Ubuntu/10.04 (lucid)
	#   Firefox/3.6.12
	#{
	#my $user_agent = http::header("User-Agent");
	#print STDERR "user_agent=$user_agent\n";
	#}

	# Internally resolve any defined paths.

	my $resolved = 0;
	my $counter = 0;

	my $path = sloop_config::logical_path();

	while (!$resolved)
	{
	$resolved = 1;
	$counter++;

	last if $counter > 16;  # impose max 16 redirects

	my @path = http::split_path($path);
	my $function = shift @path;

	if (!defined $function)
		{
		}
	elsif ($function eq "view")
		{
		# We allow paths like these:
		#
		#   /view/$hash
		#   /view/$hash.tar.gz
		#   /view/$hash/lib.tar.gz
		#
		# The suffix is useful for telling the browser what type of document
		# this is and a suggested name for saving it.

		my $hash = shift @path;

		if (!defined $hash)
			{
			page::not_found();
			return;
			}

		if ($hash =~ /^([^.]*)\.(.*)$/)
			{
			my $prefix = $1;
			my $suffix = $2;  # ignore suffix

			$hash = $prefix;
			}

		http::put("function",$function);
		http::put("hash",$hash);
		}
	elsif ($function eq "cache")
		{
		# Allow cache control with a path like this:
		#    /cache/3600/$path
		#
		# Note that we use urls like /cache/7200/data/style.css

		my $time = shift @path;
		if (!defined $time || $time !~ /^\d{1,8}$/)
			{
			page::not_found();
			return;
			}

		page::set_cache_time($time);

		$path = join("/",@path);
		$resolved = 0;
		}
	elsif ($function eq "data")
		{
		my $name = shift @path;

		if (!defined $name)
			{
			page::not_found();
			return;
			}

		http::put("function",$function);
		http::put("name",$name);
		}
	else
		{
		http::put("function",$function);
		}
	}

	my $name = http::get("function");

	if ($name eq "folder" || $name eq "contact" || $name eq "asset"
		|| $name eq "")
		{
		page_folder::respond();
		}
	elsif ($name eq "grid")
		{
		page_grid_api::respond();
		}
	elsif ($name eq "archive")
		{
		page_archive_api::respond();
		}
	elsif ($name eq "view")
		{
		page_view::respond();
		}
	elsif ($name eq "data")
		{
		page_data::respond();
		}
	elsif ($name eq "folder_tools")
		{
		page_tool::respond();
		}
	elsif ($name eq "archive_tutorial")
		{
		page_archive_tutorial::respond();
		}
	elsif ($name eq "grid_tutorial")
		{
		page_grid_tutorial::respond();
		}
	elsif ($name eq "test")
		{
		page_test::respond();
		}
	elsif ($name eq "help")
		{
		require page_faq;
		page_faq::respond();
		}
	elsif ($name eq "random")
		{
		my $id = random::hex();

		my $api = context::new();
		context::put($api,"function",$name);
		context::put($api,"value",$id);

		my $response_code = "200 OK";
		my $headers = "Content-Type: text/plain\n";
		my $result = context::write_kv($api);

		page::format_HTTP_response($response_code,$headers,$result);
		}
	elsif ($name eq "hash")
		{
		my $api = context::new();
		context::put($api,"function",$name);

		my $input = http::get("input");

		my $hash = sha256::bin($input);
		my $id = substr($hash,0,16) ^ substr($hash,16,16);
		$id = unpack("H*",$id);

		context::put($api,"input",$input);
		context::put($api,"sha256_hash",unpack("H*",$hash));
		context::put($api,"folded_hash",$id);

		my $response_code = "200 OK";
		my $headers = "Content-Type: text/plain\n";
		my $result = context::write_kv($api);

		page::format_HTTP_response($response_code,$headers,$result);
		}
	else
		{
		page::not_found();
		}

	return;
	}

sub transaction_too_large
	{
	my $page = <<EOM;
Content-Type: text/html

<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<html>
<head> <title>413 Transaction Too Large</title> </head>
<body>
<h1>Transaction Too Large</h1>
Your request was too large for the server to store in memory safely.
</body>
</html>
EOM

	page::HTTP("413 Request Entity Too Large", $page);
	trans::cancel();
	$g_transaction_in_progress = 0;
	sloop_io::disconnect();
	return;
	}

sub transaction_conflict
	{
	my $page = <<EOM;
Content-Type: text/html

<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<html>
<head> <title>409 Transaction Conflict</title> </head>
<body>
<h1>Transaction Conflict</h1>
Your request was trying to modify data while too many other processes were also
modifying that same data.  We had to give up, but you can try again later.
</body>
</html>
EOM

	page::HTTP("409 Conflict", $page);
	trans::cancel();
	$g_transaction_in_progress = 0;
	sloop_io::disconnect();
	return;
	}

# This routine handles the entire interaction with a single client process from
# start to finish.
#
# The database provides simple "get" and "put" routines only.  This allows the
# core logic of the system to behave as if it has exclusive control of a simple
# key-value data store, with no other processes changing values "under its
# feet" so to speak.
#
# We can maintain that illusion because, after the core logic is complete, we
# commit the database changes with the robust "parallel update" routine
# (file::update).  If the commit succeeds, it means that all the values we
# originally read from the file system remained untouched by other processes
# while we were deciding what changes to make, and all of our changes were
# successfully written with proper locking to ensure data integrity and avoid
# deadlock.
#
# If the commit fails, it means that at least one value changed under our feet
# while we were deciding what changes to make.  In that case we loop around and
# run the original query over again as if nothing had happened.  We keep doing
# this until the commit finally succeeds, which the laws of probability
# guarantee will happen eventually, even in a very busy system with several
# processes trying to update the same things.  See the "test_file" program
# for a very thorough stress test of this principle.

sub respond
	{
	# Initialize the transaction.

	my $dir = file::child(sloop_top::dir(),"data/app");
	file::restrict($dir);

	trans::start($dir);

	# Flag which tracks if this client process is doing an ACID transaction.
	# (Atomicity, Consistency, Isolation, Durability)

	$g_transaction_in_progress = 0;

	# This loop reads successive HTTP messages from the client and sends
	# responses, possibly altering the DB in the process.

	while (1)
		{
		# First clear the HTTP input buffer so it will read more bytes from
		# the client.

		http::clear();

		# This next inner loop reads the HTTP message, dispatches, and tries to
		# commit any DB changes.  If the commit succeeds it exits the loop.
		# If the commit fails it loops back again and replays the request,
		# reading the same message bytes we read the first time.

		my $max_commit_failure = 1000;
		my $count_commit_failure = 0;

		while (1)
			{
			return if !http::read_message();

			loom_dispatch();  # This handles the message.

			if ($g_transaction_in_progress)
				{
				# See if current transaction size exceeds maximum.
				my $max_size = 2097152; # 2^21 bytes (2 MiB)

				my $cur_size = trans::size();
				if ($cur_size > $max_size)
					{
					transaction_too_large();
					}

				last;
				}
			elsif (trans::commit())
				{
				last;
				}
			else
				{
				# Commit failed because some data changed under our feet.
				# Loop back around and handle the same message again.
				# We impose a limit on number of failures.  It could
				# be that we failed because too many files were open, or
				# some other error besides read inconsistency.

				$count_commit_failure++;

				#print "$$ ($count_commit_failure/$max_commit_failure) "
				#	."commit failed let's retry\n";

				if ($count_commit_failure >= $max_commit_failure)
					{
					transaction_conflict();
					last;
					}
				}
			}

		# Now that we have successfully read a message from the client, handled
		# the message, and committed any database changes, let's send our
		# response to the client.

		page::send_response();

		#sloop_io::disconnect(); # for testing

		return if sloop_io::exiting();
		}

	return;
	}

return 1;
