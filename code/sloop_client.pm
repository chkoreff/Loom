use strict;
use api;
use archive;
use array;
use context;
use dttm;
use file;
use grid;
use html;
use http;
use id;
use loom_config;
use loom_db;
use loom_login;
use notify;
use page_archive_api;
use page_archive_tutorial;
use page_data;
use page_edit;
use page_folder;
use page_grid_api;
use page_grid_tutorial;
use page_help;
use page_test;
use page_tool;
use page_trade;
use page_view;
use page_wallet;
use random;
use sha256;
use sloop_io;
use sloop_top;
use token;
use trans;
use URI::Escape;

# LATER 20100325 Do a local install of all the prerequisite Perl modules.

# LATER 031810 make the entire server completely self-configuring upon
# installation.

# LATER 20110313 Even though Perl closes abandoned file handles automatically,
# let's put in code to close them explicitly, and include a counter of open
# files which must be zero at key places during the program run.

# LATER minimize coupling on these

my $g_title_text;
my $g_title_literal; # flag
my $g_focus_field;
my $g_need_keyboard;
my $g_printer_friendly;
my $g_top_links;
my $g_top_message;
my $g_body;
my $g_response_text;
my $g_cache_time;
my $g_cookie_text;
my $g_cookie_cache;
my $g_transaction_in_progress;

# LATER unify with read_http_headers

sub split_content
	{
	my $text = shift;

	my $header_op = op_new();
	my $header_end_pos = 0;
	my $headers = "";

	my $pos = 0;

	while (1)
		{
		my $index = index($text, "\012", $pos);
		last if $index < 0;

		my $line = substr($text,$pos,$index-$pos);
		$line =~ s/\015$//;  # strip trailing CR

		$pos = $index + 1;

		if ($line eq "")
			{
			$header_end_pos = $pos;
			last;
			}
		elsif ($line =~ /^([\w\-]+): (.+)/i)
			{
			# Looks like a header.

			my $key = $1;
			my $val = $2;

			op_put($header_op,$key,$val);

			$headers .= "$line\n";
			$header_end_pos = $pos;
			}
		elsif ($line ne "")
			{
			# We saw a line which does not look like a header, so
			# we must be inside the content now.

			last;
			}
		}

	if ($headers eq "")
		{
		return ($header_op,$headers,$text);
		}
	else
		{
		my $content = substr($text,$header_end_pos);
		return ($header_op,$headers,$content);
		}
	}

sub loom_get_cookie
	{
	my $key = shift;

	if (!defined $g_cookie_cache)
		{
		my $cookie_line = http_header("Cookie");

		my @pairs =
			map { split(/=/,$_) }
			split(/\s*;\s*/,trimblanks($cookie_line));

		$g_cookie_cache = op_new(@pairs);
		}

	return op_get($g_cookie_cache,$key);
	}

sub loom_put_cookie
	{
	my $key = shift;
	my $val = shift;
	my $timeout = shift;  # in seconds (optional)

	my $this_url = loom_config("this_url");
	my $host = http_header("Host");

	my $server_name = $host;
	$server_name =~ s/:\d+$//; # strip off port number if present

	my $cookie_domain = ".$server_name";
	my $cookie_path = "/";
	my $cookie_secure = ($this_url =~ /^https:/);

	my $expires = "";
	if (defined $timeout)
		{
		my $time = time + $timeout;
		my $dttm = dttm_as_cookie($time);
		$expires = " expires=$dttm";
		}

	my $secure = $cookie_secure ? " secure;" : "";

	$g_cookie_text .=
		"Set-Cookie: $key=$val;$secure domain=$cookie_domain; "
		."path=$cookie_path;"
		."$expires\n";

	return;
	}

sub format_HTTP_response
	{
	my $response_code = shift;
	my $headers = shift;
	my $content = shift;

	my $content_length = length($content);

	$g_response_text = "";
	$g_response_text = "HTTP/1.1 $response_code\n";
	$g_response_text .= $headers;

	$g_response_text .= $g_cookie_text;
	$g_response_text .=
		"Cache-Control: max-age=$g_cache_time; must-revalidate\n"
		if $g_cache_time ne "";

	$g_response_text .= "Content-Length: $content_length\n";
	$g_response_text .= "\n";
	$g_response_text .= $content;

	return;
	}

# See if the page has any content headers.  If so, don't change anything.  If
# not, put Content-Type: text/plain on the front so it renders properly.

sub page_HTTP
	{
	my $response_code = shift;
	my $page = shift;

	my ($header_op,$headers,$content) = split_content($page);

	if ($headers eq "")
		{
		# No headers, use text/plain by default.
		$headers = "Content-Type: text/plain\n";
		}

	format_HTTP_response($response_code,$headers,$content);
	return;
	}

sub page_ok
	{
	my $page = shift;

	page_HTTP("200 OK", $page);
	}

sub page_not_found
	{
	my $page = <<EOM;
Content-Type: text/html

<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<html>
<head> <title>404 Not Found</title> </head>
<body>
<h1>Not Found</h1>
The requested URL was not found on this server.
</body>
</html>
EOM

	page_HTTP("404 Not Found",$page);

	sloop_disconnect();

	return;
	}

sub set_title
	{
	my $title = shift;

	$g_title_text = html_quote($title);
	$g_title_literal = 0;
	return;
	}

sub set_title_literal
	{
	my $title = shift;

	$g_title_text = html_quote($title);
	$g_title_literal = 1;
	return;
	}

sub get_title
	{
	return $g_title_text;
	}

sub set_focus
	{
	my $name = shift;

	$g_focus_field = $name;
	}

sub need_keyboard
	{
	$g_need_keyboard = 1;
	}

# LATER perhaps a standard Print link for printer-friendly versions of all
# pages.
sub printer_friendly
	{
	$g_printer_friendly = 1;
	}

sub top_message
	{
	my $text = shift;

	$g_top_message = $text;
	}

sub top_link
	{
	my $link = shift;

	push @$g_top_links, $link;
	return;
	}

# Conditionally highlighted link.

sub highlight_link
	{
	my $url = shift;
	my $label = shift;
	my $highlight = shift;
	my $title = shift;  # optional

	$title = "" if !defined $title;
	$title = qq{ title="$title"} if $title ne "";

	my $style = $highlight ? " class=highlight_link" : "";
	my $link = qq{<a$style href="$url"$title>$label</a>};
	return $link;
	}

sub simple_value_selector
	{
	my $field = shift;
	my $label = shift;
	my $values = shift;

	my $selector = "";

	$selector .= <<EOM;
<select name=$field>
<option value="">$label</option>
EOM

	for my $value (@$values)
		{
		my $q_value = html_quote($value);

		my $selected = "";
		$selected = " selected" if http_get($field) eq $value;

		$selector .= <<EOM;
<option$selected value="$q_value">$q_value</option>
EOM
		}

	$selector .= <<EOM;
</select>
EOM

	return $selector;
	}

# Check the session parameter for validity.  XOR it with the mask cookie to
# reveal the real session id.  Validate the real session id.  If it's good,
# return it.  If not, clear the session parameter and return null.

sub loom_check_session
	{
	my $masked_session = http_get("session");
	my $mask = loom_get_cookie("mask");

	if (valid_id($masked_session) && valid_id($mask))
		{
		my $real_session = xor_hex($masked_session,$mask);

		if (valid_session($real_session))
			{
			# Session is valid.  Return it.
			return $real_session;
			}
		}

	# Session is not valid.  Clear the parameter and return null.
	http_put("session","");
	return "";
	}

sub loom_clear_state
	{
	set_title("");

	$g_focus_field = "";
	$g_body = "";
	$g_response_text = "";

	$g_printer_friendly = 0;
	$g_need_keyboard = 0;

	$g_top_links = [];
	$g_top_message = "";

	$g_cache_time = "";
	$g_cookie_text = "";
	$g_cookie_cache = undef;

	return;
	}

sub emit
	{
	my $text = \shift; # pass by reference to avoid copy
	$g_body .= $$text;
	return;
	}

# The transactional API is:
#
#    /trans/begin
#    /trans/commit
#    /trans/cancel
#
# This returns results in KV format.
#
# You can also do transactions interactively, in HTML, by using "trans_web"
# instead of "trans".

sub page_trans_respond
	{
	my @path = http_split_path(http_path());
	my $format = shift @path;

	die if $format ne "trans" && $format ne "trans_web";

	my $action = shift @path;
	$action = "" if !defined $action;

	my $api = op_new();
	op_put($api,"action",$action);

	if ($action eq "begin")
		{
		op_put($api,"status",$g_transaction_in_progress ? "fail" : "success");
		$g_transaction_in_progress = 1;
		}
	elsif ($action eq "commit")
		{
		my $ok = trans_commit();
		op_put($api,"status", $ok ? "success" : "fail");
		$g_transaction_in_progress = 0;
		}
	elsif ($action eq "cancel")
		{
		op_put($api,"status","success");
		trans_cancel();
		$g_transaction_in_progress = 0;
		}
	else
		{
		op_put($api,"status","fail");
		op_put($api,"error_action","unknown");
		}

	if ($format eq "trans")
		{
		# Return result in KV format.
		my $response_code = "200 OK";
		my $headers = "Content-Type: text/plain\n";
		my $text = op_write_kv($api);
		format_HTTP_response($response_code,$headers,$text);
		}
	elsif ($format eq "trans_web")
		{
		# Return result in HTML format.

		my $action = op_get($api,"action");
		my $status = op_get($api,"status");

		if ($action eq "begin")
			{
			set_title("Transaction");

			emit(<<EOM
<h1> Transaction in Progress </h1>
EOM
);
			emit(<<EOM
<p>
You have started a new transaction.
EOM
) if $status eq "success";
			emit(<<EOM
<p>
You already have a transaction in progress.
EOM
) if $status eq "fail";
			emit(<<EOM
<p>
Now you can now go off and do any series of operations you like.  Use the link
below if you'd like to start fresh.  Or, if you already have a window or tab
open, you can go there and do the operations.

<p style='margin-left:20px'>
<a href="/" target=_new> Visit Home page in a new window. </a>
<p>
When you're done, come back to this window and either commit or cancel the
transaction.
<p style='margin-left:20px; margin-top:30px;'>
<a href="/trans_web/commit"> Commit the transaction (save all changes). </a>
<p style='margin-left:20px; margin-top:30px;'>
<a href="/trans_web/cancel"> Cancel the transaction (discard all changes). </a>
EOM
);
			}
		elsif ($action eq "commit")
			{
			if ($status eq "success")
			{
			emit(<<EOM
<h1> Transaction Committed </h1>
<p>
The transaction was committed successfully.
EOM
);
			}
			else
			{
			emit(<<EOM
<h1> Transaction Failed </h1>
<p>
It was not possible to commit the transaction because some other process made
some changes while the transaction was in progress.  Perhaps someone else is
changing this same data from another web browser.
EOM
);
			}

			}
		elsif ($action eq "cancel")
			{
			emit(<<EOM
<h1> Transaction Canceled </h1>
<p>
The transaction has been canceled.
EOM
);
			}

		if ($action eq "commit" || $action eq "cancel")
			{
			emit(<<EOM
<p style='margin-left:20px'>
<a href="/trans_web/begin"> Start a new transaction. </a>
<p style='margin-left:20px'>
<a href="/"> Return to Home page. </a>
EOM
);
			}
		}

	return;
	}

sub showing_maintenance_page
	{
	return 0 if !in_maintenance_mode();

	http_put("error_system","maintenance");

	my $system_name = loom_config("system_name");

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

	page_ok($page);

	return 1;
	}

sub interpret_archive_slot
	{
	my $id = shift;

	my $content = archive_get($id);
	my ($header_op,$header_text,$payload) = split_content($content);

	my $content_type = op_get($header_op,"Content-Type");
	$content_type = op_get($header_op,"Content-type")
		if $content_type eq "";

	if ($content_type eq "standard-page")
		{
		my $title = op_get($header_op,"Title");
		set_title_literal($title);
		emit($payload);

		top_link(highlight_link(top_url(), "Home"));

		top_link(highlight_link(
			http_path(),
			get_title(),1));
		}
	elsif ($content_type eq "loom-trade-page")
		{
		page_trade_respond($id,$header_op,$payload);
		}
	else
		{
		page_not_found();
		}
	}

# LATER: Normalize the internal redirect mechanism as well, or make it
# unnecessary.

sub loom_dispatch
	{
	loom_clear_state();

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
	#my $user_agent = http_header("User-Agent");
	#print STDERR "user_agent=$user_agent\n";
	#}

	# Internally resolve any defined paths.

	my $resolved = 0;
	my $counter = 0;

	my $path = http_path();

	while (!$resolved)
	{
	$resolved = 1;
	$counter++;

	last if $counter > 16;  # impose max 16 redirects

	my @path = http_split_path($path);
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
			page_not_found();
			return;
			}

		if ($hash =~ /^([^.]*)\.(.*)$/)
			{
			my $prefix = $1;
			my $suffix = $2;  # ignore suffix

			$hash = $prefix;
			}

		http_put("function",$function);
		http_put("hash",$hash);
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
			page_not_found();
			return;
			}

		$g_cache_time = $time;

		$path = join("/",@path);
		$resolved = 0;
		}
	elsif ($function eq "data")
		{
		my $name = shift @path;

		if (!defined $name)
			{
			page_not_found();
			return;
			}

		http_put("function",$function);
		http_put("name",$name);
		}
	else
		{
		# LATER this is the only case where you can get infinite loops.
		# All we have to do is reduce the alias to a form which is
		# resolved *outside* of this loop, down below.  That is, the
		# alias is just a single mapping operation.
		#
		# We currently use this for favicon.ico and nav_logo.

		my $alias = loom_config("alias/$function");

		if ($alias ne "")
			{
			$path = $alias;
			$resolved = 0;
			}
		else
			{
			# If we don't find an alias for this leg of the path, just put it
			# in the "function" key and drop into the normal processing below.
			#
			# LATER: we could implement full positional notation for all
			# functions, besides just the few we've done.

			http_put("function",$function);
			}
		}
	}

	my $name = http_get("function");

	if ($name eq "folder" || $name eq "contact" || $name eq "asset"
		|| $name eq "")
		{
		page_folder_respond();
		}
	elsif ($name eq "grid")
		{
		page_grid_api_respond();
		}
	elsif ($name eq "archive")
		{
		page_archive_api_respond();
		}
	elsif ($name eq "trans" || $name eq "trans_web")
		{
		page_trans_respond();
		}
	elsif ($name eq "view")
		{
		page_view_respond();
		}
	elsif ($name eq "edit" || $name eq "upload")
		{
		page_edit_respond();
		}
	elsif ($name eq "data")
		{
		page_data_respond();
		}
	elsif ($name eq "folder_tools")
		{
		page_tool_respond();
		}
	elsif ($name eq "archive_tutorial")
		{
		page_archive_tutorial_respond();
		}
	elsif ($name eq "grid_tutorial")
		{
		page_grid_tutorial_respond();
		}
	elsif ($name eq "test")
		{
		page_test_respond();
		}
	elsif ($name eq "random")
		{
		my $id = unpack("H*",random_id());

		my $api = op_new();
		op_put($api,"function",$name);
		op_put($api,"value",$id);

		my $response_code = "200 OK";
		my $headers = "Content-Type: text/plain\n";
		my $result = op_write_kv($api);

		format_HTTP_response($response_code,$headers,$result);
		}
	elsif ($name eq "hash")
		{
		my $api = op_new();
		op_put($api,"function",$name);

		my $input = http_get("input");

		my $hash = sha256($input);
		my $id = substr($hash,0,16) ^ substr($hash,16,16);
		$id = unpack("H*",$id);

		op_put($api,"input",$input);
		op_put($api,"sha256_hash",unpack("H*",$hash));
		op_put($api,"folded_hash",$id);

		my $response_code = "200 OK";
		my $headers = "Content-Type: text/plain\n";
		my $result = op_write_kv($api);

		format_HTTP_response($response_code,$headers,$result);
		}
	elsif ($name eq "object")
		{
		my @path = http_split_path($path);
		shift @path;
		my $id = shift @path;
		interpret_archive_slot($id);
		}
	else
		{
		my $id = loom_config("link/$name");
		if ($id eq "")
			{
			page_not_found();
			}
		else
			{
			interpret_archive_slot($id);
			}
		}

	return;
	}

sub loom_top_navigation_bar
	{
	my $dsp_links = "";
	for my $link (@$g_top_links)
		{
		next if !defined $link || $link eq "";
		$dsp_links .= qq{<span style='padding-right:15px'>$link</span>\n};
		}

	my $nav_logo_stanza = loom_config("nav_logo_stanza");

	if ($nav_logo_stanza eq "")
		{
		$nav_logo_stanza = "<td></td>\n";
		}

	my $result = "";
	$result .= <<EOM;
<div id=navigation>
<table border=0 width="100%" cellpadding=0 cellspacing=0>
<colgroup>
<col>
<col width="100%">
</colgroup>
<tr>
$nav_logo_stanza
<td>
$dsp_links
</td>
</tr>
EOM
	if ($g_top_message ne "")
		{
		$result .= <<EOM;
<tr>
<td colspan=2>
$g_top_message
</td>
</tr>
EOM
		}
	$result .= <<EOM;
</table>

</div>
EOM

	return $result;
	}

sub loom_render_page
	{
	return if $g_response_text ne "";

	my $onload_clause = "";
	$onload_clause = qq{ onload="document.forms[0].$g_focus_field.focus()"}
		if $g_focus_field ne "";

	my $system_name = loom_config("system_name");
	my $title = get_title();
	$title = $g_title_literal ? $title : "$system_name $title";

	# Conditional javascript keyboard.

	my $keyboard_script = "";

	if ($g_need_keyboard)
		{
		$keyboard_script .= <<EOM;
<script type="text/javascript" src="/cache/7200/data/keyboard.js" charset="UTF-8"></script>
<link rel="stylesheet" href="/cache/7200/data/keyboard.css" type="text/css">
EOM
		}

	my $payload = "";

	# Allow optional "base ref" clause in case someone is running the Loom
	# server behind a front-end that uses some other root path.
	my $base_clause = "";
	if (loom_config("use_base"))
		{
		my $this_url = loom_config("this_url");
		$base_clause = qq{<base href="$this_url">\n};
		}

	$payload .= <<EOM;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN">
<html>
<head>
$base_clause<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
<meta http-equiv="Content-Language" content="en-us">
<meta name="description" content="$system_name">
<meta name="keywords" content="CMS content-management gold payment freedom">
<title>$title</title>
<link rel="stylesheet" href="/cache/7200/data/style.css" type="text/css">
$keyboard_script
</head>
<body style='max-width:700px'$onload_clause>
EOM

	$payload .= loom_top_navigation_bar() if !$g_printer_friendly;

	$payload .= <<EOM;
<div id=content>
$g_body
</div>
</body>
</html>
EOM

	my $response_code = "200 OK";
	my $headers = "Content-Type: text/html\n";

	format_HTTP_response($response_code,$headers,$payload);
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

	page_HTTP("413 Request Entity Too Large", $page);
	trans_cancel();
	$g_transaction_in_progress = 0;
	sloop_disconnect();
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

	page_HTTP("409 Conflict", $page);
	trans_cancel();
	$g_transaction_in_progress = 0;
	sloop_disconnect();
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
# (file_update).  If the commit succeeds, it means that all the values we
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

sub sloop_client_respond
	{
	# Initialize the transaction.

	my $dir = file_child(sloop_top(),"data/app");
	file_restrict($dir);

	trans_init($dir);

	# Flag which tracks if this client process is doing an ACID transaction.
	# (Atomicity, Consistency, Isolation, Durability)

	$g_transaction_in_progress = 0;

	# This loop reads successive HTTP messages from the client and sends
	# responses, possibly altering the DB in the process.

	while (1)
		{
		# First clear the HTTP input buffer so it will read more bytes from
		# the client.

		http_clear();

		# This next inner loop reads the HTTP message, dispatches, and tries to
		# commit any DB changes.  If the commit succeeds it exits the loop.
		# If the commit fails it loops back again and replays the request,
		# reading the same message bytes we read the first time.

		my $max_commit_failure = 1000;
		my $count_commit_failure = 0;

		while (1)
			{
			return if !http_read_message();

			loom_dispatch();  # This handles the message.

			if ($g_transaction_in_progress)
				{
				# See if current transaction size exceeds maximum.
				my $max_size = 2097152; # 2^21 bytes (2 MiB)

				my $cur_size = trans_size();
				if ($cur_size > $max_size)
					{
					transaction_too_large();
					}

				last;
				}
			elsif (trans_commit())
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

		loom_render_page();
		sloop_send($g_response_text);

		#sloop_disconnect(); # for testing

		return if sloop_exiting();
		}

	return;
	}

return 1;
