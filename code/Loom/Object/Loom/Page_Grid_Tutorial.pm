package Loom::Object::Loom::Page_Grid_Tutorial;
use strict;
use Loom::Context;

# Sample 128-bit number:
#  3a4511c895fc71fdfea08f3f3f8c7a97
# Sample 256-bit number:
#  6486b8158425d380642a444f5b2047fd97e452f7c92eaa8d8a7d2c53516d4a69

# Largest 128-bit int:
#  170141183460469231731687303715884105727
#
# Smallest 128-bit int:
#  -170141183460469231731687303715884105728

sub new
	{
	my $class = shift;
	my $site = shift;

	my $s = bless({},$class);
	$s->{site} = $site;
	$s->{html} = $site->{html};
	return $s;
	}

sub respond
	{
	my $s = shift;

	my $site = $s->{site};
	my $op = $site->{op};

	$site->set_title("Grid Tutorial");
	$s->top_links;

	if ($op->get("help"))
		{
		$site->object("Loom::Object::Loom::Page_Help",$site,"grid")->respond; # LATER get rid of these
		return;
		}

	my $api = Loom::Context->new;

	$api->put(function => "grid");

	if ($op->get("buy") ne "")
		{
		$api->put(
			action => "buy",
			type => $op->get("common_type"),
			loc => $op->get("buy_loc"),
			usage => $op->get("buy_usage"),
			);
		}
	elsif ($op->get("sell") ne "")
		{
		$api->put(
			action => "sell",
			type => $op->get("common_type"),
			loc => $op->get("buy_loc"),
			usage => $op->get("buy_usage"),
			);
		}
	elsif ($op->get("issuer") ne "")
		{
		$api->put(
			action => "issuer",
			type => $op->get("common_type"),
			orig => $op->get("issuer_orig"),
			dest => $op->get("issuer_dest"),
			);
		}
	elsif ($op->get("touch") ne "")
		{
		$api->put(
			action => "touch",
			type => $op->get("common_type"),
			loc => $op->get("touch_loc"),
			);
		}
	elsif ($op->get("look") ne "")
		{
		$api->put(
			action => "look",
			type => $op->get("common_type"),
			hash => $op->get("look_hash"),
			);
		}
	elsif ($op->get("move") ne "")
		{
		$api->put(
			action => "move",
			type => $op->get("common_type"),
			qty => $op->get("move_qty"),
			orig => $op->get("move_orig"),
			dest => $op->get("move_dest"),
			);
		}
	elsif ($op->get("move_back") ne "")
		{
		# Just a convenient way to move in the opposite direction, e.g.
		# to undo the last move.

		my $qty = $op->get("move_qty");
		if ($qty =~ /^-/)
			{
			$qty = substr($qty,1);
			}
		else
			{
			$qty = "-$qty";
			}

		$api->put(
			action => "move",
			type => $op->get("common_type"),
			qty => $qty,
			orig => $op->get("move_orig"),
			dest => $op->get("move_dest"),
			);
		}

	my $orig_api;

	if ($api->get("action") ne "")
		{
		# First make a copy of the $api object so we can show the url below.

		$orig_api = Loom::Context->new($api->pairs);

		$site->{loom}->run_op($api);
		}

	my $q = {};

	for my $field (
		qw(
		common_type
		buy_loc buy_usage
		issuer_orig issuer_dest
		move_qty move_orig move_dest
		touch_loc
		look_hash
		))
		{
		$q->{$field} = $s->{html}->quote($op->get($field));
		}

	# Allow a little extra room for display.
	my $input_size_id = 32 + 4;
	my $input_size_hash = 2 * $input_size_id;
	my $input_size_qty = 45;

	my $colgroup = <<EOM;
<colgroup>
<col width=150>
<col width=600>
</colgroup>
EOM

	my $common_table = "";
	$common_table .= <<EOM;
<table border=0 style='border-collapse:collapse'>
$colgroup

<tr>
<td>
Asset Type:
</td>
<td>
<input type=text class=tt name=common_type size=$input_size_id value="$q->{common_type}">
</td>
</tr>

</table>
EOM

	my $buy_table = "";
	$buy_table .= <<EOM;
<table border=0 style='border-collapse:collapse'>
$colgroup

<tr>
<td>
<input type=submit name=buy value="Buy">
<input type=submit name=sell value="Sell">
</td>
<td class=small>
Buy location for one usage token, or sell location for refund.
</td>
</tr>

<tr>
<td>
Location:
</td>
<td>
<input type=text class=tt name=buy_loc size=$input_size_id value="$q->{buy_loc}">
</td>
</tr>

<tr>
<td>
Usage location:
</td>
<td>
<input type=text class=tt name=buy_usage size=$input_size_id value="$q->{buy_usage}">
</td>
</tr>

</table>
EOM

	my $issuer_table = "";
	$issuer_table .= <<EOM;
<table border=0 style='border-collapse:collapse'>
$colgroup

<tr>
<td>
<input type=submit name=issuer value="Issuer">
</td>
<td class=small>
Change the issuer location for a type.
</td>
</tr>

<tr>
<td>
Current Issuer:
</td>
<td>
<input type=text class=tt name=issuer_orig size=$input_size_id value="$q->{issuer_orig}">
</td>
</tr>

<tr>
<td>
New Issuer:
</td>
<td>
<input type=text class=tt name=issuer_dest size=$input_size_id value="$q->{issuer_dest}">
</td>
</tr>

</table>
EOM

	my $move_table = "";
	$move_table .= <<EOM;
<table border=0 style='border-collapse:collapse'>
$colgroup

<tr>
<td>
<input type=submit name=move value="Move">
<input type=submit name=move_back value="Back">
</td>
<td class=small>
Move units from one location to another.
</td>
</tr>

<tr>
<td>
Quantity:
</td>
<td>
<input type=text class=tt name=move_qty size=$input_size_qty value="$q->{move_qty}">
</td>
</tr>

<tr>
<td>
Origin:
</td>
<td>
<input type=text class=tt name=move_orig size=$input_size_id value="$q->{move_orig}">
</td>
</tr>

<tr>
<td>
Destination:
</td>
<td>
<input type=text class=tt name=move_dest size=$input_size_id value="$q->{move_dest}">
</td>
</tr>

</table>
EOM

	my $touch_table = "";
	$touch_table .= <<EOM;
<table border=0 style='border-collapse:collapse'>
$colgroup

<tr>
<td>
<input type=submit name=touch value="Touch">
</td>
<td class=small>
Touch a location directly to see its value.
</td>
</tr>

<tr>
<td>
Location:
</td>
<td>
<input type=text class=tt name=touch_loc size=$input_size_id value="$q->{touch_loc}">
</td>
</tr>

</table>
EOM

	my $look_table = "";
	$look_table .= <<EOM;
<table border=0 style='border-collapse:collapse'>
$colgroup

<tr>
<td>
<input type=submit name=look value="Look">
</td>
<td class=small>
Look at a location by its hash.
</td>
</tr>

<tr>
<td>
Hash:
</td>
<td>
<input type=text class=tt name=look_hash size=$input_size_hash value="$q->{look_hash}">
</td>
</tr>

</table>
EOM

	my $hidden = $s->{html}->hidden_fields($op->slice(qw(function)));

	$site->{body} .= <<EOM;
<p>
This is an interactive tutorial to help you set up and test Grid API operations.
Be careful using sensitive locations in this tutorial, since they do show
up in plain text on this screen.

<p>
<form method=post action="" autocomplete=off>
$hidden
<table border=1 cellpadding=10 style='border-collapse:collapse'>

<tr>
<td>
$common_table
</td>
</tr>

<tr>
<td>
$buy_table
</td>
</tr>

<tr>
<td>
$issuer_table
</td>
</tr>

<tr>
<td>
$touch_table
</td>
</tr>

<tr>
<td>
$look_table
</td>
</tr>

<tr>
<td>
$move_table
</td>
</tr>

</table>

</form>
EOM

	if ($api->get("action") ne "")
	{
	my $q_result = $api->write_kv;
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
		$site->url(function => "grid_tutorial"),
		"Grid Tutorial",
		($function eq "grid_tutorial" && !$op->get("help"))
		);
	
	my $link_api =
		$site->highlight_link
		(
		$site->url(function => "grid_tutorial", help => 1),
		"Grid API",
		($function eq "grid_tutorial" && $op->get("help"))
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
