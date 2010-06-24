package Loom::Web::Page_Archive_Tutorial;
use strict;
use Loom::Context;
use Loom::Digest::SHA256;

sub new
	{
	my $class = shift;
	my $site = shift;

	my $s = bless({},$class);
	$s->{site} = $site;
	$s->{html} = $site->{html};
	$s->{hasher} = Loom::Digest::SHA256->new;
	return $s;
	}

sub respond
	{
	my $s = shift;

	my $site = $s->{site};
	my $op = $site->{op};

	$site->set_title("Archive Tutorial");
	$s->top_links;

	if ($op->get("help"))
		{
		$site->object("Loom::Web::Page_Help",$site,"archive")->respond;
		return;
		}

	my $q = {};   # for page rendering

	$q->{dsp_error} = "";
	$q->{dsp_cost} = "";

	my $api = Loom::Context->new;
	$api->put(function => "archive");

	if ($op->get("look") ne "")
		{
		$api->put(action => "look");
		$api->put(hash => $op->get("hash"));
		}
	elsif ($op->get("touch") ne "")
		{
		$api->put(action => "touch");
		$api->put(loc => $op->get("loc"));
		}
	elsif ($op->get("write") ne "")
		{
		$api->put(action => "write");
		$api->put(usage => $op->get("usage"));
		$api->put(loc => $op->get("loc"));
		$api->put(content => $op->get("content"));
		$api->put(guard => $op->get("guard"));
		}
	elsif ($op->get("buy") ne "")
		{
		$api->put(action => "buy");
		$api->put(usage => $op->get("usage"));
		$api->put(loc => $op->get("loc"));
		}
	elsif ($op->get("sell") ne "")
		{
		$api->put(action => "sell");
		$api->put(usage => $op->get("usage"));
		$api->put(loc => $op->get("loc"));
		}

	my $orig_api;

	if ($api->get("action") ne "")
		{
		# First make a copy of the $api object so we can show the url below.

		$orig_api = Loom::Context->new($api->pairs);

		$site->{loom}->run_op($api);
		}

	$q->{enable_write} = 1;

	my $action = $api->get("action");

	if ($action ne "")
		{
		my $status = $api->get("status");

		if ($action eq "look" || $action eq "touch"
			|| $action eq "buy" || $action eq "sell")
			{
			$op->put("content",$api->get("content"));
			}

		if ($action eq "touch" || $action eq "write"
			|| $action eq "buy" || $action eq "sell")
			{
			$op->put("hash",$api->get("hash"));
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
			$q->{dsp_error} = $api->get("error_loc");
			$q->{dsp_error} = "<span class=alarm>$q->{dsp_error}</span>"
				if $q->{dsp_error} ne "";
			}
		}

	for my $field (qw(usage hash loc))
		{
		$q->{$field} = $s->{html}->quote($op->get($field));
		}

	{
	my $entered_content = $op->get("content");

	my @lines = split("\n",$entered_content);

	my $num_lines = scalar(@lines);

	my $num_rows = $num_lines;
	$num_rows = 20 if $num_rows < 20;
	$num_rows = 40 if $num_rows > 40;

	$q->{content} = $s->{html}->quote($entered_content);
	$q->{num_content_rows} = $num_rows;
	}

	my $input_size_id = 32 + 2;
	my $input_size_hash = 2 * $input_size_id;

	my $hidden = $s->{html}->hidden_fields($op->slice(qw(function)));

	$site->{body} .= <<EOM;
<form method=post action="" autocomplete=off>
$hidden

EOM

	my $dsp_content = "";

	my $dsp_write = "";

	if ($q->{enable_write})
	{
	$dsp_write .= <<EOM;
<input type=submit name=write value="Write">
EOM
	}

	{
	my $action = $api->get("action");

	if ($action eq "write" || $action eq "buy" || $action eq "sell")
		{
		my $status = $api->get("status");
		my $color = $status eq "success" ? "green" : "red";
		my $dsp_status = "<span style='color:$color'>$status</span>";

		my $cost = $api->get("cost");
		my $bal = $api->get("usage_balance");
		if ($cost ne "")
			{
			$dsp_status .= " (cost $cost, bal $bal)";
			}

		$dsp_write .= " $dsp_status";
		}
	}

	my $link_view = $site->highlight_link(
		$site->url(function => "view", hash => $op->get("hash")),
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
	my $guard = unpack("H*",$s->{hasher}->sha256($op->get("content")));

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

	my $color = $site->{config}->get("odd_row_color");

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

	$site->{body} .= <<EOM;
<p>
This is an interactive tutorial to help you set up and test Archive API operations.
Be careful using sensitive locations in this tutorial, since they do show
up in plain text on this screen.

<p>
$archive_table
EOM

	$site->{body} .= <<EOM;

</form>
EOM

	if ($api->get("action") ne "")
	{
	my $q_result = $s->{html}->quote($api->write_kv);
	my $url = $site->url($orig_api->pairs);

	my $this_url = $site->{config}->get("this_url");

	$site->{body} .= <<EOM;
<h2>URL</h2>
<p>
<a href="$url">$this_url$url</a>
</p>

<h2>Result (in KV format)</h2>
<pre>
$q_result
</pre>
EOM
	}

	return;
	}

sub top_links
	{
	my $s = shift;

	my $site = $s->{site};
	my $op = $site->{op};

	my $function = $op->get("function");

	push @{$site->{top_links}},
		$site->highlight_link(
			$site->url,
			"Home");

	push @{$site->{top_links}},
		$site->highlight_link(
			$site->url(help => 1),
			"Advanced");
	
	my $link_tutorial =
		$site->highlight_link
		(
		$site->url(function => "archive_tutorial"),
		"Archive Tutorial",
		($function eq "archive_tutorial" && !$op->get("help"))
		);

	my $link_api =
		$site->highlight_link
		(
		$site->url(function => "archive_tutorial", help => 1),
		"Archive API",
		($function eq "archive_tutorial" && $op->get("help"))
		);
	
	if ($op->get("help"))
		{
		push @{$site->{top_links}}, $link_api;
		push @{$site->{top_links}}, "";
		push @{$site->{top_links}}, $link_tutorial;
		}
	else
		{
		push @{$site->{top_links}}, $link_tutorial;
		push @{$site->{top_links}}, "";
		push @{$site->{top_links}}, $link_api;
		}


	return;
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
