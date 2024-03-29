package page_asset;
use strict;
use archive;
use context;
use grid;
use html;
use http;
use id;
use loom_config;
use loom_qty;
use page;
use page_folder;
use random;
use sha256;

sub help_asset
	{
	page::printer_friendly() if http::get("print");

	page::emit(<<EOM
<h1> Assets </h1>
An asset is a type of value that can be moved around in the Loom system.
Before you can transact in a particular asset, you must explicitly accept it
into your wallet.  Otherwise your wallet will not recognize the asset, and you
will not see it even if someone moves it over to you through a contact point.

<h1> Accepting an asset </h1>

An asset description is a code which looks something like this:

<p class=tiny_mono style='margin-left:20px; color:blue'>
0f8fccf7c65e42d422c37ea222e700d5x2x2x466c6f77657220506574616c73x52c0dc51

<p>
Accepting that asset description into your wallet is easy.  Click Assets,
then Accept.  Then copy and paste the asset description into the Description
field and press Save.  (Hint:  double-click the description to highlight it,
then right-click Copy, then right-click Paste into the Description field.)

<h1> Why must I add assets to my wallet? </h1>
<p>
Loom users are creating new assets all the time.  Most of these you will
never hear about.  But when you <em>do</em> hear about an asset and decide to
transact in it, you must add that asset to your wallet so it can recognize it.
Otherwise you will never see that asset, even if someone tries to give some
of it to you.
<p>
We occasionally hear complaints that adding a new asset is a difficult and
mind-bending chore.  However, we think that adding a new asset to your Loom
wallet is <em>far</em> easier than what you have to do now in non-Loom systems.
In the non-Loom world, every time you want to transact in a new type of asset,
you must create a brand new account in a totally separate system, with yet
another user name and password to track.
<p>
In Loom, all you have to do is copy and paste the asset description into your
<em>existing</em> wallet.  It doesn't get any simpler than that!

<h1> Validating an asset </h1>
When you add a new asset to your wallet, be sure you are getting the
information from a <em>reliable source</em>, preferably from the original
authoritative web site of the company issuing the asset.  You should not
trust asset descriptions recommended to you by strangers or even friends
without first checking with an authoritative source.
<p>
It is <span class=alarm>your responsibility</span> to avoid accepting a
counterfeit asset.  For example, let's say that an online florist
has issued an asset which they call "Flower Petals," and they accept
this as payment for flower deliveries.  The company documents the asset on
their web site as:

<p class=tiny_mono style='margin-left:20px; color:blue'>
0f8fccf7c65e42d422c37ea222e700d5x2x2x466c6f77657220506574616c73x52c0dc51

<p>
<em>That</em> is the one you should accept, because it is from an
authoritative and trusted source.  But what if someone else claims that
<em>this</em> is the true Flower Petal asset?

<p class=tiny_mono style='margin-left:20px; color:blue'>
0f8fccf7c65e42d422c37ea222e7005dx2x2x466c6f77657220506574616c73x02a7f284

<p>
<em>Ignore</em> that one!  He is either trying to fool you into accepting a
counterfeit asset, or he himself was fooled into accepting it.  Stick with the
asset description on the company's own web site!

<p>
Keep in mind that once you've accepted the genuine asset into your wallet, you
don't have to worry about it any more.  You only have to be careful when you
first accept it.
EOM
);
	return;
	}

sub page_asset_list
	{
	# LATER use CSS style sheet

	my $odd_color = loom_config::get("odd_row_color");
	my $even_color = loom_config::get("even_row_color");

	my $odd_row = 1;  # for odd-even coloring

	my $loc_folder = page_folder::current_location();

	my @list_type = page_folder::get_sorted_list_type();

	my $table = "";

	my $link_accept = page::highlight_link(
		html::top_url(http::slice("function"), "action","accept",
			http::slice("session")),
		"Accept an existing asset into your wallet.");

	my $link_create = page::highlight_link(
		html::top_url(http::slice("function"), "action","create",
			http::slice("session")),
		"Create a brand new asset which you issue.");

	my $hidden = html::hidden_fields(http::slice(qw(function session)));

	$table .= <<EOM;
<h1> Asset List </h1>
These are the asset types which your wallet currently recognizes.
<p>$link_accept</p>
<p>$link_create</p>
<form method=post action="" autocomplete=off>
$hidden
<table border=0 cellpadding=1 style='border-collapse:collapse;'>
<colgroup>
<col width=80>
<col width=570>
</colgroup>

<tr>
<td class=wallet_bold_clean align=center>
<input class=smaller type=submit name=save_enabled value="Save">
<br>
Enabled
</td>
<td class=wallet_bold_clean valign=bottom>
Name
</td>
</tr>
EOM

	my $context = context::new(http::slice(qw(function session)));

	my $save_enabled = http::get("save_enabled") ne "";

	for my $type (@list_type)
	{
	my $type_name = page_folder::map_id_to_nickname("type",$type);
	my $q_type_name = html::quote($type_name);

	my $url = html::top_url("function",http::get("function"),
		"name",$type_name, "session",http::get("session"));

	$q_type_name =
	qq{<a href="$url" title="View or edit this asset.">$q_type_name</a>};

	my $row_color = $odd_row ? $odd_color : $even_color;
	$odd_row = 1 - $odd_row;

	my $is_disabled = page_folder::get("type_disable.$type");
	my $is_enabled = !$is_disabled;

	if ($save_enabled)
		{
		$is_enabled = http::get("enable_$type") ne "";
		my $disable_flag = $is_enabled ? "" : "1";
		page_folder::put("type_disable.$type",$disable_flag);
		}

	my $checked = $is_enabled ? " checked" : "";

	my $enable_control =
	qq{<input$checked type=checkbox name=enable_$type>};

	$table .= <<EOM;
<tr style='height:28px; background-color:$row_color'>
<td align=center>
$enable_control
</td>
<td style='padding-left:5px'>
$q_type_name
</td>
</tr>
EOM
	}

	$table .= <<EOM;
</table>
</form>
EOM

	if ($save_enabled)
		{
		page_folder::save();
		}

	page::emit($table);

	return;
	}

sub add_asset
	{
	my $type = shift;
	my $name = shift;
	my $scale = shift;
	my $min_precision = shift;

	my $result = {};
	$result->{error} = "";

	my $loc_folder = page_folder::current_location();

	my $list_type = page_folder::get("list_type");
	my @list_type = split(" ",$list_type);
	push @list_type, $type;

	$list_type = join(" ",@list_type);

	page_folder::put("list_type",$list_type);
	page_folder::put("type_name.$type", $name);
	page_folder::put("type_scale.$type", $scale);
	page_folder::put("type_min_precision.$type", $min_precision);

	# Clear the deleted flag if any.
	page_folder::put("type_del.$type","");

	my $write = page_folder::save();
	if (context::get($write,"status") ne "success")
		{
		$result->{error} = "insufficient_usage";
		}

	if ($result->{error} eq "")
		{
		# Now let's attempt to become the issuer for this type.

		# LATER perhaps ONLY with Create.  If you Accept an asset, just add it?

		my $loc_zero = "0" x 32;
		grid::buy($type, $loc_zero, $loc_folder);
		grid::buy($type, $loc_folder, $loc_folder);
		grid::issuer($type,$loc_zero,$loc_folder);
		grid::sell($type,$loc_zero,$loc_folder);
		}

	return $result;
	}

sub asset_edit_form
	{
	my $flavor = shift;   # edit or create

	die if $flavor ne "edit" && $flavor ne "create";

	my $type_name;
	my $type;
	my $scale;
	my $precision;

	my $edit_form = "";

	my $q_error_id = "";
	my $q_error_name = "";
	my $q_error_scale = "";
	my $q_error_precision = "";
	my $q_error_stanza = "";

	my $update_folder = 0;

	if ($flavor eq "edit")
		{
		$type_name = http::get("name");
		$type = page_folder::map_nickname_to_id("type",$type_name);

		die if $type eq "";

		$scale = page_folder::get("type_scale.$type");
		$precision = page_folder::get("type_min_precision.$type");
		}
	else
		{
		$type = http::get("new_id");
		$type = html::trimblanks($type);
		if ($type eq "")
			{
			$type = random::hex();
			}

		$type_name = "";
		$scale = "";
		$precision = "";
		}

	my $new_name = http::get("new_name");
	my $new_scale = http::get("new_scale");
	my $new_precision = http::get("new_precision");

	my $submitted_form =
		(
		http::get("save") ne ""
		|| $new_name ne ""
		|| $new_scale ne ""
		|| $new_precision ne ""
		);

	if (!$submitted_form)
		{
		$new_name = $type_name;
		$new_scale = $scale;
		$new_precision = $precision;
		}
	else
		{
		if ($flavor eq "create")
			{
			# Check the ID if creating a new asset.

			if (!id::valid_id($type))
				{
				$q_error_id = "Invalid ID";
				$q_error_stanza .= <<EOM;
<p>
That ID is invalid.  It should be a "hexadecimal" number, consisting of exactly
32 digits 0-9 or a-f.
EOM
				}
			else
				{
				# Make sure the ID is not already used in this folder.
				my $other_name = page_folder::map_id_to_nickname("type",$type);
				if ($other_name ne "")
					{
					$q_error_id = "Already used";
					$q_error_stanza .= <<EOM;
<p>
That ID is already used by another asset in your wallet.
EOM
					}
				}
			}

		if ($new_name eq "")
			{
			$q_error_name = "Missing name";
			$q_error_stanza .= <<EOM;
<p>
Please enter a name for this asset.
EOM
			}
		else
			{
			my $other_type = page_folder::map_nickname_to_id("type",$new_name);

			if ($other_type ne "" && $other_type ne $type)
				{
				$q_error_name = "Already used";
				$q_error_stanza .= <<EOM;
<p>
Sorry, that name is already used for another asset.
EOM
				}
			elsif ($new_name ne $type_name)
				{
				$update_folder = 1;
				}
			}

		{
		$new_scale = html::trimblanks($new_scale);

		if (!loom_qty::valid_scale($new_scale))
			{
			$q_error_scale = "Only integers from 0 to 99 are allowed";
			$q_error_stanza .= <<EOM;
<p>
The Scale must be a whole number in the range 0 through 99.
EOM
			}
		elsif ($new_scale ne $scale)
			{
			$update_folder = 1;
			}
		}

		{
		$new_precision = html::trimblanks($new_precision);

		if (!loom_qty::valid_scale($new_precision))
			{
			$q_error_precision = "Only integers from 0 to 99 are allowed";
			$q_error_stanza .= <<EOM;
<p>
The Precision must be a whole number in the range 0 through 99.
EOM
			}
		elsif ($new_precision ne $precision)
			{
			$update_folder = 1;
			}
		}

		$update_folder = 0 if $q_error_stanza ne "";

		if ($update_folder)
			{
			# Everything is good, save the changes.

			http::put("name",$new_name);

			if ($flavor eq "edit")
			{
			page_folder::put("type_name.$type",$new_name);
			page_folder::put("type_scale.$type",$new_scale);
			page_folder::put("type_min_precision.$type",$new_precision);

			page_folder::save();
			}
			else
			{
			my $result = add_asset($type,$new_name,$new_scale,
				$new_precision);

			if ($result->{error} eq "")
				{
				return ($update_folder,$edit_form);
				}
			else
				{
				$update_folder = 0;
				$q_error_stanza .= <<EOM;
<p>
Sorry, you do not have enough usage tokens to complete this operation.
EOM
				}
			}

			}
		}

	my $hidden = html::hidden_fields(
		http::slice(qw(function name action session)));

	my $q_new_name = html::quote($new_name);
	my $q_new_scale = html::quote($new_scale);
	my $q_new_precision = html::quote($new_precision);

	$q_error_id = qq{<span class=alarm>$q_error_id</span>}
		if $q_error_id ne "";
	$q_error_name = qq{<span class=alarm>$q_error_name</span>}
		if $q_error_name ne "";
	$q_error_scale = qq{<span class=alarm>$q_error_scale</span>}
		if $q_error_scale ne "";
	$q_error_precision = qq{<span class=alarm>$q_error_precision</span>}
		if $q_error_precision ne "";

	page::set_focus("new_name");
	page::set_focus("new_precision") if $q_error_precision ne "";
	page::set_focus("new_scale") if $q_error_scale ne "";
	page::set_focus("new_name") if $q_error_name ne "";
	page::set_focus("new_id") if $q_error_id ne "";

	if ($flavor eq "edit")
	{
	$edit_form .= <<EOM;
<h2>Edit the details of this asset:</h2>
EOM
	}
	else
	{
	$edit_form .= <<EOM;
<h1> Create a brand new asset which you issue. </h1>
<p>
Here you may create a brand new asset that has never been seen before.
You become the sole issuer of the new asset, paying it into existence!
<p>
After you create the asset, you will see a <em>negative</em> balance on the
Home page.  That indicates that the asset is a <em>liability</em> to you.
Initially you'll have a balance of -0 (negative 0), because you haven't
spent any into existence yet.  But as you start paying the asset out, you'll
see your balance drop further negative.
<p>
At all times the size of your negative balance will equal the total quantity
of the asset held by all others in the system.  That way, you will always know
how much is "out there" (currently issued).
<p>
<h2>Enter the new asset details here:</h2>
EOM
	}

	my $link_cancel;
	{
	my $url = html::top_url(http::slice("function","name","session"));
	$link_cancel = qq{<a class=large style='padding-left:20px' href="$url">Cancel</a>};
	}

	my $dsp_id;

	if ($flavor eq "edit")
		{
		$dsp_id = qq{<td class=large_mono>$type</td>};
		}
	else
		{
		my $input_size_id = 32 + 4;
		my $q_type = html::quote($type);
		$dsp_id = <<EOM;
<td>
<input type=text class=mono name=new_id size=$input_size_id value="$q_type">
$q_error_id
</td>
EOM
		}

	$edit_form .= <<EOM;
<form method=post action="" autocomplete=off>
$hidden

<table border=0 cellpadding=2 style='border-collapse:collapse; margin-left:20px'>
<colgroup>
<col width=100>
</colgroup>

<tr>
<td>ID:</td>
$dsp_id
</tr>
EOM
	$edit_form .= <<EOM;
<tr>
<td></td>
<td style='padding-bottom:15px'>
EOM
	$edit_form .= <<EOM if $flavor ne "edit";
Here we have conveniently inserted a random ID for the new asset.
EOM
	$edit_form .= <<EOM;
</td>
</tr>
EOM
	$edit_form .= <<EOM;

<tr>
<td>
Name:
</td>
<td>
<input type=text name=new_name size=40 value="$q_new_name">
$q_error_name
</td>
</tr>

<tr>
<td></td>
<td style='padding-bottom:15px'>
Enter a nickname for the asset.
</td>
</tr>

<tr>
<td>
Scale:
</td>
<td>
<input type=text name=new_scale size=5 value="$q_new_scale">
$q_error_scale
</td>
</tr>

<tr>
<td></td>
<td style='padding-bottom:15px'>
Enter a number which tells the system where to put the decimal point.  For
example if you enter 7 then you can use quantities with 7 decimal places such
as 12.3456789.  If you enter 0 or leave it blank then you can use only whole
number quantities.
</td>
</tr>

<tr>
<td>
Min Precision:
</td>
<td>
<input type=text name=new_precision size=5 value="$q_new_precision">
$q_error_precision
</td>
</tr>

<tr>
<td></td>
<td style='padding-bottom:15px'>
This is optional.  Enter a number here if you want to force the system to
display a minimum number of decimal places.  For example if you enter 3 then
the quantity 12.1 will display as 12.100.
</td>
</tr>

<tr>
<td></td>
<td>
<input type=submit name=save value="Save">
$link_cancel
</td>
</tr>
EOM

	$edit_form .= <<EOM;

</table>

$q_error_stanza

</form>
EOM

	return ($update_folder,$edit_form);
	}

sub page_zoom_asset_heading
	{
	my $type_name = http::get("name");
	my $type = page_folder::map_nickname_to_id("type",$type_name);
	my $q_type_name = html::quote($type_name);

	my $q_title = qq{ title="Send to recipient of payment."};

	my $q_description = asset_description($type);

	page::emit(<<EOM
<h1> Asset : $q_type_name </h1>
<p> Description :
<span class=tiny_mono style='color:green; font-weight:bold'$q_title>
$q_description
</span>
</p>
EOM
);
	}

sub asset_description
	{
	my $type = shift;

	my $type_name = page_folder::get("type_name.$type");
	my $scale = page_folder::get("type_scale.$type");
	my $precision = page_folder::get("type_min_precision.$type");

	my $hex_name = unpack("H*",$type_name);
	my $description = $type."x".$scale."x".$precision."x".$hex_name;

	# Now append a hash checksum of the main description.
	my $checksum = substr(unpack("H*",sha256::bin($description)),0,8);

	$description .= "x$checksum";

	return $description;
	}

sub page_zoom_asset
	{
	my $type_name = http::get("name");
	my $q_type_name = html::quote($type_name);

	my $type = page_folder::map_nickname_to_id("type",$type_name);
	if ($type eq "")
		{
		page_asset_list();
		return;
		}

	my $action = http::get("action");

	my $edit_form = "";

	my $scale = page_folder::get("type_scale.$type");
	my $precision = page_folder::get("type_min_precision.$type");

	if ($action eq "rename")
		{
		my $length = html::display_length($q_type_name);
		my $size = $length + 3;
		$size = 25 if $size < 25;
		$size = 70 if $size > 70;

		page::set_focus("new_name");

		my $hidden = html::hidden_fields(
			http::slice(qw(function name action session)));

		my $q_new_name = $q_type_name;

		my $new_name = http::get("new_name");

		my $error = "";

		my $rename_complete = 0;

		if ($new_name ne "")
		{
		$q_new_name = html::quote($new_name);

		if ($new_name eq $type_name)
			{
			# No change
			$rename_complete = 1;
			}
		else
			{
			# Make sure the new name is not already used in the folder.
			my $new_type = page_folder::map_nickname_to_id("type",$new_name);

			if ($new_type eq "")
				{
				# OK, we're good to go, let's save the new name.

				page_folder::put("type_name.$type",$new_name);

				page_folder::save();

				http::put("name",$new_name);

				$type_name = $new_name;
				$q_type_name = html::quote($type_name);

				$rename_complete = 1;
				}
			else
				{
				$error = <<EOM;
<p>
Sorry, that name is already used for another asset.  Please try a different
name.
EOM
				}
			}
		}

		if (!$rename_complete)
		{
		my $link_cancel;
		{
		my $url = html::top_url(http::slice("function","name","session"));
		$link_cancel = qq{<a class=large style='padding-left:20px' href="$url">Cancel</a>};
		}

		page_zoom_asset_heading();
		page::emit(<<EOM
<p>
Enter the new name you would like to use for this asset:
<form method=post action="" autocomplete=off>
$hidden
<div>
<input type=text size=$size name=new_name value="$q_new_name">
<input type=hidden name=old_name value="$q_type_name">
<input type=submit name=save value="Save" class=small>
$link_cancel
</div>
$error
</form>
EOM
);
		return;
		}

		}

	if ($action eq "delete")
	{

	if (http::get("confirm_delete") ne "" && http::get("delete_now") ne "")
		{
		# Confirmed delete

		my $found = 0;

		# First search the history to see if there's an entry with this
		# asset ID.

		{
		my $list_H = page_folder::get("list_H");
		my @list_H = split(" ",$list_H);

		for my $h_id (@list_H)
			{
			my $this_type = page_folder::get("H_type.$h_id");
			next if $this_type ne $type;
			$found = 1;
			last;
			}
		}

		my $old_list_type = page_folder::get("list_type");
		my @old_list_type = split(" ",$old_list_type);

		my @new_list_type = ();

		for my $item (@old_list_type)
			{
			next if $item eq $type;
			push @new_list_type, $item;
			}

		my $new_list_type = join(" ",@new_list_type);

		page_folder::put("list_type",$new_list_type);

		if ($found)
			{
			# We still have a history entry which refers to this asset, so
			# let's just mark the asset as deleted instead of clearing all
			# the details.  That way we can still render history properly.

			page_folder::put("type_del.$type",1);
			}
		else
			{
			page_folder::put("type_name.$type","");
			page_folder::put("type_scale.$type","");
			page_folder::put("type_min_precision.$type","");
			}

		page_folder::save();

		# Attempt to sell the underlying locations for this type.
		my $loc_folder = page_folder::current_location();

		my @list_loc = split(" ",page_folder::get("list_loc"));
		for my $loc (@list_loc)
			{
			grid::sell($type,$loc,$loc_folder);
			}

		my $val = grid::touch($type,$loc_folder);
		if ($val eq "-1")
			{
			# This is a brand new type with no outstanding liability, so let's
			# go ahead and move the issuer location back to zero.

			my $loc_zero = "0" x 32;
			grid::buy($type, $loc_zero, $loc_folder);
			grid::issuer($type,$loc_folder,$loc_zero);
			grid::sell($type,$loc_folder,$loc_folder);
			grid::sell($type,$loc_zero,$loc_folder);
			}

		page_asset_list();
		return;
		}
	}
	elsif ($action eq "edit")
	{
	my $updated;
	($updated,$edit_form) = asset_edit_form("edit");

	if ($updated)
		{
		# Read the name again in case it was changed.
		$type_name = http::get("name");
		$q_type_name = html::quote($type_name);

		$edit_form .= <<EOM;
<p>
<span style='color:green'>Changes saved.
Click Cancel when you are done making changes.
</span>
EOM
		}
	}

	page_zoom_asset_heading();

	if ($action ne "delete" && $action ne "edit")
	{
	my $link_refresh = page::highlight_link(
		html::top_url(http::slice("function","name","session")),
		"Refresh");

	my $link_pay = page::highlight_link(
		html::top_url("function","folder", "type",http::get("name"),
			http::slice("session")),
		"Pay");

	my $link_rename = page::highlight_link(
		html::top_url(http::slice("function","name","session"), "action","rename"),
		"Rename");

	my $link_edit = page::highlight_link(
		html::top_url(http::slice("function","name","session"), "action","edit"),
		"Edit details");

	my $link_delete = page::highlight_link(
		html::top_url(http::slice("function","name","session"), "action","delete"),
		"Delete");

	page::emit(<<EOM
<p>
<b>Options:</b>
<span style='padding-left:15px'> $link_refresh </span>
<span style='padding-left:15px'> $link_pay </span>
<span style='padding-left:15px'> $link_rename </span>
<span style='padding-left:15px'> $link_edit </span>
<span style='padding-left:15px'> $link_delete </span>
</p>
EOM
);
	}

	my $display = {};
	$display->{flavor} = "zoom_asset";
	$display->{type_name} = $type_name;

	my $table = page_folder::value_table($display);
	my $has_assets = $display->{involved_type}->{$type};

	if ($action eq "delete")
	{
	my $hidden = html::hidden_fields(
		http::slice(qw(function name action session)));

	page::emit(<<EOM
<form method=post action="" autocomplete=off>
$hidden
EOM
);

	page::emit(<<EOM
<h2 class=alarm>Confirm deletion</h2>
EOM
);

	if ($has_assets)
	{
	page::emit(<<EOM
If you insist on deleting this asset, you risk <span class=alarm>losing</span>
all of the assets below.
EOM
);
	}

	my $link_cancel;
	{
	my $url = html::top_url(http::slice("function","name","session"));
	$link_cancel = qq{<a class=large style='padding-left:20px' href="$url">Cancel</a>};
	}

	page::emit(<<EOM
<p>
<input type=checkbox name=confirm_delete>
Check the box to confirm, then press
<input type=submit name=delete_now value="Delete Now!" class=small>
$link_cancel
EOM
);

	page::emit(<<EOM
</form>
EOM
);

	}
	elsif ($action eq "edit")
	{
	page::emit($edit_form);
	}

	# LATER maybe single out the issuer case specially.

	if (0)
	{
	if ($has_assets)
	{
	page::emit(<<EOM
<p>
You have this asset at these contact points:
EOM
);
	}
	else
	{
	page::emit(<<EOM
<p>
You do not have this asset at any contact points.
EOM
);
	}
	}

	page::emit($table);

	return;
	}

sub page_add_asset
	{
	my $type = "";
	my $scale = "";
	my $min_precision = "";
	my $name = "";

	my $q_error_stanza = "";
	my $submitted_form = 0;
	my $duplicate_id = 0;
	my $duplicate_name = 0;

	my $entry_form = "";

	my $description = http::get("description");

	# Translate all runs of non-printable characters to a single space.
	# This makes the code more forgiving, for example if someone copies
	# and pastes an asset description that has been wrapped across multiple
	# lines in an email.  Those can have embedded sequences such as \015\n.

	$description =~ s/[^ -~]+/ /g;
	$description = html::trimblanks($description);

	http::put("description",$description);

	my $q_description = html::quote($description);

	page::set_focus("description");

	my $hidden = html::hidden_fields(
		http::slice(qw(function action session)));

	my $link_cancel;
	{
	my $url = html::top_url(http::slice("function","session"));
	$link_cancel = qq{<a class=large style='padding-left:20px' href="$url">Cancel</a>};
	}

	$entry_form = <<EOM;
<h1> Accept an existing asset into your wallet. </h1>
Copy and paste the asset description into the field below and press Save.
<form method=post action="" autocomplete=off>
$hidden
<div>
<input class=tiny_mono type=text name=description size=100 value="$q_description">
<p>
<input type=submit name=save value="Save">
$link_cancel
</div>
</form>
EOM

	if ($description ne "" || http::get("save") ne "")
	{
	# User submitted the form.

	$submitted_form = 1;
	my $good_format = 0;

	if ($description eq "")
	{
	$q_error_stanza .= <<EOM;
<p>
Please enter the asset description.
EOM
	}
	elsif ($description =~
	/^([a-f0-9]{32})x([0-9]*)x([0-9]*)x([a-f0-9]+)x([a-f0-9]{8})$/
	)
	{
	# New style format.
	# This format is:  <id>x<scale>x<precision>x<name>x<checksum>
	#
	# The id, name, and checksum are hexadecimal.  The scale and
	# precision are decimal.

	$type = $1;
	$scale = $2;
	$min_precision = $3;

	my $checksum = $5;

	# Remove any weird binary chars from name.
	$name = pack("H*",$4);
	$name = html::remove_nonprintable($name);

	# Verify the checksum.

	# Chop off the checksum.
	my $inner_description = substr($description,0,-9);

	my $expect_checksum = substr(unpack("H*",
		sha256::bin($inner_description)),0,8);

	if ($expect_checksum eq $checksum)
		{
		# checksum is good
		$good_format = 1;
		}
	}
	elsif ($description =~
	/^id:\s*(\S+)\s+scale:\s*(\S+)\s+precision:\s*(\S+)\s+name:\s*(.*)$/
	)
	{
	# Old style format.
	$type = $1;
	$scale = $2;
	$min_precision = $3;
	$name = $4;

	$good_format = 1;
	}

	if (!$good_format && $q_error_stanza eq "")
	{
	$q_error_stanza .= <<EOM;
<p>
Sorry, that asset description does not have the right format.
Please make sure you copied and pasted it correctly.

<p>
Be sure to copy and paste the <em>entire</em> description, which should look
something like this:
<p class=small style='margin-left:30px'>
0f8fccf7c65e42d422c37ea222e700d5x2x2x466c6f77657220506574616c73x52c0dc51

<p>
or perhaps like this (from an older source):

<p class=small style='margin-left:30px'>
id: 0f8fccf7c65e42d422c37ea222e700d5 scale: 2 precision: 2 name: Flower Petals
EOM
	}

	}

	if ($submitted_form && $q_error_stanza eq "")
	{
	# Looks good so far, let's do some more checking.

	if ($type eq "")
		{
		$q_error_stanza .= <<EOM;
<p>
The asset ID is missing.
EOM
		}
	elsif (!id::valid_id($type))
		{
		$q_error_stanza .= <<EOM;
<p>
That asset ID is invalid.
EOM
		}
	else
		{
		my $old_name = page_folder::map_id_to_nickname("type",$type);

		# If the asset is marked as deleted, pretend like you didn't see it
		# so it can be added again.

		if (page_folder::get("type_del.$type"))
			{
			$old_name = "";
			}

		if ($old_name ne "")
			{
			my $q_old_name = html::quote($old_name);
			my $q_name = html::quote($name);

			$duplicate_id = 1;

			if ($old_name eq $name)
			{
			$q_error_stanza .= <<EOM;
<p>
You have already added this asset <b>$q_name</b> to your wallet.
There is no need to add it again.
EOM
			}
			else
			{
			$q_error_stanza .= <<EOM;
<p>
You have already added this asset ID to your wallet using the name
<b>$q_old_name</b>.  The new one you are trying to add is named
<b>$q_name</b>, but let's just ignore it and stick with your old name.
Just click Cancel to get out of here.
EOM
			}

			}
		}

	if ($name eq "")
		{
		$q_error_stanza .= <<EOM;
<p>
The asset name is missing.
EOM
		}
	else
		{
		my $other_type = page_folder::map_nickname_to_id("type",$name);
		if ($other_type ne "" && $other_type ne $type)
			{
			$duplicate_name = 1;

			if (!$duplicate_id)
			{
			my $q_name = html::quote($name);
			$q_error_stanza .= <<EOM;
<p>
This new asset is named <b>$q_name</b>, but you already have an asset with
that name in your wallet.  This could be an innocent name conflict, since
asset names are not guaranteed to be unique across the whole system.  Or
it could be someone trying to scam you, passing off a fake asset with a
misleading name.
<p>
We advise you to verify this new asset and make sure you really want to
accept it.  If so, you can rename your old asset currently called
<b>$q_name</b>, changing it slightly to distinguish it from this new one.
Then you can try adding this one again.  After you add it, you can change its
name as well.
<p>
For example, you could distinguish the two assets by including the issuer's
name, ending up with something like "<b>Alice $q_name</b>" and
"<b>Bob $q_name</b>".  That way it is <em>very clear</em> what each asset
means to you.
EOM
			}

			}
		}

	{
	$scale = html::trimblanks($scale);

	if (!loom_qty::valid_scale($scale))
		{
		$q_error_stanza .= <<EOM;
<p>
The scale number is invalid.
EOM
		}
	}

	{
	$min_precision = html::trimblanks($min_precision);

	if (!loom_qty::valid_scale($min_precision))
		{
		$q_error_stanza .= <<EOM;
<p>
The minimum precision number is invalid.
EOM
		}
	}

	if ($q_error_stanza eq "")
	{
	# OK, it's all perfect, let's try to add the asset.

	my $result = add_asset($type,$name,$scale,$min_precision);

	if ($result->{error} eq "")
		{
		}
	elsif ($result->{error} eq "insufficient_usage")
		{
		$q_error_stanza .= <<EOM;
<p>
Sorry, you do not have enough usage tokens to complete this operation.
EOM
		}

	if ($result->{error} eq "")
		{
		# Zoom in on the asset page after adding.

		http::put("name",$name);
		page_zoom_asset();

		return;
		}
	}

	}

	page::emit($entry_form);
	page::emit($q_error_stanza) if $q_error_stanza ne "";

	return;
	}

sub page_create_asset
	{
	my ($updated,$edit_form) = asset_edit_form("create");

	if ($updated)
		{
		page_zoom_asset();
		return;
		}

	page::emit($edit_form);

	return;
	}

sub respond
	{
	page::set_title("Assets");

	my $action = http::get("action");

	if (http::get("help"))
		{
		help_asset();
		}
	elsif ($action eq "accept")
		{
		page_add_asset();
		}
	elsif ($action eq "create")
		{
		page_create_asset();
		}
	elsif ($action eq "" || $action eq "rename" || $action eq "edit"
		|| $action eq "delete")
		{
		if (http::get("name") ne "")
			{
			page_zoom_asset();
			}
		else
			{
			page_asset_list();
			}
		}
	else
		{
		page_asset_list();
		}

	return;
	}

return 1;
