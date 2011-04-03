use strict;

sub page_archive_tutorial_links
	{
	my $function = http_get("function");

	top_link(highlight_link(top_url(),"Home"));
	top_link(highlight_link(top_url("help",1),"Advanced"));

	my $link_tutorial =
		highlight_link
		(
		top_url("function","archive_tutorial"),
		"Archive Tutorial",
		($function eq "archive_tutorial" && !http_get("help"))
		);

	my $link_api =
		highlight_link
		(
		top_url("function","archive_tutorial", "help",1),
		"Archive API",
		($function eq "archive_tutorial" && http_get("help"))
		);

	top_link($link_api);
	top_link($link_tutorial);

	return;
	}

sub page_archive_tutorial_respond
	{
	set_title("Archive Tutorial");
	page_archive_tutorial_links();

	if (http_get("help"))
		{
		help_topic("archive");
		return;
		}

	my $q = {};   # for page rendering

	$q->{dsp_error} = "";
	$q->{dsp_cost} = "";

	my $api = op_new();
	op_put($api,"function","archive");

	if (http_get("look") ne "")
		{
		op_put($api,"action","look");
		op_put($api,"hash",http_get("hash"));
		}
	elsif (http_get("touch") ne "")
		{
		op_put($api,"action","touch");
		op_put($api,"loc",http_get("loc"));
		}
	elsif (http_get("write") ne "")
		{
		my $content = http_get("content");
		$content =~ s/\015//g;
		http_put("content",$content);

		op_put($api,"action","write");
		op_put($api,"usage",http_get("usage"));
		op_put($api,"loc",http_get("loc"));
		op_put($api,"content",http_get("content"));
		op_put($api,"guard",http_get("guard"));
		}
	elsif (http_get("buy") ne "")
		{
		op_put($api,"action","buy");
		op_put($api,"usage",http_get("usage"));
		op_put($api,"loc",http_get("loc"));
		}
	elsif (http_get("sell") ne "")
		{
		op_put($api,"action","sell");
		op_put($api,"usage",http_get("usage"));
		op_put($api,"loc",http_get("loc"));
		}

	my $orig_api;

	if (op_get($api,"action") ne "")
		{
		# First make a copy of the $api object so we can show the url below.

		$orig_api = op_new(op_pairs($api));

		api_respond($api);
		}

	$q->{enable_write} = 1;

	my $action = op_get($api,"action");

	if ($action ne "")
		{
		my $status = op_get($api,"status");

		if ($action eq "look" || $action eq "touch"
			|| $action eq "buy" || $action eq "sell")
			{
			http_put("content",op_get($api,"content"));
			}

		if ($action eq "touch" || $action eq "write"
			|| $action eq "buy" || $action eq "sell")
			{
			http_put("hash",op_get($api,"hash"));
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
			$q->{dsp_error} = op_get($api,"error_loc");
			$q->{dsp_error} = "<span class=alarm>$q->{dsp_error}</span>"
				if $q->{dsp_error} ne "";
			}
		}

	for my $field (qw(usage hash loc))
		{
		$q->{$field} = html_quote(http_get($field));
		}

	{
	my $entered_content = http_get("content");

	my @lines = split("\n",$entered_content);

	my $num_lines = scalar(@lines);

	my $num_rows = $num_lines;
	$num_rows = 20 if $num_rows < 20;
	$num_rows = 40 if $num_rows > 40;

	$q->{content} = html_quote($entered_content);
	$q->{num_content_rows} = $num_rows;
	}

	my $input_size_id = 32 + 2;
	my $input_size_hash = 2 * $input_size_id;

	my $hidden = html_hidden_fields(http_slice(qw(function)));

	emit(<<EOM
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
	my $action = op_get($api,"action");

	if ($action eq "write" || $action eq "buy" || $action eq "sell")
		{
		my $status = op_get($api,"status");
		my $color = $status eq "success" ? "green" : "red";
		my $dsp_status = "<span style='color:$color'>$status</span>";

		my $cost = op_get($api,"cost");
		my $bal = op_get($api,"usage_balance");
		if ($cost ne "")
			{
			$dsp_status .= " (cost $cost, bal $bal)";
			}

		$dsp_write .= " $dsp_status";
		}
	}

	my $link_view = highlight_link(
		top_url("function","view", "hash",http_get("hash")),
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
	my $guard = unpack("H*",sha256(http_get("content")));

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

	my $color = loom_config("odd_row_color");

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

	emit(<<EOM
<p>
This is an interactive tutorial to help you set up and test Archive API operations.
Be careful using sensitive locations in this tutorial, since they do show
up in plain text on this screen.

<p>
$archive_table
EOM
);

	emit(<<EOM

</form>
EOM
);

	if (op_get($api,"action") ne "")
	{
	my $q_result = html_quote(op_write_kv($api));
	my $url = top_url(op_pairs($orig_api));

	my $this_url = loom_config("this_url");

	emit(<<EOM
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
