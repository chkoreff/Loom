package page_grid_tutorial;
use strict;
use api;
use context;
use html;
use http;
use loom_config;
use page;
use page_help;

sub links
	{
	my $function = http::get("function");

	page::top_link(page::highlight_link(html::top_url(),"Home"));
	page::top_link(page::highlight_link(html::top_url("help",1),"Advanced"));

	my $link_tutorial =
		page::highlight_link(
		html::top_url("function","grid_tutorial"),
		"Grid Tutorial",
		($function eq "grid_tutorial" && !http::get("help"))
		);

	my $link_api =
		page::highlight_link(
		html::top_url("function","grid_tutorial", "help",1),
		"Grid API",
		($function eq "grid_tutorial" && http::get("help"))
		);

	page::top_link($link_api);
	page::top_link($link_tutorial);

	return;
	}

sub respond
	{
	page::set_title("Grid Tutorial");
	links();

	if (http::get("help"))
		{
		# LATER get rid of these
		page_help::topic("grid");
		return;
		}

	my $api = context::new();

	context::put($api,"function","grid");

	if (http::get("buy") ne "")
		{
		context::put($api,
			"action","buy",
			"type",http::get("common_type"),
			"loc",http::get("buy_loc"),
			"usage",http::get("buy_usage"),
			);
		}
	elsif (http::get("sell") ne "")
		{
		context::put($api,
			"action","sell",
			"type",http::get("common_type"),
			"loc",http::get("buy_loc"),
			"usage",http::get("buy_usage"),
			);
		}
	elsif (http::get("issuer") ne "")
		{
		context::put($api,
			"action","issuer",
			"type",http::get("common_type"),
			"orig",http::get("issuer_orig"),
			"dest",http::get("issuer_dest"),
			);
		}
	elsif (http::get("touch") ne "")
		{
		context::put($api,
			"action","touch",
			"type",http::get("common_type"),
			"loc",http::get("touch_loc"),
			);
		}
	elsif (http::get("look") ne "")
		{
		context::put($api,
			"action","look",
			"type",http::get("common_type"),
			"hash",http::get("look_hash"),
			);
		}
	elsif (http::get("move") ne "")
		{
		context::put($api,
			"action","move",
			"type",http::get("common_type"),
			"qty",http::get("move_qty"),
			"orig",http::get("move_orig"),
			"dest",http::get("move_dest"),
			);
		}
	elsif (http::get("move_back") ne "")
		{
		# Just a convenient way to move in the opposite direction, e.g.
		# to undo the last move.

		my $qty = http::get("move_qty");
		if ($qty =~ /^-/)
			{
			$qty = substr($qty,1);
			}
		else
			{
			$qty = "-$qty";
			}

		context::put($api,
			"action","move",
			"type",http::get("common_type"),
			"qty",$qty,
			"orig",http::get("move_orig"),
			"dest",http::get("move_dest"),
			);
		}

	my $orig_api;

	if (context::get($api,"action") ne "")
		{
		# First make a copy of the $api object so we can show the url below.
		$orig_api = context::new(context::pairs($api));
		api::respond($api);
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
		$q->{$field} = html::quote(http::get($field));
		}

	# Allow a little extra room for display.
	my $input_size_id = 32 + 4;
	my $input_size_hash = 2 * $input_size_id;
	my $input_size_qty = 45;

	my $colgroup = <<EOM;
<colgroup>
<col width=140>
<col width=510>
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
<input type=text class=mono name=common_type size=$input_size_id value="$q->{common_type}">
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
<input type=submit class=small name=buy value="Buy">
<input type=submit class=small name=sell value="Sell">
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
<input type=text class=mono name=buy_loc size=$input_size_id value="$q->{buy_loc}">
</td>
</tr>

<tr>
<td>
Usage location:
</td>
<td>
<input type=text class=mono name=buy_usage size=$input_size_id value="$q->{buy_usage}">
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
<input type=submit class=small name=issuer value="Issuer">
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
<input type=text class=mono name=issuer_orig size=$input_size_id value="$q->{issuer_orig}">
</td>
</tr>

<tr>
<td>
New Issuer:
</td>
<td>
<input type=text class=mono name=issuer_dest size=$input_size_id value="$q->{issuer_dest}">
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
<input type=submit class=small name=move value="Move">
<input type=submit class=small name=move_back value="Back">
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
<input type=text class=mono name=move_qty size=$input_size_qty value="$q->{move_qty}">
</td>
</tr>

<tr>
<td>
Origin:
</td>
<td>
<input type=text class=mono name=move_orig size=$input_size_id value="$q->{move_orig}">
</td>
</tr>

<tr>
<td>
Destination:
</td>
<td>
<input type=text class=mono name=move_dest size=$input_size_id value="$q->{move_dest}">
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
<input type=submit class=small name=touch value="Touch">
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
<input type=text class=mono name=touch_loc size=$input_size_id value="$q->{touch_loc}">
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
<input type=submit class=small name=look value="Look">
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
<input type=text class=tiny_mono name=look_hash size=$input_size_hash value="$q->{look_hash}">
</td>
</tr>

</table>
EOM

	my $hidden = html::hidden_fields(http::slice(qw(function)));

	page::emit(<<EOM
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
);

	if (context::get($api,"action") ne "")
	{
	my $q_result = context::write_kv($api);
	my $url =
		loom_config::get("this_url").
		html::make_url("/",context::pairs($orig_api));

	page::emit(<<EOM
<h2>URL</h2>
<p>
<a href="$url">$url</a>
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
