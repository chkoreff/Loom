package Loom::Site::Loom::Main;
use strict;
use Loom::Context;
use Loom::DB::GNU;
use Loom::Diceware;
use Loom::Dttm;
use Loom::File;
use Loom::HTML;
use Loom::ID;
use Loom::Random;
use Loom::Sloop::HTTP;
use Loom::Strq;
use Loom::Site::Loom::API;
use Loom::Site::Loom::Dispatch;
use Loom::Site::Loom::Login;  # LATER  need this here, or move down into Folder?

# LATER: do some periodic qualifications and consistency tests.

sub new
	{
	my $class = shift;
	my $TOP = shift;

	my $s = bless({},$class);

	$s->{TOP} = $TOP;

	$s->{id} = Loom::ID->new;
	$s->{html} = Loom::HTML->new;

	# Establish state machine for reading HTTP protocol.
	$s->{http} = Loom::Sloop::HTTP->new;

	# This is the database used throughout the system.
	$s->{db} = Loom::DB::GNU->new("$s->{TOP}/data/app/loom.db");

	$s->{notify_path} = "$s->{TOP}/data/run";

	# Establish random number generator.
	$s->{random} = Loom::Random->new;

	# Establish diceware object to generate random passphrase.
	$s->{diceware} = Loom::Diceware->new($s->{random});

	# Establish the main loom API used in this server.
	$s->{loom} = Loom::Site::Loom::API->new($s->{db});

	# Establish the standard apparatus for passphrase and session login.
	# LATER move down into Folder?
	$s->{login} = Loom::Site::Loom::Login->new($s->{loom});

	$s->configure;

	$s->{exiting} = 0;
	$s->{input} = "";  # buffer for input coming from client

	return $s;
	}

# This is called when new input data arrives from the client.

sub put
	{
	my $s = shift;
	my $data = shift;

	if (!defined $data)
		{
		# Client disconnected.
		$s->{input} = undef;
		}
	elsif ($data eq "")
		{
		# Client needs more data from server.  (We should never see this.)
		}
	else
		{
		$s->{input} .= $data;
		}

	return;
	}

# This is called to get the next response from the server.

sub get
	{
	my $s = shift;

	my $input = $s->{input};
	$s->{exiting} = 1 if !defined $input;

	return if $s->{exiting};
	return "" if $input eq "";  # need data from client

	$s->{input} = "";  # clear the input buffer

	my $http = $s->{http};

	$http->parse_data($input);

	if ($http->{complete})
		{
		$s->respond;

		$s->{exiting} = 1 if $http->{exiting};
			# This can happen if the connection type is "close" instead of
			# "keep-alive".

		$http->start;

		return $s->{response_text};
		}

	if ($http->{exiting})
		{
		# HTTP parser terminated because the post was too big.
		$s->{exiting} = 1;
		return;
		}

	return "";  # need more data from client
	}

# Read the basic system configuration from the data/conf/loom file.

sub configure
	{
	my $s = shift;

	# Read the configuration parameters from the archive (in KV format).

	my $config_id;

	{
	my $text = Loom::File->new("$s->{TOP}/data/conf/loom")->get;

	for my $line (split("\n",$text))
		{
		next if $line =~ /^\s*$/ || $line =~ /^#/;
			# ignore blank lines and comments

		my $cmd = Loom::Strq->new->parse($line);
		my $verb = $cmd->[0];

		if ($verb eq "config_id")
			{
			$config_id = $cmd->[1];
			}
		}
	}

	$s->{config} = Loom::Context->read_kv( $s->archive_get($config_id) );

	# Configure the dynamic dispatcher.

	$s->{dispatch} = Loom::Site::Loom::Dispatch->new;

	my @entries =
	(
	["", "Loom::Site::Loom::Page_Folder"],
	["folder", "Loom::Site::Loom::Page_Folder"],
	["contact", "Loom::Site::Loom::Page_Folder"],
	["asset", "Loom::Site::Loom::Page_Folder"],
	["grid", "Loom::Site::Loom::Page_Grid_API"],
	["archive", "Loom::Site::Loom::Page_Archive_API"],
	["view", "Loom::Site::Loom::Page_View"],
	["edit", "Loom::Site::Loom::Page_Edit"],
	["upload", "Loom::Site::Loom::Page_Edit"],
	["data", "Loom::Site::Loom::Page_Data"],
	["folder_tools", "Loom::Site::Loom::Page_Tool"],
	["archive_tutorial", "Loom::Site::Loom::Page_Archive_Tutorial"],
	["grid_tutorial", "Loom::Site::Loom::Page_Grid_Tutorial"],
	["test", "Loom::Site::Loom::Page_Test"],
	["news", "Loom::Site::Loom::Page_Std", $s->{config}->get("news_page"), "News"],
	["merchants", "Loom::Site::Loom::Page_Std", $s->{config}->get("merchants_page"),
		"Merchants"],
	["faq", "Loom::Site::Loom::Page_Std", $s->{config}->get("faq_page"),
		"FAQ"],
	);

	for my $entry (@entries)
		{
		$s->{dispatch}->map_named_object(@$entry);
		}

	return;
	}

# Respond to a complete HTTP message in $s->{http}.

sub respond
	{
	my $s = shift;

	$s->{op} = $s->{http}->{op};

	$s->clear_state;
	$s->dispatch;
	$s->render_page;

	$s->{op} = undef;
	$s->{db}->finish;

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

	return if $s->showing_maintenance_page;

	my $op = $s->{op};

	# Internally resolve any defined paths.

	$s->{resolved} = 0;
	$s->{counter} = 0;

	while (!$s->{resolved})
	{
	$s->{resolved} = 1;
	$s->{counter}++;

	my $file = $s->{http}->{file};

	last if $s->{counter} > 16;  # impose max 16 redirects

	my @path;
	for my $leg (split("/",$file))
		{
		push @path, $leg if $leg ne "";
		}

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

		$s->{http}->{file} = join("/",@path);
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
			$s->{http}->{file} = $alias;
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
	my $object = $s->{dispatch}->get_named_object($name,$s);

	return $s->page_not_found if !defined $object;

	$object->respond;

	return;
	}

# This is used for dynamic loading.

sub object
	{
	my $s = shift;
	my $module = shift;

	return $s->{dispatch}->get_object($module,@_);
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
<body style='max-width:800px'$onload_clause>
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
		my $cookie_line = $s->{http}->{header}->get("Cookie");

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
		$link = "/" if !defined $link || $link eq "";

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

	my $result = "";
	$result .= <<EOM;
<div style='${padding}background-color:#EEEEEE;
	margin-bottom:5px;
	border: solid 0px'>

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

	$s->{exiting} = 1;  # sever the connection here

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

	my $op = $s->{op};
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
