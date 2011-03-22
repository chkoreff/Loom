use strict;
use archive;
use crypt_span;
use diceware;
use dttm;
use grid;
use http;
use id;
use loom_qty;
use page_asset;
use page_contact;
use random;

sub put_mask_if_absent
	{
	my $mask = loom_get_cookie("mask");
	if (!valid_id($mask))
		{
		# Set the mask cookie to a new random value.
		$mask = unpack("H*",random_id());
		loom_put_cookie("mask",$mask);
		}

	return;
	}

sub page_cookie_problem
	{
	put_mask_if_absent();

	top_link(highlight_link(top_url(),"Home"));

	emit(<<EOM
<h2> This site requires cookies! </h2>
This site requires cookies in order to function properly, but it appears that
you have disabled them in your browser.  Please change your browser preferences
to allow cookies for this site.

<h2> Why does this site require cookies? </h2>
We could allow you to log in without cookies, but that would be a major
<em>security hazard</em>.  Someone could look over your shoulder without
your knowledge and see the secret session ID at the top of your browser.
If he entered that same session ID in his own browser, he would be logged
in <em>as you</em> and could steal all your assets.
<p>
A cookie prevents that.  A "shoulder surfer" might still see the session ID,
but without the cookie value which is stored invisibly inside your browser,
the session ID is useless.
EOM
);

	return;
	}

# LATER 012911 You'll need to bracket the folder operations in trans/begin
# and trans/commit.  In particular, updating the session id in the archive
# requires two writes.  Those should be atomic.  This currently doesn't
# matter, primarily because the wallet code is not doing its operations
# "over the wire" yet (i.e., it's using an entirely local API).  But if
# you do run the wallet interface from a remote client, you should use
# the transaction mechanism to be truly safe.

my $g_folder_object;
my $g_folder_location;
my $g_folder_reclaim;
my $g_folder_result;

sub folder_location
	{
	return $g_folder_location;
	}

sub folder_result
	{
	return $g_folder_result;
	}

sub read_folder
	{
	my $session = shift;

	$g_folder_location = archive_touch($session);
	$g_folder_object = archive_touch_object($g_folder_location);
	return;
	}

sub save_folder
	{
	# Write the modified folder object into the archive.
	my $write = archive_write_object($g_folder_location,$g_folder_object,
		$g_folder_location);

	# Refresh the folder object in memory.
	$g_folder_object = archive_touch_object($g_folder_location);

	# Return the result of the write operation.
	return $write;
	}

sub folder_get
	{
	my $key = shift;
	return op_get($g_folder_object,$key);
	}

sub folder_put
	{
	my $key = shift;
	my $val = shift;

	op_put($g_folder_object,$key,$val);
	}

# Format a grid value for display according to the conventions of the current
# folder.
#
# If the value is negative, we take out the extra -1 which is due to the
# 2s-complement representation.  For example a raw -1 balance in the grid
# will show as -0 on the web page, which should be more clear to the issuer.

sub display_value
	{
	my $value = shift;
	my $type = shift;

	die if !defined $type;

	my $scale = folder_get("type_scale.$type");
	my $min_precision = folder_get("type_min_precision.$type");

	return ones_complement_float($value,$scale,$min_precision);
	}

sub map_id_to_nickname
	{
	my $kind = shift;
	my $id = shift;

	my $name = folder_get($kind."_name.$id");
	return $name;
	}

sub map_nickname_to_id
	{
	my $kind = shift;
	my $name = shift;

	my $list = folder_get("list_".$kind);
	my @list = split(" ",$list);

	for my $id (@list)
		{
		my $id_name = folder_get($kind."_name.$id");
		return $id if $id_name eq $name;
		}

	return "";
	}

sub map_ids_to_nicknames
	{
	my $kind = shift;
	my $ids = shift;

	my $names = [];
	for my $id (@$ids)
		{
		push @$names, map_id_to_nickname($kind,$id);
		}

	return $names;
	}

sub get_sorted_list_loc
	{
	my $list_loc = folder_get("list_loc");
	my @list_loc = split(" ",$list_loc);

	return @list_loc if @list_loc == 0;

	my $first_loc = shift @list_loc;

	my @result =
		map { $_->[0] }
		sort { lc($a->[1]) cmp lc($b->[1]) }
		map { [$_, map_id_to_nickname("loc",$_)] }
		@list_loc
		;

	unshift @result, $first_loc;
	return @result;
	}

sub get_sorted_list_loc_enabled
	{
	my @list = get_sorted_list_loc();
	my @result;
	for my $loc (@list)
		{
		push @result, $loc if !folder_get("loc_disable.$loc");
		}

	return @result;
	}

sub get_sorted_list_type
	{
	my $list_type = folder_get("list_type");
	my @list_type = split(" ",$list_type);

	my @result =
		map { $_->[0] }
		sort { lc($a->[1]) cmp lc($b->[1]) }
		map { [$_, map_id_to_nickname("type",$_)] }
		@list_type
		;

	return @result;
	}

sub get_sorted_list_type_enabled
	{
	my @list = get_sorted_list_type();
	my @result;
	for my $loc (@list)
		{
		push @result, $loc if !folder_get("type_disable.$loc");
		}

	return @result;
	}

sub handle_login
	{
	my $out = folder_result();

	http_put("session","");
	my $passphrase = http_get("passphrase");

	my $min_length = 8;
	my $max_length = 255;

	die if $min_length > $max_length;

	if ($passphrase eq "")
		{
		op_put($out,"error_passphrase","missing");
		}
	elsif (length($passphrase) < $min_length)
		{
		op_put($out,"error_passphrase","too_small");
		op_put($out,"error_passphrase_min_length", $min_length);
		}
	elsif (length($passphrase) > $max_length)
		{
		op_put($out,"error_passphrase","too_large");
		op_put($out,"error_passphrase_max_length", $max_length);
		}
	else
		{
		my $session = passphrase_session($passphrase);
		if ($session eq "")
			{
			op_put($out,"error_passphrase","invalid");
			}

		http_put("session",$session);
		}
	}

sub configure_scan_display
	{
	my $display = shift;
	my $list_loc = shift;
	my $list_type = shift;

	my $out = folder_result();

	# When we render the main wallet display, we compute the list of all zero-
	# value locations we find so we can reclaim (sell) them automatically.

	$g_folder_reclaim = [];

	# We pass in the "1" flag to force the scan to show us 0-value locations
	# as well.

	my $rsp = grid_scan($list_loc,$list_type,1);

	op_put($out,"scan_status",op_get($rsp,"status"));
	op_put($out,"scan_error",op_get($rsp,"error"));
	op_put($out,"scan_error_max",op_get($rsp,"error_max"));

	my $usage_type = "0" x 32;

	for my $loc (split(" ",op_get($rsp,"locs")))
		{
		my @items;

		for my $pair (split(" ",op_get($rsp,"loc/$loc")))
			{
			my ($value,$type) = split(":",$pair);

			if ($value eq "0")
				{
				if ($display->{flavor} eq "move_dialog")
					{
					# We found a 0-value location, so add it to the reclaim
					# list.

					push @$g_folder_reclaim, [$loc,$type];
					}

				# However, do not include 0-value locations in the wallet
				# display.

				next;
				}

			$display->{involved_type}->{$type} = 1;
			$display->{involved_loc}->{$loc} = 1;

			push @items, [$value,$type];

			if ($type eq $usage_type)
				{
				$display->{usage_count}->{$loc} = $value;
				}
			}

		if ($display->{involved_loc}->{$loc})
			{
			push @{$display->{locations}}, $loc;
			$display->{location_items}->{$loc} = \@items;
			}
		}

	return;
	}

sub page_move_dialog
	{
	my $list_select_type = shift;
	my $list_select_loc = shift;

	my $out = folder_result();

	my $type_selector = simple_value_selector("type",
		"-- choose asset --",
		map_ids_to_nicknames("type",$list_select_type));

	my $loc_selector;

	{
	my $selector = "";
	$selector .= <<EOM;
<select name=loc>
<option value="">-- choose contact --</option>
EOM

	for my $loc (@$list_select_loc)
		{
		my $name = map_id_to_nickname("loc",$loc);

		my $q_value = html_quote($name);
		my $q_display = $q_value;

		my $selected = "";
		$selected = " selected" if http_get("loc") eq $name;

		$selector .= <<EOM;
<option$selected value="$q_value">$q_display</option>
EOM
		}

	$selector .= <<EOM;
</select>
EOM
	$loc_selector = $selector;
	}

	set_focus("qty");

	my $qty = http_get("qty");
	my $q_qty = html_quote($qty);

	my $size = html_display_length($q_qty) + 3;
	$size = 10 if $size < 10;

	my $message = "";

	{
	my $status = op_get($out,"status");
	my $color = "";

	if ($status eq "")
		{
		}
	elsif ($status eq "success")
		{
		# Don't display anything if successful: the red and green highlights
		# are enough.
		}
	else
		{
		$color = "red";
		$message = op_get($out,"error_move");

		if ($message eq "")
			{
			$message = "Fail";
			}
		elsif ($message eq "missing_qty")
			{
			$message = "Please enter a quantity.";
			set_focus("qty");
			}
		elsif ($message eq "invalid_qty")
			{
			$message = "Not a valid quantity";
			set_focus("qty");
			}
		elsif ($message eq "insufficent_usage")
			{
			$message = "You don't have enough usage tokens to do this.";
			}
		}

	if ($color ne "")
		{
		$message = "<span style='color:$color'>$message</span>";
		}
	}

	my $result = "";
	$result .= <<EOM;
<tr>
<td class=wallet_bold_clean colspan=3>
Send Money
</td>
</tr>

<tr>
<td align=right>
<b>Quantity:</b>
</td>
<td>
<input type=text size=$size name=qty value="$q_qty" style='text-align:right'>
</td>
</tr>

<tr>

<td align=right>
<b>Asset:</b>
</td>

<td colspan=2>
$type_selector
</td>

</tr>

<tr>
<td align=right>
<b>Contact:</b>
</td>
<td colspan=2>
$loc_selector
</td>
</tr>

<td align=right>
</td>

<td>
<input type=submit name=give value="Pay">
</td>

</tr>
EOM

	if ($message ne "")
	{
	$result .= <<EOM;
<tr style='height:20px;'>
<td>
</td>
<td valign=top>
$message
</td>
</tr>
EOM
	}

	return $result;
	}

sub configure_value_display
	{
	my $display = shift;

	my $loc_folder = folder_location();

	$display->{locations} = [];
	$display->{contact_title} = "";
	$display->{move_dialog} = "";
	$display->{involved_type} = {};
	$display->{involved_loc} = {};

	my @list_type = get_sorted_list_type_enabled();

	if ($display->{flavor} eq "move_dialog")
		{
		# Show all non-empty locations.

		my @list_loc = get_sorted_list_loc_enabled();

		$display->{contact_title} = "View contact";

		$display->{involved_loc}->{$loc_folder} = 1;
			# Show main folder location even if empty.

		configure_scan_display($display,\@list_loc,\@list_type);

		my @list_select_loc;

		for my $loc (@list_loc)
			{
			next if $loc eq $loc_folder;
				# don't include ourself in drop points
			push @list_select_loc, $loc;
			}

		$display->{move_dialog} =
			page_move_dialog(\@list_type,\@list_select_loc);

		# NOTE: We make ALL asset types show up in the drop-down menu.
		# That way you can move "0" quantity of it to a drop point when
		# you are creating an invitation and want the new user to inherit
		# that type, even when you have none of it yourself.
		}
	elsif ($display->{flavor} eq "zoom_contact")
		{
		my $loc = map_nickname_to_id("loc",$display->{location_name});

		if ($loc ne "")
			{
			$display->{involved_loc}->{$loc} = 1;
				# Show location even if empty.

			$display->{contact_title} = "Refresh contact";

			configure_scan_display($display,[$loc],\@list_type);
			}
		}
	elsif ($display->{flavor} eq "invite_location")  # LATER make obsolete
		{
		my $loc = map_nickname_to_id("loc",$display->{location_name});

		if ($loc ne "")
			{
			configure_scan_display($display,[$loc],\@list_type);
			}
		}
	elsif ($display->{flavor} eq "delete_type")
		{
		# Show all locations which have something of a given type.

		my @list_loc = get_sorted_list_loc_enabled();

		my $type = map_nickname_to_id("type",$display->{type_name});

		if ($type ne "")
			{
			configure_scan_display($display,\@list_loc,[$type]);
			}
		}
	}

# This is called from Contact and Asset.

# Detect any Loom coordinates with a 0 balance, and reclaim (sell) them to
# receive usage token refunds.  We only do this when we're on the main wallet
# display.

sub page_folder_value_table
	{
	my $display = shift;

	my $out = folder_result();

	configure_value_display($display);

	if ($display->{flavor} eq "move_dialog")
	{
	if (@$g_folder_reclaim)
		{
		my $loc_folder = folder_location();

		my $usage_type = "0" x 32;

		for my $pair (@$g_folder_reclaim)
			{
			my ($loc,$type) = @$pair;

			if ($loc eq $loc_folder && $type eq $usage_type)
				{
				# We don't even try to sell the usage token location for the
				# folder location itself.  The API doesn't allow it anyway,
				# and would give you a "cannot_refund" error because you cannot
				# sell a usage token location and receive the refund in that
				# same place.
				}
			else
				{
				grid_sell($type,$loc,$loc_folder);
				}
			}

		# Now re-compute the value display to reflect any recovered
		# usage tokens.

		configure_value_display($display);
		}
	}

	my $loc_folder = folder_location();

	# Now build up the HTML display of all the specified locations.

	my $table = "";
	$table .= <<EOM;
<table border=0 cellpadding=2 style='border-collapse:collapse;'>
<colgroup>
<col width=180>
<col width=380>
<col width=90>
</colgroup>
EOM

	if (op_get($out,"scan_status") eq "fail")
		{
		my $scan_error_max = op_get($out,"scan_error_max");

		$table .= <<EOM;
<tr>
<td colspan=3 style='border: solid 1px'>
<span class=alarm><b>Warning: This wallet is too big.</b></span>
Some values may be missing from this list because you are trying to examine
more than $scan_error_max at a time.  Please delete any unused contacts or
assets from this wallet, or move some of them to a brand new wallet.
</td>
</tr>
EOM
		}

	if ($display->{move_dialog} ne "")
		{
		$table .= $display->{move_dialog};

		$table .= <<EOM;
<tr style='height:28px'>
<td colspan=3>&nbsp;</td>
</tr>
EOM
		}

	for my $loc (@{$display->{locations}})
	{
	my @location_items = @{$display->{location_items}->{$loc}};

	# Show the nickname header for this contact.
	{
	my $loc_name = map_id_to_nickname("loc",$loc);

	my $url = top_url(
		"function","contact",
		"name",$loc_name,
		http_slice(qw(session)),
		);

	my $label = $loc eq $loc_folder ? "In my wallet" : "On the table";

	my $q_loc_name = html_quote($loc_name);

	my $link_view_contact = "";

	if ($display->{flavor} ne "invite_location")
		{
		$link_view_contact =
		qq{<a href="$url" title="View details of this contact.">}.
		qq{View contact</a>};
		}

	$table .= <<EOM;
<tr>
<td class=wallet_bold_clean>
$label
</td>
<td class=wallet_bold_clean style='font-size:11pt'>
$q_loc_name
</td>
<td class=wallet_normal_clean align=right>
$link_view_contact
</td>
</tr>
EOM
	}

	# Now show the individual items under this contact.

	# LATER use CSS style sheet

	my $odd_color = loom_config("odd_row_color");
	my $even_color = loom_config("even_row_color");

	my $odd_row = 1;  # for odd-even coloring

	for my $item (@location_items)
	{
	my ($value,$type) = @$item;
	my $q_value = display_value($value,$type);

	my $style = "";
	my $color = op_get($out,"color.$type.$loc");
	if ($color ne "")
		{
		# NOTE: Getting rid of the red and green display for now because
		# one user found the red slightly alarming.  But we keep the bold
		# fact to highlight what just happened.

		##$style = " style='font-weight:bold; color:$color'";
		$style = " style='font-weight:bold;'";
		}

	my $loc_name = map_id_to_nickname("loc",$loc);
	$loc_name = "" if $loc eq $loc_folder;

	my $type_name = map_id_to_nickname("type",$type);
	my $q_type_name = html_quote($type_name);

	my $link_asset = "";

	if ($display->{flavor} eq "move_dialog" && $loc ne $loc_folder)
		{
		my $url = top_url(
			"function","folder",
			"qty",$q_value,
			"loc",$loc_name,
			"type",$type_name,
			"take",1,
			http_slice(qw(session)),
			);

		$link_asset =
		qq{<a href="$url" title="Claim this asset as your own.">}
		.qq{Claim asset</a>};
		}
	elsif ($display->{flavor} ne "move_dialog"
		&& $display->{flavor} ne "invite_location")
		{
		my $url = top_url("function","asset",
			"name",$type_name, "session",http_get("session"));

		$link_asset =
		qq{<a href="$url" title="View or edit this asset.">}
		.qq{View asset</a>};
		}

	my $row_color = $odd_row ? $odd_color : $even_color;
	$odd_row = 1 - $odd_row;

	$table .= <<EOM
<tr style='height:28px; background-color:$row_color'>
<td align=right$style>
<span style='margin-right:5px'>
$q_value
</span>
</td>
<td$style>
$q_type_name
</td>
<td align=right$style>
$link_asset
</td>
</tr>
EOM
	}

	$table .= <<EOM;
<tr style='height:28px'>
<td colspan=3>&nbsp;</td>
</tr>
EOM
	}

	$table .= <<EOM;
</table>
EOM

	return $table;
	}

# LATER maybe get rid of complex build_folder_template for the purpose of
# estimating usage token cost.  Still need to support GNB links though.

sub build_folder_template
	{
	my $template = shift;

	my $build = {};

	$build->{object} = undef;
	$build->{folder_text} = "";

	$build->{location} = "";
	$build->{list_type} = [];
	$build->{list_loc} = [];

	$build->{cost} = 0;
	$build->{min_usage} = 0;

	# Go ahead and build the folder object in memory based on the invitation
	# parameters.  This enables us to display the assets the new user will
	# receive, and compute an estimate (probably perfect) of the usage tokens
	# needed to create the folder.

	{
	my $passphrase = op_get($template,"passphrase");
	$build->{location} = passphrase_location($passphrase);

	$build->{object} = op_new();

	# Build up the folder object in memory based on the invitation
	# parameters.

	{
	op_put($build->{object},"Content-Type", "loom/folder");

	# Build the list of asset types from the invitation url.

	my $install_types = [];

	{
	my $usage_type = "0" x 32;
	my $found_usage_type = 0;

	my $nT = op_get($template,"nT");
	$nT = 0 if $nT eq "";

	for my $type_no (1 .. $nT)
		{
		my $id = op_get($template,"T$type_no.id");
		my $name = op_get($template,"T$type_no.name");
		my $display = op_get($template,"T$type_no.display");

		next if $id eq "" || $name eq "";
		next if !valid_id($id);

		my $scale = "";
		my $min_precision = "";

		if ($display =~ /^(\d+)[,\.](\d+)$/)
			{
			$scale = $1;
			$min_precision = $2;
			}

		push @$install_types, [$id,$name,$scale,$min_precision];

		$found_usage_type = 1 if $id eq $usage_type;
		}

	# If usage tokens are not in the template, add them by default.
	if (!$found_usage_type)
		{
		unshift @$install_types,
		["00000000000000000000000000000000","usage tokens","",""];
		}
	}

	for my $entry (@$install_types)
		{
		my $type = $entry->[0];
		push @{$build->{list_type}}, $type;
		}

	my $list_type = join(" ",@{$build->{list_type}});
	op_put($build->{object},"list_type", $list_type);

	for my $entry (@$install_types)
		{
		my ($type,$nickname,$scale,$min_precision) = @$entry;
		op_put($build->{object},"type_name.$type",$nickname);
		op_put($build->{object},"type_scale.$type", $scale);
		op_put($build->{object},"type_min_precision.$type", $min_precision);
		}

	my $sponsor = op_get($template,"usage");

	my $install_locs = [];

	my $owner_name = op_get($template,"owner.name");
	$owner_name = "My New Wallet" if $owner_name eq "";

	# Note that if you ever change the default sponsor name here you need
	# to change it above in handle_new_folder above as well.  That ain't
	# pretty but that's the way it is right now.

	my $sponsor_name = op_get($template,"sponsor.name");
	$sponsor_name = "My Sponsor" if $sponsor_name eq "";

	push @$install_locs, [$build->{location},$owner_name];
	push @$install_locs, [$sponsor,$sponsor_name];

	for my $entry (@$install_locs)
		{
		my $loc = $entry->[0];
		push @{$build->{list_loc}}, $loc;
		}

	my $list_loc = join(" ",@{$build->{list_loc}});
	op_put($build->{object},"list_loc", $list_loc);

	for my $entry (@$install_locs)
		{
		my ($loc,$nickname) = @$entry;
		op_put($build->{object},"loc_name.$loc", $nickname);
		}

	# Enable transaction history by default.
	op_put($build->{object},"recording",1);
	}

	# Now estimate cost of creation.

	$build->{folder_text} = archive_object_text($build->{object});

	$build->{cost}++;  # will buy folder location in archive

	# Compute cost of folder object in archive.
	{
	my $blocks = span_encrypt("\000"x16,$build->{folder_text});

	my $len_old = 16;  # because the new loc has an encrypted null
	my $len_new = length($blocks);
	my $folder_cost = int( ($len_new - $len_old) / 16);

	$build->{cost} += $folder_cost;
	}

	# Will buy folder location for each type.
	for my $type (@{$build->{list_type}})
		{
		$build->{cost}++;
		}

	$build->{cost}++;     # will buy pointer to session id loc
	$build->{cost} += 2;  # will write session id there
	$build->{cost}++;     # will buy session id loc itself
	$build->{cost} += 2;  # will write folder loc there

	# Require an extra 20 usage tokens so the user will have some room to
	# expand.  Also require at least 100 no matter what.

	$build->{min_usage} = $build->{cost} + 20;
	$build->{min_usage} = 100 if $build->{min_usage} < 100;
	}

	return $build;
	}

sub handle_new_folder
	{
	http_put("session","");

	set_title("Create Wallet");
	set_focus("passphrase");

	my $out = folder_result();

	op_put($out,"status","");

	# Normalize the usage parameter
	{
	my $usage = http_get("usage");
	$usage = trimblanks($usage);
	http_put("usage",$usage);
	}

	my $build = build_folder_template(http_op());

	if (http_get("create_folder") ne "")
		{
		if (op_get($out,"status") eq "")
			{
			set_focus("passphrase");

			my $passphrase = http_get("passphrase");
			if (length($passphrase) < 8)
				{
				op_put($out,"status","fail");
				op_put($out,"error_passphrase","too_short");
				}
			elsif (length($passphrase) > 255)
				{
				op_put($out,"status","fail");
				op_put($out,"error_passphrase","too_long");
				}
			}

		if (op_get($out,"status") eq "")
			{
			my $passphrase = http_get("passphrase");
			my $passphrase2 = http_get("passphrase2");

			if ($passphrase2 ne $passphrase)
				{
				op_put($out,"status","fail");
				op_put($out,"error_passphrase2","no_match");
				}
			}

		if (op_get($out,"status") eq "")
			{
			set_focus("usage");

			my $usage = http_get("usage");
			$usage = trimblanks($usage);
			http_put("usage",$usage);

			if (!valid_id($usage))
				{
				op_put($out,"status","fail");
				op_put($out,"error_usage","not_valid_id");
				}
			}

		if (op_get($out,"status") eq "")
			{
			# Everything looks good so far, let's see if the passphrase is
			# already taken.

			my $passphrase = http_get("passphrase");

			my $loc_folder = passphrase_location($passphrase);

			if (!archive_is_vacant($loc_folder))
				{
				# Something is already at this folder location, so ask
				# user to choose a different passphrase.

				set_focus("passphrase");

				op_put($out,"status","fail");
				op_put($out,"error_passphrase","taken");
				}
			}

		if (op_get($out,"status") eq "")
			{
			# Double-checking
			my $passphrase = http_get("passphrase");
			my $passphrase2 = http_get("passphrase2");
			die if $passphrase ne $passphrase2;
			die if length($passphrase) < 8 || length($passphrase) > 255;
			}

		# See if there are enough usage tokens in this invitation to fund
		# the creation.

		if (op_get($out,"status") eq "")
			{
			my $sponsor = http_get("usage");
			my $usage_type = "0" x 32;

			my $value = grid_touch($usage_type,$sponsor);

			if ($value eq "" && $sponsor eq $usage_type)
				{
				# Maybe we're just starting up a brand new Loom and the
				# user is creating a folder with the zero location.
				# In that case let's buy the zero location so the -1
				# will show up there.
				#
				# After you create the very first folder this way, your
				# next step should be to *delete* the usage token type
				# from the folder and then add it back in.  That will
				# cause the system to make your folder location the issuing
				# location for usage tokens.

				grid_buy($usage_type,$sponsor,$sponsor);
				$value = grid_touch($usage_type,$sponsor);
				}

			$value = "0" if $value eq "";

			if ($value !~ /^-/ && $value < $build->{min_usage})
				{
				op_put($out,"status","fail");
				op_put($out,"error_usage","insufficient");
				op_put($out,"error_usage_here",$value);
				op_put($out,"error_usage_min",$build->{min_usage});
				}
			}

		# If everything went well, go ahead and create the folder.

		if (op_get($out,"status") eq "")
			{
			my $sponsor = http_get("usage");

			my $type_usage = "0" x 32;
			archive_buy($build->{location},$sponsor);

			# Get the location "adjacent" to the folder itself and we'll
			# store the session id there.

			my $session_ptr = xor_hex($build->{location}, "0" x 31 . "1");

			# Create an initial session.

			# LATER unify with loom_login code

			my $session = archive_random_vacant_location();

			# Store the session id adjacent to the folder.

			archive_buy($session_ptr,$sponsor);
			archive_write($session_ptr,$session,$sponsor);

			# Store the folder location at the session id.

			archive_buy($session,$sponsor);
			archive_write($session,$build->{location},$sponsor);

			# Write the folder text.

			archive_write($build->{location},$build->{folder_text},$sponsor);

			# Buy the folder location for each asset type.

			for my $type (@{$build->{list_type}})
				{
				grid_buy($type,$build->{location},$sponsor);
				}

			# Take all assets away from the sponsor drop point.

			for my $type (@{$build->{list_type}})
				{
				my $remain = grid_touch($type,$sponsor);
				grid_move($type,$remain,$sponsor,$build->{location});
				}

			http_put("session",$session);

			return;
			}
		}

	my $q_error_usage = "";
	my $q_error_passphrase = "";
	my $q_error_passphrase2 = "";

	if (op_get($out,"status") eq "fail")
		{
		my $error_usage = op_get($out,"error_usage");

		if ($error_usage eq "not_valid_id")
			{
			$error_usage = "Not a valid invitation code";
			}
		elsif ($error_usage eq "insufficient")
			{
			my $min = op_get($out,"error_usage_min");
			my $here = op_get($out,"error_usage_here");

			$error_usage = "This invitation has $here usage tokens, but you ";
			$error_usage .= "need at least $min to create a wallet.  ";

			if ($here eq "0")
				{
				$error_usage .=
				"Perhaps the invitation has already been claimed.";
				}
			else
				{
				$error_usage .=
				"Please ask your sponsor for more usage tokens.";
				}
			}

		if ($error_usage ne "")
			{
			$q_error_usage = qq{<br><span class=alarm>$error_usage</span>};
			}

		my $error_passphrase = op_get($out,"error_passphrase");

		if ($error_passphrase eq "too_short")
			{
			$error_passphrase = "Please enter at least 8 characters.";
			}
		elsif ($error_passphrase eq "too_long")
			{
			$error_passphrase = "Please enter at most 255 characters.";
			}
		elsif ($error_passphrase eq "taken")
			{
			$error_passphrase = "The system cannot accept that passphrase.";
			$error_passphrase .= "  Please choose another passphrase.";
			}

		if ($error_passphrase ne "")
			{
			$q_error_passphrase = qq{<br><span class=alarm>$error_passphrase</span>};
			}

		my $error_passphrase2 = op_get($out,"error_passphrase2");

		if ($error_passphrase2 eq "no_match")
			{
			$error_passphrase2 = "The passphrases did not match.";
			}

		if ($error_passphrase2 ne "")
			{
			$q_error_passphrase2 = qq{<br><span class=alarm>$error_passphrase2</span>};
			}
		}

	my $context = op_new(http_slice(qw(function new_folder invite)));

	# Include extra type and location information supplied in the invitation.
	{
	op_put($context,http_slice(qw(owner.name sponsor.name)));

	my $nT = http_get("nT");
	op_put($context,"nT",$nT);

	$nT = 0 if $nT eq "";
	for my $type_no (1 .. $nT)
		{
		for my $field (qw(id name display))
			{
			my $key = "T$type_no.$field";
			op_put($context,$key, http_get($key));
			}
		}
	}

	my $hidden = html_hidden_fields(op_pairs($context));

	my $input_size_id = 32 + 4;

	my $usage = http_get("usage");
	my $q_usage = html_quote($usage);

	top_link(highlight_link(top_url(),"Home"));

	top_link(highlight_link(
		top_url(op_pairs($context), "usage",$usage),
		"Sign Up", 1));

	emit(<<EOM
<h1> Create a New Wallet </h1>

<hr>
<h2> Step 1:  Choose a passphrase </h2>

<p>
To create a new wallet, you first need to choose a passphrase for it.
We advise you <em><b>not</b></em> to choose something off the top of your head,
such as a birthday or pet's name, because that would be too easy for
others to guess.  Instead, press the Random Passphrase button below.  That will
create a 5 word passphrase that is very easy to remember, yet very strong.
<p>
Guessing a 5-word passphrase is about like winning the lottery a million
million times in a row.  If you want an even stronger passphrase, you can
press the button again to gather more words.

EOM
);
	emit(<<EOM
<p>
<form method=post action="" autocomplete=off>
$hidden
EOM
);
	emit(<<EOM
<p>
<input type=submit name=random_passphrase value="Random Passphrase">
EOM
);
	if (http_get("random_passphrase") ne "")
	{
	my $passphrase = diceware_passphrase(5);

	emit(<<EOM
<p>
<span class=large_mono>$passphrase</span>

<p>
We advise you to <em><b>write down</b></em> your new passphrase and keep it in a
<em><b>very safe</b></em> place.  (Do not tape it to your computer monitor.)
Eventually you may type the passphrase so many times that you'll feel safe in
destroying the original piece of paper, but we recommend keeping the paper
hidden for quite a while to ensure that you don't forget the passphrase.

<p class=alarm>
<b>WARNING:</b>
If you lose your passphrase, you lose all the assets in this wallet.
There is <em><b>no way</b></em> to retrieve a lost passphrase.
</p>

EOM
);
	}

	emit(<<EOM
<hr>
<h2> Step 2: Enter the passphrase </h2>

<p>
Now type your chosen passphrase into the field below, and type it again
to make sure you entered it correctly.
EOM
);
	if (http_get("random_passphrase") ne "")
	{
	emit(<<EOM
Make sure you <em><b>type</b></em> the passphrase using your keyboard &mdash;
<span class=alarm>do not</span> copy and paste it.
EOM
);
	}

	need_keyboard();

	emit(<<EOM

<table border=0 cellpadding=5 style='border-collapse:collapse'>

<colgroup>
<col width=220>
</colgroup>

<tr>
<td>
Enter passphrase for this wallet:
<br>
<span class=small>(between 8 and 255 characters)</span>
</td>
<td>
<input type=password name=passphrase size=40 value="" class="keyboardInput">
$q_error_passphrase
</td>
</tr>

<tr>
<td>
Enter the passphrase again:
</td>
<td>
<input type=password name=passphrase2 size=40 value="" class="keyboardInput">
$q_error_passphrase2
</td>
</tr>

</table>
EOM
);

	if (http_get("invite"))
	{
	}
	else
	{
	emit(<<EOM
<hr>
<h2> Step 3: Paste your invitation into the box and press Create Wallet. </h2>

EOM
);
	}

	emit(<<EOM
<table border=0 cellpadding=5 style='border-collapse:collapse'>

<colgroup>
<col width=220>
</colgroup>

EOM
);

	if (http_get("invite"))
	{
	emit(<<EOM
<tr>
<td></td>
<td>
<input type=hidden name=usage value="$q_usage">
$q_error_usage
</td>
</tr>
EOM
);
	}
	else
	{
	emit(<<EOM
<tr>
<td>
Paste your invitation here:
</td>
<td>
<input type=text class=mono name=usage size=$input_size_id value="$q_usage">
$q_error_usage
</td>
</tr>
EOM
);
	}

	emit(<<EOM

<tr>
<td>
</td>
<td>
<input type=submit name=create_folder value="Create Wallet">
</td>
</tr>

</table>
EOM
);

	{
	# Rig up the asset display parameters and call the display routine.

	my $display = {};
	$display->{flavor} = "invite_location";

	my $loc_name = http_get("sponsor.name");
	$loc_name = "My Sponsor" if $loc_name eq "";
	$display->{location_name} = $loc_name;

	$g_folder_object = $build->{object};
	$g_folder_location = $build->{location};

	# Look first to see if anything is there.

	configure_value_display($display);

	{
	my $sponsor = http_get("usage");

	if ($sponsor eq "")
		{
		}
	elsif (!valid_id($sponsor))
		{
		emit(<<EOM
<hr>
<h1 class=alarm> Warning </h1>
<p>
This is not a valid invitation code.
EOM
);
		}
	elsif ($display->{involved_loc}->{$sponsor})
		{
		# Check for sufficient usage.

		my $actual_usage = $display->{usage_count}->{$sponsor};
		$actual_usage = "0" if !defined $actual_usage;

		if ($actual_usage >= $build->{min_usage})
		{
		emit(<<EOM
<hr>
<h1>Assets you will receive</h1>
<p>
Your sponsor is offering you the following assets.  When you create your new
wallet, you will be charged $build->{cost} usage tokens, and any remaining
assets will become yours.  
EOM
);
		}
		else
		{
		emit(<<EOM
<hr>
<h1>Not enough usage tokens here!</h1>
<p>
Your sponsor is offering you the following assets.  However, your sponsor must
move at least $build->{min_usage} usage tokens to this invitation before it
will work.
EOM
);
		}

		}
	else
		{
		emit(<<EOM
<hr>
<h1 class=alarm> Warning </h1>
<p>
There are no assets in this invitation.  Perhaps the invitation has already
been taken, or there was some mistake in transmission.  Please check with your
sponsor.
EOM
);
		}
	}

	emit(page_folder_value_table($display));

	$g_folder_object = undef;
	$g_folder_location = undef;
	}

	if (http_get("invite"))
	{
	}
	elsif (http_get("usage") eq "")
	{
	my $url = top_url("help",1, "topic","get_usage_tokens");
	my $link = qq{<a class=large href="$url">How do I get an invitation?</a>};

	emit(<<EOM
<p>
$link
EOM
);
	}

	emit(<<EOM
</form>
EOM
);

	return;
	}

sub page_login
	{
	set_title("Login");
	put_mask_if_absent();

	if (http_get("help"))
		{
		# LATER This is our entry point into the "Advanced" screen.
		# Strange but oh well.
		help_topic("index");
		return;
		}

	my $out = folder_result();

	top_link(highlight_link(top_url(),"Home", 1));

	if (http_get("logout") ne "")
		{
		top_message(
		"<div class=alarm><b>Please close your browser window now.</b></div>");
		}

	set_focus("passphrase");

	my $error = op_get($out,"error_passphrase");

	if ($error eq "missing")
		{
		$error = "Please enter a passphrase.";
		}
	elsif ($error eq "too_small")
		{
		my $min_length = op_get($out,"error_passphrase_min_length");
		$error = "Please enter at least $min_length characters.";
		}
	elsif ($error eq "too_large")
		{
		my $max_length = op_get($out,"error_passphrase_max_length");
		$error = "Please enter at most $max_length characters.";
		}
	elsif ($error eq "invalid")
		{
		$error = "Invalid passphrase";
		}

	if ($error ne "")
		{
		$error = " <span class=alarm>$error</span>";
		}

	my $hidden = html_hidden_fields(http_slice(qw(function)));

	# Allow specifying partial or complete passphrase in URL.  That way you
	# could bookmark the first part of a passphrase, and type in the rest.

	my $q_passphrase = "";
	if (http_get("login") eq "")
		{
		my $passphrase = http_get("passphrase");
		$q_passphrase = html_quote($passphrase);
		}

	need_keyboard();

	my $name = loom_config("system_name");
	my $login_greeting = "<h1>\nWelcome to $name.</h1>";

	emit(<<EOM
$login_greeting
EOM
);

	# LATER: we'll spruce up sign-up process.
	{
	my $link_folder_new = highlight_link(
		top_url("function","folder", "new_folder",1),
		"sign up here.",
		0,
		"Become a brand new user",
		);

	emit(<<EOM
If someone sent you an invitation, $link_folder_new
EOM
);
	}

	emit(<<EOM
<p>
If you have already signed up, enter your passphrase and press Login.
<br>
For extra security, use the keyboard icon.
<p>
<form method=post action="">
$hidden
<div>
<input type=password name=passphrase size=40 value="$q_passphrase" class="keyboardInput">
<input type=submit name=login value="Login">$error
</div>
</form>
<p>
<table border=0 cellpadding=0 style='border-collapse:collapse'>
<tr>
<td colspan=2>
<h2> Important Security Advice </h2>
<p>
Do not log in here unless you are certain you are at the <em>authentic</em>
Loom site.  Some people will try to lead you to a fake Loom site and steal your
passphrase, but you can easily protect yourself with a little discipline.
</td>
</tr>
<tr>
<td valign=top>
<h2> <span style='color:green'>What you SHOULD do:</span> </h2>
<ul>
<li> Type "loom.cc" in the location bar of your browser and press the Enter
key.  Make sure you type it in the area <em>way</em> at the top of your browser
&mdash; not in the search area.  Hint: type Ctrl-L to put your cursor in the
location bar, then type "loom.cc" there and press Enter.
<li> You will then see the landing page.  Click the link under
"Traditional Secure Login", or use the "Enhanced Security Option" if you prefer.
<li> You will then see the secure login page.  For your convenience, we
recommend that you <b>bookmark</b> that page in your browser.  That way you can
reach it in the future with a single click.
<li> At the secure login page, you may safely log in.
</ul>
</td>
<td valign=top>
<h2> <span style='color:red'>What you should NEVER do:</span> </h2>
<ul>
<li> Never log into Loom by clicking a link you found in an email, or even in
another web page.  The links you see in emails and other web pages could lead
you to a fake Loom site.  If you log in at one of those fake sites, a thief
will steal your passphrase.  You have been warned.
</ul>
</td>
</tr>
</table>
EOM
);

	# LATER let's rethink this.  If we are supposed to be at an https site
	# but we aren't, then it means the redirection from http to https is
	# not working.  In that case we don't want the user to log in at all.
	# The site is effectively down and we should go into maintenance mode.

	if (0)
	{
	my $color = "";
	my $msg = "";

	my $this_url = loom_config("this_url");

	if ($this_url =~ /^https:/)
	{
	$color = "green";
	$msg = "This is a secure login form.";
	}
	else
	{
	$color = "red";
	$msg = "*** WARNING: This is <em>not</em> a secure login form!";
	}

	emit(<<EOM
<span class=small style='color:$color; font-weight:bold; margin-left:20px;'>
$msg
</span>
EOM
);
	}

	top_link("");

	top_link(highlight_link(
		top_url("function","folder", "new_folder",1),
		"Sign Up", 0, "Become a brand new user"));

	top_link(highlight_link(
		"/faq",
		"FAQ", 0, "Frequently Asked Questions"));

	top_link(highlight_link(
		top_url("help",1, "topic","contact_info"),
		"Contact", 0, "Contact someone for help with your questions"));

	top_link(highlight_link(
		"/news",
		"News", 0,
		"See the latest announcements and other useful information"));

	top_link(highlight_link(
		"/merchants",
		"Merchants", 0, "See who uses Loom"));

	top_link(highlight_link(
		"/trade",
		"Trade", 0, "See the products that vendors buy and sell."));

	top_link(highlight_link(
		top_url("help",1),
		"Advanced", 0,
		"Advanced functions which may interest experts and developers"));

	return;
	}

sub page_folder_respond
	{
	set_title("Wallet");

	$g_folder_object = undef;
	$g_folder_location = undef;
	$g_folder_reclaim = undef;
	$g_folder_result = op_new();

	# If we got here by default then set function to "folder".
	http_put("function","folder") if http_get("function") eq "";

	my $action = "";

	if (http_get("new_folder") ne "" || http_get("invite") ne "")
		{
		$action = "new_folder";
		}
	elsif (http_get("login") ne "" || http_get("passphrase") ne "")
		{
		# Attempt a login if the user pressed Login or entered a passphrase.
		$action = "login";
		}
	elsif (http_get("logout") ne "")
		{
		$action = "logout";
		}

	my $mask = loom_get_cookie("mask");

	if ($action ne "" && !valid_id($mask))
		{
		# Here we take an extra measure to enable "auto-login" links.  If you
		# click an auto-login link, it brings up a browser and attempts to
		# login.  The problem is, if the "mask" cookie is not already set in
		# that browser, the Loom server will think you have disabled cookies
		# and will display an error message.  So in the case of login, we give
		# your browser one more chance to set the cookie.

		if ($action eq "login" && http_get("repeat") eq "")
			{
			put_mask_if_absent();

			my $url = top_url(
				http_slice("function","login","passphrase"),
				"repeat","1",
				);
			format_HTTP_response
				(
				"303 See Other",
				"Location: $url\n",
				"",
				);
			return;
			}

		page_cookie_problem();
		return;
		}

	if ($action eq "login" || $action eq "new_folder")
		{
		if ($action eq "login")
			{
			handle_login();
			}
		else
			{
			handle_new_folder();
			}

		my $real_session = http_get("session");
		if (valid_id($real_session))
			{
			my $masked_session = xor_hex($real_session,$mask);

			# http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html

			format_HTTP_response
				(
				"303 See Other",
				"Location: /?function=folder&session=$masked_session\n",
				"",
				);

			return;
			}

		return if $action eq "new_folder";
		}
	elsif ($action eq "logout")
		{
		my $real_session = loom_check_session();
		if ($real_session ne "")
			{
			kill_session($real_session);

			format_HTTP_response
				(
				"303 See Other",
				"Location: /?logout=1\n",
				"",
				);

			return;
			}
		}

	my $real_session = loom_check_session();

	if ($real_session eq "")
		{
		page_login();
		return;
		}

	die if $real_session eq "";  # being careful

	read_folder($real_session);

	my $content_type = folder_get("Content-Type");
	$content_type = folder_get("Content-type") if $content_type eq "";

	if ($content_type ne "loom/folder")
	{
	my $q_content_type = html_quote($content_type);

	emit(<<EOM
<h1>Unknown Content-Type: $q_content_type</h1>
EOM
);
	return;
	}

	{
	top_link(highlight_link(
		top_url("function","folder", http_slice("session")),
		"Refresh Wallet",
		http_get("function") eq "folder"
			&& !http_get("h_only")
			&& !http_get("help"),
		"Refresh your wallet display to see if any assets have moved."));

	top_link(highlight_link(
		top_url("function","contact", http_slice("session")),
		"Contacts",
		http_get("function") eq "contact" && http_get("help") eq "",
		"Manage contacts, invite new users"));

	top_link(highlight_link(
		top_url("function","asset", http_slice("session")),
		"Assets",
		http_get("function") eq "asset" && http_get("help") eq "",
		"Manage asset types"));

	top_link(highlight_link(
		top_url(http_slice("function","session"), "help",1),
		"Help",
		http_get("help") ne ""));
	}

	# Reset the result context here because page_wallet_respond uses it.
	# I'm not thrilled with this but oh well for now.

	$g_folder_result = op_new();

	{
	my $function = http_get("function");

	if ($function eq "folder")
		{
		page_wallet_respond();
		}
	elsif ($function eq "contact")
		{
		page_contact_respond();
		}
	elsif ($function eq "asset")
		{
		page_asset_respond();
		}
	else
		{
		die;
		}
	}

	# Add the Logout link.

	top_link("&nbsp;");

	top_link(highlight_link(
		top_url("function","folder", http_slice("session"),
			"logout",1),
		"Logout", 0,
		"Log out of your wallet."));

	# Append the name of this folder to the title.
	{
	my $list_loc = folder_get("list_loc");
	my @list_loc = split(" ",$list_loc,2);
	my $loc = $list_loc[0];
	if (defined $loc)
		{
		my $name = map_id_to_nickname("loc",$loc);
		my $q_name = html_quote($name);
		my $title = get_title();
		$title = "$title : $q_name";
		set_title($title);
		}
	}

	return;
	}

return 1;
