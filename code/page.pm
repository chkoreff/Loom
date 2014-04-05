package page;
use strict;
use context;
use dttm;
use html;
use http;
use id;
use loom_config;
use loom_login;
use sloop_io;

# LATER unify with read_http_headers

sub split_content
	{
	my $text = shift;

	my $header_op = context::new();
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

			context::put($header_op,$key,$val);

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

my $g_cookie_cache;
my $g_cookie_text;
my $g_title_text;
my $g_printer_friendly;
my $g_focus_field;
my $g_need_keyboard;
my $g_response_text;
my $g_body;
my $g_cache_time;
my $g_top_links;
my $g_top_message;

sub clear
	{
	set_title("");

	$g_response_text = "";
	$g_focus_field = "";
	$g_need_keyboard = 0;
	$g_body = "";

	$g_printer_friendly = 0;

	$g_cache_time = "";
	$g_cookie_text = "";
	$g_cookie_cache = undef;

	$g_top_links = [];
	$g_top_message = "";
	}

sub get_cookie
	{
	my $key = shift;

	if (!defined $g_cookie_cache)
		{
		my $cookie_line = http::header("Cookie");

		my @pairs =
			map { split(/=/,$_) }
			split(/\s*;\s*/,html::trimblanks($cookie_line));

		$g_cookie_cache = context::new(@pairs);
		}

	return context::get($g_cookie_cache,$key);
	}

sub put_cookie
	{
	my $key = shift;
	my $val = shift;
	my $timeout = shift;  # in seconds (optional)

	my $this_url = loom_config::get("this_url");
	my $host = http::header("Host");

	my $server_name = $host;
	$server_name =~ s/:\d+$//; # strip off port number if present

	my $cookie_domain = ".$server_name";
	my $cookie_path = "/";
	my $cookie_secure = ($this_url =~ /^https:/);

	my $expires = "";
	if (defined $timeout)
		{
		my $time = time + $timeout;
		my $dttm = dttm::as_cookie($time);
		$expires = " expires=$dttm";
		}

	my $secure = $cookie_secure ? " secure;" : "";

	$g_cookie_text .=
		"Set-Cookie: $key=$val;$secure domain=$cookie_domain; "
		."path=$cookie_path;"
		."$expires\n";

	return;
	}

sub set_cache_time
	{
	$g_cache_time = shift;
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

sub HTTP
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

sub ok
	{
	my $page = shift;

	HTTP("200 OK", $page);
	}

sub not_found
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

	HTTP("404 Not Found",$page);

	sloop_io::disconnect();

	return;
	}

sub set_title
	{
	my $title = shift;

	$g_title_text = html::quote($title);
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

sub top_link
	{
	my $link = shift;

	push @$g_top_links, $link;
	return;
	}

# Conditionally highlighted link.

# TODO 20140405 simplify page::top_link(page::highlight_link(...))
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

sub top_message
	{
	my $text = shift;

	$g_top_message = $text;
	}

sub emit
	{
	my $text = \shift; # pass by reference to avoid copy
	$g_body .= $$text;
	return;
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
		my $q_value = html::quote($value);

		my $selected = "";
		$selected = " selected" if http::get($field) eq $value;

		$selector .= <<EOM;
<option$selected value="$q_value">$q_value</option>
EOM
		}

	$selector .= <<EOM;
</select>
EOM

	return $selector;
	}

sub loom_top_navigation_bar
	{
	my $dsp_links = "";
	for my $link (@$g_top_links)
		{
		next if !defined $link || $link eq "";
		$dsp_links .= qq{<span style='padding-right:15px'>$link</span>\n};
		}

	my $nav_logo_stanza = loom_config::get("nav_logo_stanza");

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

	my $system_name = loom_config::get("system_name");
	my $title = get_title();

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

#<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">

	# Allow optional "base ref" clause in case someone is running the Loom
	# server behind a front-end that uses some other root path.
	my $base_clause = "";
	if (loom_config::get("use_base"))
		{
		my $this_url = loom_config::get("this_url");
		$base_clause = qq{<base href="$this_url">\n};
		}

	$payload .= <<EOM;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN">
<html>
<head>
$base_clause<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
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

# Check the session parameter for validity.  XOR it with the mask cookie to
# reveal the real session id.  Validate the real session id.  If it's good,
# return it.  If not, clear the session parameter and return null.

sub check_session
	{
	my $masked_session = http::get("session");
	my $mask = get_cookie("mask");

	if (id::valid_id($masked_session) && id::valid_id($mask))
		{
			my $real_session = id::xor_hex($masked_session,$mask);

		if (loom_login::valid_session($real_session))
			{
			# Session is valid.  Return it.
			return $real_session;
			}
		}

	# Session is not valid.  Clear the parameter and return null.
	http::put("session","");
	return "";
	}

sub send_response
	{
	loom_render_page();
	sloop_io::send($g_response_text);
	}

return 1;
