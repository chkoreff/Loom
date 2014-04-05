package page_archive_tutorial;
use strict;
use api;
use context;
use html;
use http;
use loom_config;
use page;
use page_help;
use sha256;

sub links
	{
	my $function = http::get("function");

	page::top_link(page::highlight_link(html::top_url(),"Home"));
	page::top_link(page::highlight_link(html::top_url("help",1),"Advanced"));

	my $link_tutorial =
		page::highlight_link(
		html::top_url("function","archive_tutorial"),
		"Archive Tutorial",
		($function eq "archive_tutorial" && !http::get("help"))
		);

	my $link_api =
		page::highlight_link(
		html::top_url("function","archive_tutorial", "help",1),
		"Archive API",
		($function eq "archive_tutorial" && http::get("help"))
		);

	page::top_link($link_api);
	page::top_link($link_tutorial);

	return;
	}

sub respond
	{
	page::set_title("Archive Tutorial");
	links();

	if (http::get("help"))
		{
		page_help::topic("archive");
		return;
		}

	my $q = {};   # for page rendering

	$q->{dsp_error} = "";
	$q->{dsp_cost} = "";

	my $api = context::new();
	context::put($api,"function","archive");

	if (http::get("look") ne "")
		{
		context::put($api,"action","look");
		context::put($api,"hash",http::get("hash"));
		}
	elsif (http::get("touch") ne "")
		{
		context::put($api,"action","touch");
		context::put($api,"loc",http::get("loc"));
		}
	elsif (http::get("write") ne "")
		{
		my $content = http::get("content");
		$content =~ s/\015//g;
		http::put("content",$content);

		context::put($api,"action","write");
		context::put($api,"usage",http::get("usage"));
		context::put($api,"loc",http::get("loc"));
		context::put($api,"content",http::get("content"));
		context::put($api,"guard",http::get("guard"));
		}
	elsif (http::get("buy") ne "")
		{
		context::put($api,"action","buy");
		context::put($api,"usage",http::get("usage"));
		context::put($api,"loc",http::get("loc"));
		}
	elsif (http::get("sell") ne "")
		{
		context::put($api,"action","sell");
		context::put($api,"usage",http::get("usage"));
		context::put($api,"loc",http::get("loc"));
		}

	my $orig_api;

	if (context::get($api,"action") ne "")
		{
		# First make a copy of the $api object so we can show the url below.

		$orig_api = context::new(context::pairs($api));

		api::respond($api);
		}

	$q->{enable_write} = 1;

	my $action = context::get($api,"action");

	if ($action ne "")
		{
		my $status = context::get($api,"status");

		if ($action eq "look" || $action eq "touch"
			|| $action eq "buy" || $action eq "sell")
			{
			http::put("content",context::get($api,"content"));
			}

		if ($action eq "touch" || $action eq "write"
			|| $action eq "buy" || $action eq "sell")
			{
			http::put("hash",context::get($api,"hash"));
			}

		if ($action eq "look")
			{
			$q->{enable_write} = 0;
			}
		elsif ($action eq "touch")
			{
			$q->{enable_write} = ($status eq "success");
			}
		elsif ($action eq "buy")
			{
			$q->{enable_write} = ($status eq "success");
			}
		elsif ($action eq "sell")
			{
			$q->{enable_write} = 0;
			}

		if ($status eq "fail")
			{
			$q->{dsp_error} = context::get($api,"error_loc");
			$q->{dsp_error} = "<span class=alarm>$q->{dsp_error}</span>"
				if $q->{dsp_error} ne "";
			}
		}

	for my $field (qw(usage hash loc))
		{
		$q->{$field} = html::quote(http::get($field));
		}

	{
	my $entered_content = http::get("content");

	my @lines = split("\n",$entered_content);

	my $num_lines = scalar(@lines);

	my $num_rows = $num_lines;
	$num_rows = 20 if $num_rows < 20;
	$num_rows = 40 if $num_rows > 40;

	$q->{content} = html::quote($entered_content);
	$q->{num_content_rows} = $num_rows;
	}

	my $input_size_id = 32 + 2;
	my $input_size_hash = 2 * $input_size_id;

	my $hidden = html::hidden_fields(http::slice(qw(function)));

	page::emit(<<EOM
<form method=post action="" autocomplete=off>
$hidden

EOM
);

	my $dsp_content = "";

	my $dsp_write = "";

	if ($q->{enable_write})
	{
	$dsp_write .= <<EOM;
<input type=submit name=write value="Write">
EOM
	}

	{
	my $action = context::get($api,"action");

	if ($action eq "write" || $action eq "buy" || $action eq "sell")
		{
		my $status = context::get($api,"status");
		my $color = $status eq "success" ? "green" : "red";
		my $dsp_status = "<span style='color:$color'>$status</span>";

		my $cost = context::get($api,"cost");
		my $bal = context::get($api,"usage_balance");
		if ($cost ne "")
			{
			$dsp_status .= " (cost $cost, bal $bal)";
			}

		$dsp_write .= " $dsp_status";
		}
	}

	my $link_view = page::highlight_link(
		html::top_url("function","view", "hash",http::get("hash")),
		"View", 0, "View as web page",
		);

	$dsp_content .= <<EOM;
<tr>
<td>
Content:
</td>
<td>
$link_view
$dsp_write
</td>
</tr>
EOM

	if ($q->{enable_write})
	{
	my $guard = unpack("H*",sha256::bin(http::get("content")));

	$dsp_content .= <<EOM;
<tr>
<td colspan=2>
<input type=hidden name=guard value="$guard">
<textarea name=content rows=$q->{num_content_rows} cols=80>
$q->{content}</textarea>
</td>
</tr>
EOM
	}
	else
	{
	# We set the width here to avoid a problem I saw in Firefox when
	# viewing a text value which contained some very long lines.  If I
	# don't set the width, Firefox hides the text input fields (e.g. hash,
	# loc, usage).

	my $color = loom_config::get("odd_row_color");

	$dsp_content .= <<EOM;
<tr>
<td colspan=2>
<div style='background-color:$color; font-size:8pt; width:700px;'>
<pre>
$q->{content}
</pre>
</div>
</td>
</tr>
EOM
	}

	my $archive_table = "";
	$archive_table .= <<EOM;
<table border=0 style='border-collapse:collapse'>
<colgroup>
<col width=80>
</colgroup>

<tr>
<td>
Hash:
</td>
<td>
<input type=text class=mono name=hash size=$input_size_hash value="$q->{hash}">
<input type=submit name=look value="Look">
</td>
</tr>

<tr>
<td>
Location:
</td>
<td>
<input type=text class=mono name=loc size=$input_size_id value="$q->{loc}">
<input type=submit name=touch value="Touch">
<input type=submit name=buy value="Buy">
<input type=submit name=sell value="Sell">
$q->{dsp_error}
</td>
</tr>

<tr>
<td>
Usage:
</td>
<td>
<input type=text class=mono name=usage size=$input_size_id value="$q->{usage}">
</td>
</tr>

$dsp_content

</table>
EOM

	page::emit(<<EOM
<p>
This is an interactive tutorial to help you set up and test Archive API operations.
Be careful using sensitive locations in this tutorial, since they do show
up in plain text on this screen.

<p>
$archive_table
EOM
);

	page::emit(<<EOM

</form>
EOM
);

	if (context::get($api,"action") ne "")
	{
	my $q_result = html::quote(context::write_kv($api));
	my $url = html::top_url(context::pairs($orig_api));

	my $this_url = loom_config::get("this_url");

	page::emit(<<EOM
<h2>URL</h2>
<p>
<a href="$url">$this_url$url</a>
</p>

<h2>Result (in KV format)</h2>
<pre>
$q_result
</pre>
EOM
);
	}

	return;
	}

return 1;
