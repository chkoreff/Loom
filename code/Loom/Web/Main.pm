package Loom::Web::Main;
use strict;
use Loom::Context;
use Loom::DB::Trans;
use Loom::DB::GNU;
use Loom::Dttm;
use Loom::File;
use Loom::HTML;
use Loom::ID;
use Loom::KV;
use Loom::Load;
use Loom::Random;
use Loom::Sloop::HTTP::Parse;
use Loom::Web::API;
use Loom::Web::Login;  # LATER  need this here, or move down into Folder?
use URI::Escape;

# LATER 0325 Let's do a local install of all the prerequisite Perl modules.

# LATER 0325 Let's not "use" all the modules right away here.  That way if some
# some modules are missing the self-test will get a chance to run and report
# them cleanly.  As it stands the code just dies if something like
# Crypt::Rijndael is missing.

# LATER 0318 object system.  Maps public object id to private archive id.
# Interpret the private archive text according to first leg of URL path, e.g.
# "shop", and verify that Content-type is compatible with that.  

sub new
	{
	my $class = shift;
	my $arena = shift;

	my $s = bless({},$class);
	$s->{arena} = $arena;

	$s->{client} = $arena->{client};

	$s->{TOP} = $arena->{top}->full_path;

	$s->{id} = Loom::ID->new;
	$s->{html} = Loom::HTML->new;

	# This is the database used throughout the system.
	$s->{db} = Loom::DB::GNU->new("$s->{TOP}/data/app/loom.db");

	$s->{notify_path} = "$s->{TOP}/data/run";

	# Establish random number generator.
	$s->{random} = Loom::Random->new;

	# Establish the main loom API used in this server.
	$s->{loom} = Loom::Web::API->new($s->{db});

	# Establish the standard apparatus for passphrase and session handling.
	$s->{login} = Loom::Web::Login->new($s->{loom});

	# Dynamic loader.
	$s->{load} = Loom::Load->new;

	$s->{http} = Loom::Sloop::HTTP::Parse->new($s->{client});

	# Flag which tracks if this client process is doing an ACID transaction.
	# (Atomicity, Consistency, Isolation, Durability)

	$s->{transaction_in_progress} = 0;

	$s->configure;

	return $s;
	}

# This routine handles the entire interaction with a single client process from
# start to finish.

sub respond
	{
	my $s = shift;

	# This next outer loop reads successive HTTP messages from the client and
	# sends responses, possibly altering the DB in the process.

	while (1)
		{
		# First clear the HTTP input buffer so it will read more bytes from
		# the client.

		$s->{http}->clear;

		# This next inner loop reads the HTTP message, dispatches, and tries to
		# commit any DB changes.  If the commit succeeds it exits the loop.
		# If the commit fails it loops back again and replays the request,
		# reading the same message bytes we read the first time.

		while (1)
			{
			return if !$s->{http}->read_complete_message;

			$s->dispatch;  # This handles the message.

			last if $s->{transaction_in_progress};  # Don't commit yet.
			last if $s->{db}->commit;

			# Commit failed because some data changed under our feet.
			# Loop back around and handle the same message again.

			# LATER test this point (commit failure in busy system)
			#print "$$ commit failed, let's retry\n";
			}

		# Now that we have successfully read a message from the client, handled
		# the message, and committed any database changes, let's send our
		# response to the client.

		$s->render_page;
		$s->{client}->send($s->{response_text});

		return if $s->{client}->exiting;
		}
	}

# Read the basic system configuration from the data/conf/loom file.

sub configure
	{
	my $s = shift;

	# Read the configuration parameters from the archive (in KV format).

	my $text = Loom::File->new("$s->{TOP}/data/conf/loom")->get;
	my $config_id = Loom::KV->new->hash($text)->{config_id};

	$s->{config} = Loom::Context->read_kv( $s->archive_get($config_id) );

	$s->set_default_config("odd_row_color","#f6e8b9");
	$s->set_default_config("even_row_color","#ebddae");

	return;
	}

# Set a default value for a given key in the system-wide configuration.  If
# the key has not already been set, set it to the default.

sub set_default_config
	{
	my $s = shift;
	my $key = shift;
	my $default = shift;

	my $current = $s->{config}->get($key);
	return if $current ne "";

	$s->{config}->put($key,$default);

	return;
	}

sub clear_state
	{
	my $s = shift;

	$s->set_title("");

	$s->{focus_field} = "";
	$s->{body} = "";
	$s->{response_text} = "";

	$s->{printer_friendly} = 0;
	$s->{need_keyboard} = 0;

	$s->{top_links} = [];
	$s->{nav_message} = "";

	$s->{cache_time} = "";
	$s->{cookie_text} = "";
	$s->{cookie_cache} = undef;

	return;
	}

# LATER: Normalize the internal redirect mechanism as well, or make it
# unnecessary.

sub dispatch
	{
	my $s = shift;

	$s->clear_state;

	return if $s->showing_maintenance_page;

	my $op = $s->{http}->op;
	$s->{op} = $op;

	# Internally resolve any defined paths.

	$s->{resolved} = 0;
	$s->{counter} = 0;

	my $path = $s->{http}->path;

	while (!$s->{resolved})
	{
	$s->{resolved} = 1;
	$s->{counter}++;

	last if $s->{counter} > 16;  # impose max 16 redirects

	my @path = $s->split_path($path);
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
			$s->page_not_found;
			return;
			}

		if ($hash =~ /^([^.]*)\.(.*)$/)
			{
			my $prefix = $1;
			my $suffix = $2;  # ignore suffix

			$hash = $prefix;
			}

		$op->put("function",$function);
		$op->put("hash",$hash);
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
			$s->page_not_found;
			return;
			}

		$s->{cache_time} = $time;

		$path = join("/",@path);
		$s->{resolved} = 0;
		}
	elsif ($function eq "data")
		{
		my $name = shift @path;

		if (!defined $name)
			{
			$s->page_not_found;
			return;
			}

		$op->put("function",$function);
		$op->put("name",$name);
		}
	else
		{
		# LATER this is the only case where you can get infinite loops.
		# All we have to do is reduce the alias to a form which is
		# resolved *outside* of this loop, down below.  That is, the
		# alias is just a single mapping operation.

		my $alias = $s->{config}->get("alias/$function");

		if ($alias ne "")
			{
			$path = $alias;
			$s->{resolved} = 0;
			}
		else
			{
			# If we don't find an alias for this leg of the path, just put it
			# in the "function" key and drop into the normal processing below.
			#
			# LATER: we could implement full positional notation for all
			# functions, besides just the few we've done.

			$op->put("function",$function);
			}
		}
	}

	my $name = $op->get("function");

	if ($name eq "folder" || $name eq "contact" || $name eq "asset"
		|| $name eq "")
		{
		$s->object("Loom::Web::Page_Folder",$s)->respond;
		}
	elsif ($name eq "grid")
		{
		$s->object("Loom::Web::Page_Grid_API",$s)->respond;
		}
	elsif ($name eq "archive")
		{
		$s->object("Loom::Web::Page_Archive_API",$s)->respond;
		}
	#elsif ($name eq "api" || $name eq "web")
	#	{
	#	$s->do_api;
	#	}
	elsif ($name eq "view")
		{
		$s->object("Loom::Web::Page_View",$s)->respond;
		}
	elsif ($name eq "edit" || $name eq "upload")
		{
		$s->object("Loom::Web::Page_Edit",$s)->respond;
		}
	elsif ($name eq "data")
		{
		$s->object("Loom::Web::Page_Data",$s)->respond;
		}
	elsif ($name eq "folder_tools")
		{
		$s->object("Loom::Web::Page_Tool",$s)->respond;
		}
	elsif ($name eq "archive_tutorial")
		{
		$s->object("Loom::Web::Page_Archive_Tutorial",$s)->respond;
		}
	elsif ($name eq "grid_tutorial")
		{
		$s->object("Loom::Web::Page_Grid_Tutorial",$s)->respond;
		}
	elsif ($name eq "test")
		{
		$s->object("Loom::Web::Page_Test",$s)->respond;
		}
	elsif ($name eq "news")
		{
		$s->object("Loom::Web::Page_Std",$s,
			$s->{config}->get("news_page"),"News")->respond;
		}
	elsif ($name eq "merchants")
		{
		$s->object("Loom::Web::Page_Std",$s,
			$s->{config}->get("merchants_page"), "Merchants")->respond;
		}
	elsif ($name eq "faq")
		{
		$s->object("Loom::Web::Page_Std",$s,
			$s->{config}->get("faq_page"), "FAQ")->respond;
		}
	else
		{
		$s->page_not_found;
		}

	return;
	}

# LATER This is disabled for now because it only makes sense after we've ported
# the data to the new file system approach with optimistic concurrency.
sub do_api
	{
	my $s = shift;

	my @path = $s->split_path($s->{http}->path);
	my $format = shift @path;

	die if $format ne "api" && $format ne "web";

	my $action = shift @path;
	$action = "" if !defined $action;

	my $api = Loom::Context->new;
	$api->put("action",$action);

	if ($action eq "begin")
		{
		$api->put("status",$s->{transaction_in_progress} ? "fail" : "success");
		$s->{transaction_in_progress} = 1;
		}
	elsif ($action eq "commit")
		{
		my $ok = $s->{db}->commit;
		$api->put("status", $ok ? "success" : "fail");
		$s->{transaction_in_progress} = 0;
		}
	elsif ($action eq "cancel")
		{
		$api->put("status","success");
		$s->{db}->cancel;
		$s->{transaction_in_progress} = 0;
		}
	else
		{
		$api->put("status","fail");
		$api->put("error_action","unknown");
		}

	if ($format eq "api")
		{
		# Return result in KV format.
		my $response_code = "200 OK";
		my $headers = "Content-type: text/plain\n";
		my $text = $api->write_kv;
		$s->format_HTTP_response($response_code,$headers,$text);
		}
	elsif ($format eq "web")
		{
		# Return result in HTML format.

		my $action = $api->get("action");
		my $status = $api->get("status");

		if ($action eq "begin")
			{
			$s->set_title("Transaction");

			$s->{body} .= <<EOM;
<h1> Transaction in Progress </h1>
EOM
			$s->{body} .= <<EOM if $status eq "success";
<p>
You have started a new transaction.
EOM
			$s->{body} .= <<EOM if $status eq "fail";
<p>
You already have a transaction in progress.
EOM
			$s->{body} .= <<EOM;
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
<a href="/web/commit"> Commit the transaction (save all changes). </a>
<p style='margin-left:20px; margin-top:30px;'>
<a href="/web/cancel"> Cancel the transaction (discard all changes). </a>
EOM
			}
		elsif ($action eq "commit")
			{
			if ($status eq "success")
			{
			$s->{body} .= <<EOM;
<h1> Transaction Committed </h1>
<p>
The transaction was committed successfully.
EOM
			}
			else
			{
			$s->{body} .= <<EOM;
<h1> Transaction Failed </h1>
<p>
It was not possible to commit the transaction because some other process made
some changes while the transaction was in progress.  Perhaps someone else is
changing this same data from another web browser.
EOM
			}

			}
		elsif ($action eq "cancel")
			{
			$s->{body} .= <<EOM;
<h1> Transaction Canceled </h1>
<p>
The transaction has been canceled.
EOM
			}

		if ($action eq "commit" || $action eq "cancel")
			{
			$s->{body} .= <<EOM;
<p style='margin-left:20px'>
<a href="/web/begin"> Start a new transaction. </a>
<p style='margin-left:20px'>
<a href="/"> Return to Home page. </a>
EOM
			}
		}

	return;
	}

# Split the path on slashes returning a list of path legs.  Apply URI escape
# rules to each leg.  Ignore null legs.
#
# This allows the use of bizarre paths, allowing the encoding of somewhat
# arbitrary data.  For an example see Loom::Web::Page_Test.

sub split_path
	{
	my $s = shift;
	my $path = shift;

	my @path;
	for my $leg (split("/",$path))
		{
		next if $leg eq "";
		push @path, uri_unescape($leg);
		}
	return @path;
	}

# Eases dynamic loading and creation of objects.
sub object
	{
	my $s = shift;
	my $module = shift;

	return $s->{load}->require($module)->new(@_);
	}

sub render_page
	{
	my $s = shift;

	return if $s->{response_text} ne "";

	my $onload_clause = "";
	{
	my $focus_field = $s->{focus_field};

	$onload_clause = qq{ onload="document.forms[0].$focus_field.focus()"}
		if $focus_field ne "";
	}

	my $system_name = $s->{config}->get("system_name");
	my $title = "$system_name $s->{title}";

	# Conditional javascript keyboard.

	my $keyboard_script = "";

	if ($s->{need_keyboard})
		{
		$keyboard_script .= <<EOM;
<script type="text/javascript" src="/cache/7200/data/keyboard.js" charset="UTF-8"></script>
<link rel="stylesheet" href="/cache/7200/data/keyboard.css" type="text/css">
EOM
		}

	my $payload = "";

	$payload .= <<EOM;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
<meta http-equiv="Content-Language" content="en-us">
<meta name="description" content="$system_name">
<meta name="keywords" content="CMS content-management gold money payment freedom">
<title>$title</title>
<link rel="stylesheet" href="/cache/7200/data/style.css" type="text/css">
$keyboard_script
</head>
<body style='max-width:650px'$onload_clause>
EOM

	$payload .= $s->top_navigation_bar if !$s->{printer_friendly};

	$payload .= <<EOM;
$s->{body}
</body>
</html>
EOM

	my $response_code = "200 OK";
	my $headers = "Content-type: text/html\n";

	$s->format_HTTP_response($response_code,$headers,$payload);
	}

sub get_cookie
	{
	my $s = shift;
	my $key = shift;

	if (!defined $s->{cookie_cache})
		{
		my $cookie_line = $s->{http}->header->get("Cookie");

		my @pairs =
			map { split(/=/,$_) }
			split(/\s*;\s*/,$s->{html}->trimblanks($cookie_line));

		$s->{cookie_cache} = Loom::Context->new(@pairs);
		}

	return $s->{cookie_cache}->get($key);
	}

sub put_cookie
	{
	my $s = shift;
	my $key = shift;
	my $val = shift;
	my $timeout = shift;  # in seconds (optional)

	my $this_url = $s->{config}->get("this_url");
	my $http = $s->{http};
	my $host = $http->{header}->get("Host");

	my $server_name = $host;
	$server_name =~ s/:\d+$//; # strip off port number if present

	my $cookie_domain = ".$server_name";
	my $cookie_path = "/";
	my $cookie_secure = ($this_url =~ /^https:/);

	my $expires = "";
	if (defined $timeout)
		{
		my $time = time + $timeout;
		my $dttm = Loom::Dttm->new($time)->as_cookie;
		$expires = " expires=$dttm";
		}

	my $secure = $cookie_secure ? " secure;" : "";

	$s->{cookie_text} .=
		"Set-Cookie: $key=$val;$secure domain=$cookie_domain; "
		."path=$cookie_path;"
		."$expires\n";

	return;
	}

sub top_navigation_bar
	{
	my $s = shift;

	my $dsp_links = "";
	my $top_links = $s->{top_links};
	for my $link (@$top_links)
		{
		$link = "&nbsp;" if !defined $link || $link eq "";
		$dsp_links .= qq{<span style='padding-right:15px'>$link</span>\n};
		}

	my $nav_logo_stanza = $s->{config}->get("nav_logo_stanza");

	my $padding = "";

	if ($nav_logo_stanza eq "")
		{
		$nav_logo_stanza = "<td></td>\n";
		$padding = "padding:5px; ";
		}

	my $nav_message = $s->{nav_message};

	my $color = $s->{config}->get("odd_row_color");

	my $result = "";
	$result .= <<EOM;
<div style='${padding}background-color:$color;
	margin-bottom:5px;
	border: solid 0px;
	width: 650px;'>

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
	if ($nav_message ne "")
		{
		$result .= <<EOM;
<tr>
<td colspan=2>
$nav_message
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

# Check the session parameter for validity.  XOR it with the mask cookie to
# reveal the real session id.  Use the {login} object to validate the real
# session id.  If it's good, return it.  If not, clear the session parameter
# and return null.

sub check_session
	{
	my $s = shift;

	my $op = $s->{op};
	my $masked_session = $op->get("session");
	my $mask = $s->get_cookie("mask");

	if ($s->{id}->valid_id($masked_session) && $s->{id}->valid_id($mask))
		{
		my $real_session = $s->{id}->xor_hex($masked_session,$mask);

		if ($s->{login}->valid_session($real_session))
			{
			# Session is valid.  Return it.
			return $real_session;
			}
		}

	# Session is not valid.  Clear the parameter and return null.
	$op->put("session","");
	return "";
	}

sub archive_get
	{
	my $s = shift;
	my $loc = shift;  # id or hash

	return undef if !defined $loc;
	return undef if $loc eq "";

	if ($s->{id}->valid_id($loc))
		{
		my $api = $s->{loom}->run(
			function => "archive",
			action => "touch",
			loc => $loc);

		return undef if $api->get("status") ne "success";
		return $api->get("content");
		}
	elsif ($s->{id}->valid_hash($loc))
		{
		my $api = $s->{loom}->run(
			function => "archive",
			action => "look",
			hash => $loc);

		return undef if $api->get("status") ne "success";
		return $api->get("content");
		}
	else
		{
		return undef;
		}
	}

sub page_ok
	{
	my $s = shift;
	my $page = shift;

	$s->page_HTTP("200 OK", $page);
	}

sub page_not_found
	{
	my $s = shift;

	my $page = <<EOM;
Content-type: text/html

<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<HTML><HEAD>
<TITLE>404 Not Found</TITLE>
</HEAD><BODY>
<H1>Not Found</H1>
The requested URL was not found on this server.<P>
</BODY></HTML>
EOM

	$s->page_HTTP("404 Not Found",$page);

	$s->{client}->disconnect;

	return;
	}

# See if the page has any content headers.  If so, don't change anything.  If
# not, put Content-type: text/plain on the front so it renders properly.

sub page_HTTP
	{
	my $s = shift;
	my $response_code = shift;
	my $page = shift;

	my ($header_op,$headers,$content) = $s->split_content($page);

	if ($headers eq "")
		{
		# No headers, use text/plain by default.
		$headers = "Content-type: text/plain\n";
		}

	$s->format_HTTP_response($response_code,$headers,$content);
	}

sub format_HTTP_response
	{
	my $s = shift;
	my $response_code = shift;
	my $headers = shift;
	my $content = shift;

	my $content_length = length($content);

	$s->{response_text} = "";
	$s->{response_text} = "HTTP/1.1 $response_code\n";
	$s->{response_text} .= $headers;

	$s->{response_text} .= $s->{cookie_text};
	$s->{response_text} .=
		"Cache-Control: max-age=$s->{cache_time}; must-revalidate\n"
		if $s->{cache_time} ne "";

	$s->{response_text} .= "Content-Length: $content_length\n";
	$s->{response_text} .= "\n";
	$s->{response_text} .= $content;

	return;
	}

sub split_content
	{
	my $s = shift;
	my $text = shift;

	my $header_op = Loom::Context->new;
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

			$header_op->put($key,$val);

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

sub set_title
	{
	my $s = shift;
	$s->{title} = shift;
	}

sub set_focus
	{
	my $s = shift;
	$s->{focus_field} = shift;
	}

# Conditionally highlighted link.

sub highlight_link
	{
	my $s = shift;
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

sub url
	{
	my $s = shift;
	return $s->{html}->make_link("/", @_);
	}

sub simple_value_selector
	{
	my $s = shift;
	my $field = shift;
	my $label = shift;
	my $values = shift;

	my $op = $s->{op};

	my $selector = "";

	$selector .= <<EOM;
<select name=$field>
<option value="">$label</option>
EOM

	for my $value (@$values)
		{
		my $q_value = $s->{html}->quote($value);

		my $selected = "";
		$selected = " selected" if $op->get($field) eq $value;

		$selector .= <<EOM;
<option$selected value="$q_value">$q_value</option>
EOM
		}

	$selector .= <<EOM;
</select>
EOM

	return $selector;
	}

# This can be used for testing.
sub show_op
	{
	my $s = shift;
	my $op = shift;

	my $op_str = $op->write_kv;
	my $q_op_str = $s->{html}->quote($op_str);

	$s->{body} .= <<EOM;
<pre>
$q_op_str
</pre>
EOM
	}

sub showing_maintenance_page
	{
	my $s = shift;

	return 0 if !$s->now_in_maintenance_mode;

	$s->{op}->put("error_system","maintenance");

	my $system_name = $s->{config}->get("system_name");

	my $page = <<EOM;
Content-type: text/html

<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<HTML><HEAD>
<TITLE>503 Service Unavailable</TITLE>
</HEAD><BODY>
<H1>Service Unavailable</H1>
$system_name is currently down for maintenance.
</BODY></HTML>
EOM

	$s->page_ok($page);

	return 1;
	}

# Get a diceware random passphrase object.
sub diceware
	{
	my $s = shift;

	return $s->{diceware} if defined $s->{diceware};
	$s->{diceware} = $s->object("Loom::Diceware",$s->{random});
	return $s->{diceware};
	}

# LATER: not yet used

sub fatal_error
	{
	my $s = shift;
	my $msg = shift;
	my $level = shift;  # optional

	$level = 0 if !defined $level;

	my @caller = caller($level);
	my $filename = $caller[1];
	my $lineno = $caller[2];

	my $conf = $s->{config};
	my $system_name = $conf->get("system_name");
	my $subject = "$system_name system error";

	$s->email_notify($subject, $msg);

	my $where = "called at $filename line $lineno";

	$s->enter_maintenance_mode("$msg\n$where\n");

	die "$msg $where\n";

	exit(1);  # just in case
	}

sub enter_maintenance_mode
	{
	my $s = shift;
	my $msg = shift;

	$msg = "" if !defined $msg;

	my $fh;
	if (open($fh,">$s->{notify_path}/maintenance.flag"))
		{
		print $fh $msg;
		close($fh);
		}
	}

sub exit_maintenance_mode
	{
	my $s = shift;

	unlink "$s->{notify_path}/maintenance.flag";
	}

sub now_in_maintenance_mode
	{
	my $s = shift;

	return -e "$s->{notify_path}/maintenance.flag" ? 1 : 0;
	}

sub email_notify
	{
	my $s = shift;
	my $subject = shift;
	my $msg = shift;

	my $conf = $s->{config};
	my $from = $conf->get("notify_from");
	my $to = $conf->get("notify_to");

	$s->send_email($from, $to, $subject, $msg);
	}

# LATER:  not yet used, and may not want to use sendmail anyway.

sub send_email
	{
	my $s = shift;  # not used
	my $from = shift;
	my $to = shift;
	my $subject = shift;
	my $message = shift;

	my $fh;

	my $str = <<EOM;
To: $to
From: $from
Subject: $subject
MIME-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Transfer-Encoding: 7bit

$message
EOM

	if (open($fh, "|/usr/sbin/sendmail -t"))
		{
		print $fh $str;
		close($fh);
		}
	else
		{
		print STDERR "sendmail $!\n";
		}
	}

return 1;

__END__

# Copyright 2007 Patrick Chkoreff
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions
# and limitations under the License.
