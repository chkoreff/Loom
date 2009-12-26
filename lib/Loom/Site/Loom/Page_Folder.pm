package Loom::Site::Loom::Page_Folder;
use strict;
use Loom::Context;
use Loom::Dttm;
use Loom::Qty;
use Loom::Quote::Span;
use Loom::Site::Loom::EZ_Archive;
use Loom::Site::Loom::EZ_Grid;

sub new
	{
	my $class = shift;
	my $site = shift;

	my $s = bless({},$class);
	$s->{site} = $site;
	$s->{id} = $site->{id};
	$s->{html} = $site->{html};
	$s->{quote} = Loom::Quote::Span->new;

	$s->{module} =
		{
		folder => "Loom::Site::Loom::Page_Wallet",
		contact => "Loom::Site::Loom::Page_Contact",
		asset => "Loom::Site::Loom::Page_Asset",
		};

	return $s;
	}

sub respond
	{
	my $s = shift;

	my $site = $s->{site};

	$site->set_title("Wallet");

	$s->{out} = Loom::Context->new;
	$s->{archive} = Loom::Site::Loom::EZ_Archive->new($site->{loom});
	$s->{grid} = Loom::Site::Loom::EZ_Grid->new($site->{loom});

	my $op = $site->{op};

	# If we got here by default then set function to "folder".
	$op->put(function => "folder") if $op->get("function") eq "";

	# We attempt a login if either the Login button was pressed OR any
	# passphrase is specified.  That way you can log in with IE by just
	# pressing the Enter key instead of clicking the Login button.

	if ($op->get("new_folder") ne "" || $op->get("invite") ne "")
		{
		# TODO pretty sure we have to do something here with mask
		# probably even redirect.
		$s->handle_new_folder;
		}
	elsif ($op->get("login") ne "" || $op->get("passphrase") ne "")
		{
		$s->handle_login;

		my $session = $op->get("session");
		if ($s->{id}->valid_id($session))
			{
			my $mask = $site->get_cookie("mask");

			# TODO might want to set the mask for ALL visits to the site,
			# not just upon successful login.
			# TODO test with cookies disabled, perhaps default the mask
			# to all zeroes?
			# TODO if cookies disabled then degrade/warn gracefully

			if (!$s->{id}->valid_id($mask))
				{
				# Set the mask cookie to a new random value.
				$mask = unpack("H*",$site->{random}->get);
				$site->put_cookie("mask",$mask);
				}

			my $masked_session = $s->{id}->xor_hex($session,$mask);

			# http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html

			$site->format_HTTP_response
				(
				"303 See Other",
				"Location: /?function=folder&session=$masked_session\n",
				"",
				);

			return;
			}
		}
	elsif ($op->get("logout") ne "")
		{
		my $real_session = $site->check_session;
		$site->{login}->logout($real_session) if $real_session ne "";
		}

	my $real_session = $site->check_session;

	if ($real_session eq "")
		{
		if ($op->get("new_folder") eq "" && $op->get("invite") eq "")
			{
			$site->set_title("Login");
			$s->page_login;
			}
		return;
		}

	die if $real_session eq "";  # being careful

	$s->{location} = $s->{archive}->touch($real_session);
	$s->{object} = $s->{archive}->touch_object($s->{location});

	my $content_type = $s->{object}->get("Content-type");

	if ($content_type ne "loom/folder")
	{
	my $dsp_obj = $s->{html}->quote($s->{object}->write_kv);

	$site->{body} .= <<EOM;
<h1>Unknown Content-type</h1>
<pre>
$dsp_obj
</pre>
EOM
	return;
	}

	$s->{out} = Loom::Context->new;

	{
	my $url = $site->url(function => "folder", $op->slice("session"));
	my $highlight = $op->get("function") eq "folder" && !$op->get("help");

	if ($highlight)
		{
		push @{$site->{top_links}},
			$site->highlight_link(
				$url,
				"Refresh",
				$highlight,
				"Refresh this payment page",
				);
		}
	else
		{
		push @{$site->{top_links}},
			$site->highlight_link(
				$url,
				"Home",
				$highlight,
				"Send and receive payments",
				);
		}
	}

	{
	my $function = $op->get("function");
	$site->object($s->{module}->{$function},$s)->respond;
	}

	# Add the Logout link.
	push @{$site->{top_links}}, "";
	push @{$site->{top_links}},
		$site->highlight_link(
			$site->url(function => "folder", $op->slice("session"),
				logout => 1),
			"Logout", 0,
			"Log out of your folder",
			);

	# Append the name of this folder to the title.
	{
	my $folder = $s->{object};
	my $list_loc = $folder->get("list_loc");
	my @list_loc = split(" ",$list_loc,2);
	my $loc = $list_loc[0];
	if (defined $loc)
		{
		my $name = $s->map_id_to_nickname("loc",$loc);
		my $q_name = $s->{html}->quote($name);
		my $title = $site->{title};
		$title = "$title : $q_name";
		$site->set_title($title);
		}
	}

	}

# This is called from Contact and Asset.

sub page_folder_value_table
	{
	my $s = shift;
	my $display = shift;

	my $site = $s->{site};

	$s->configure_value_display($display);

	# Lets see if we detected any Loom coordinates with a 0 balance.  If so,
	# then we'll reclaim (sell) them, receiving usage token refunds.  We only
	# do this when we're on the main wallet display.

	if ($display->{flavor} eq "move_dialog")
	{
	my @reclaim_list = @{$s->{reclaim_list}};

	if (@reclaim_list)
		{
		my $grid = $s->{grid};
		my $loc_folder = $s->{location};

		my $usage_type = "0" x 32;

		for my $pair (@reclaim_list)
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
				$grid->sell($type,$loc,$loc_folder);
				}
			}

		# Now re-compute the value display to reflect any recovered
		# usage tokens.

		$s->configure_value_display($display);
		}

	my @unused_cash = @{$s->{unused_cash}};

	if (@unused_cash)
		{
		my $folder_object = $s->{object};
		my $loc_folder = $s->{location};

		for my $pair (@unused_cash)
			{
			my ($loc,$name) = @$pair;

			my $old_list_loc = $folder_object->get("list_loc");
			my @old_list_loc = split(" ",$old_list_loc);

			my @new_list_loc = ();

			for my $item (@old_list_loc)
				{
				next if $item eq $loc;
				push @new_list_loc, $item;
				}

			my $new_list_loc = join(" ",@new_list_loc);

			$folder_object->put("list_loc",$new_list_loc);
			$folder_object->put("loc_name.$loc","");
			}

		my $archive = $s->{archive};
		$archive->write_object($loc_folder,$folder_object,$loc_folder);
		$s->{object} = $archive->touch_object($loc_folder);

		# Now re-compute the value display to reflect any recovered
		# usage tokens.

		$s->configure_value_display($display);
		}
	}

	my $op = $site->{op};
	my $out = $s->{out};

	my $folder = $s->{object};
	my $loc_folder = $s->{location};

	# Now build up the HTML display of all the specified locations.

	my $table = "";
	$table .= <<EOM;
<table border=0 cellpadding=2 style='border-collapse:collapse;'>
<colgroup>
<col width=180>
<col width=520>
</colgroup>
EOM

	if ($out->get("scan_status") eq "fail")
		{
		my $scan_error_max = $out->get("scan_error_max");

		$table .= <<EOM;
<tr>
<td colspan=2 style='border: solid 1px'>
<span class=alarm><b>Warning: This folder is too big.</b></span>
Some values may be missing from this list because you are trying to examine
more than $scan_error_max at a time.  Please delete any unused contacts or
assets from this folder, or move some of them to a brand new folder.
</td>
</tr>
EOM
		}

	my $already_showed_transit_label = 0;
	my $payment_dialog = "";

	if ($display->{move_dialog} ne "")
		{
		my $status = $out->get("status_receive");
		my $error = "";

		if ($status eq "")
			{
			}
		elsif ($status eq "success")
			{
			}
		else
			{
			$error = $out->get("error_token");
			}
		
		if ($error eq "")
			{
			}
		elsif ($error eq "malformed")
			{
			$error = qq{That is not the right format for a cash token.}
			.qq{<br>Are you sure you copied and pasted it correctly?};
			}
		elsif ($error eq "already_exists")
			{
			$error = qq{You already have that one in your folder.};
			}
		elsif ($error eq "insufficent_usage")
			{
			$error = qq{You don't have enough usage tokens to do this.};
			}

		if ($error ne "")
			{
			$error = "<div class=alarm style='font-weight:normal'>$error</div>";
			}

		$payment_dialog .= <<EOM;
<tr>
<td class=folder_section>
Make a Payment
</td>
<td class=folder_section align=right>
Receive Cash:
<input class=tiny_mono size=34 type=text name=received_cash_token value="">
<input type=submit name=press_receive_cash value="Go">
$error
</td>
</tr>
EOM

		$payment_dialog .= $display->{move_dialog};
		}

	$table .= $payment_dialog;

	for my $loc (@{$display->{locations}})
	{
	my @location_items = @{$display->{location_items}->{$loc}};

	# Show the nickname header for this contact.
	{
	my $loc_name = $s->map_id_to_nickname("loc",$loc);

	my $q_loc_name;

	if ($loc_name =~ /^\001/ || $loc_name =~ /^\002/)
		{
		# Begins with \001 or \002, so it's inbound or outbound cash.

		$q_loc_name = "";  # We don't even use this.
		}
	else
		{
		$q_loc_name = $s->{html}->quote($loc_name);

		if ($display->{flavor} eq "move_dialog")
			{
			my $url = $site->url(
				function => "contact",
				name => $loc_name,
				$op->slice(qw(session)),
				);

			my $title = $display->{contact_title};

			$q_loc_name =
				qq{<a class=contact href="$url" title="$title">$q_loc_name</a>};
			}
		}

	if ($display->{flavor} eq "move_dialog")
	{

	if ($loc eq $loc_folder)
	{
	$table .= <<EOM;
<tr>
<td colspan=2 class=folder_section>
Your Assets
</td>
</tr>
EOM
	}
	elsif (!$already_showed_transit_label)
	{
	$already_showed_transit_label = 1;

	$table .= <<EOM;
<tr>
<td class=folder_section>
Assets In Transit
</td>
<td class=folder_section style='font-size:8pt'>
Click an asset below to claim it as your own.
</td>
</tr>
EOM
	}

	}

	if ($display->{flavor} ne "zoom_contact")
	{

	if ($loc_name =~ /^\001/)
	{
	# inbound cash (received)

	my $suffix = substr($loc_name,1);
	my ($cash_time,$cash_loc) = split(" ",$suffix);

	my $dttm = Loom::Dttm->new($cash_time)->as_gmt;

	$table .= <<EOM;
<tr>
<td align=right style='font-size:8pt; padding-top: 15px; padding-bottom:5px;'>
Received cash:
</td>

<td class=tiny_mono style='padding-top: 15px; padding-bottom:5px;'>
<span title="Click assets below to claim.  Received $dttm">$cash_loc</span>
</td>
</tr>
EOM
	}
	elsif ($loc_name =~ /^\002/)
	{
	# outbound cash (sent)

	my $suffix = substr($loc_name,1);
	my ($cash_time,$cash_loc) = split(" ",$suffix);

	my $dttm = Loom::Dttm->new($cash_time)->as_gmt;

	$table .= <<EOM;
<tr>
<td align=right style='font-size:8pt; padding-top: 15px; padding-bottom:5px;'>
Send cash token to payee:
</td>

<td class=tiny_mono style='padding-top: 15px; padding-bottom:5px;'>
<span title="Copy, paste, and send this cash token to payee.  Created $dttm">$cash_loc</span>
</td>
</tr>
EOM
	}
	else
	{
	$table .= <<EOM;
<tr>
<td>
</td>
<td style='font-size:12pt; font-weight:bold; padding-top: 15px;'>
$q_loc_name
</td>
</tr>
EOM
	}

	}

	# Do not display raw hex for main folder location itself.

	if ($display->{show_raw_hex} && $loc ne $loc_folder)
	{
	$table .= <<EOM;
<tr>
<td align=right style='font-weight:bold'>
ID:
</td>
<td class=large_mono>
$loc
</td>
</tr>
EOM
	}

	}

	# Now show the individual items under this contact.

	# LATER use CSS style sheet

	# Tan scheme
	#my $odd_color = "#fbf9f8";
	#my $even_color = "#e9e7e4";

	# Blue scheme
	my $odd_color = "#efffff";
	my $even_color = "#e8f8fe";

	my $odd_row = 1;  # for odd-even coloring

	for my $item (@location_items)
	{
	my ($value,$type) = @$item;
	my $q_value = $s->display_value($value,$type);

	my $style = "";
	my $color = $out->get("color.$type.$loc");
	if ($color ne "")
		{
		# NOTE: Getting rid of the red and green display for now because
		# one user found the red slightly alarming.  But we keep the bold
		# fact to highlight what just happened.

		##$style = " style='font-weight:bold; color:$color'";
		$style = " style='font-weight:bold;'";
		}

	my $loc_name = $s->map_id_to_nickname("loc",$loc);
	$loc_name = "" if $loc eq $loc_folder;

	my $type_name = $s->map_id_to_nickname("type",$type);
	my $q_type_name = $s->{html}->quote($type_name);

	if ($loc ne $loc_folder)
		{
		if ($display->{flavor} eq "move_dialog")
			{
			my $url = $site->url(
				function => "folder",
				qty => $q_value,
				loc => $loc_name,
				type => $type_name,
				take => 1,
				$op->slice(qw(session)),
				);

			$q_type_name =
				qq{<a href="$url" title="Take this asset">}
				.qq{$q_type_name</a>};
			}
		}

	my $row_color = $odd_row ? $odd_color : $even_color;
	$odd_row = 1 - $odd_row;

	$table .= <<EOM
<tr style='background-color:$row_color'>
<td align=right$style>
<span style='margin-right:5px'>
$q_value
</span>
</td>
<td$style>
$q_type_name
</td>
</tr>
EOM
	}

	}

	$table .= <<EOM;
</table>
EOM

	return $table;
	}

sub configure_value_display
	{
	my $s = shift;
	my $display = shift;

	my $site = $s->{site};

	my $folder = $s->{object};
	my $loc_folder = $s->{location};

	$display->{locations} = [];
	$display->{show_raw_hex} = 0;
	$display->{contact_title} = "";
	$display->{move_dialog} = "";
	$display->{involved_type} = {};
	$display->{involved_loc} = {};

	my $grid = $s->{grid};

	my @list_type = $s->get_sorted_list_type;

	if ($display->{flavor} eq "move_dialog")
		{
		# Show all non-empty locations.

		my @list_loc = $s->get_sorted_list_loc;

		$display->{show_raw_hex} = 0;

		$display->{contact_title} = "Show contact";

		$display->{involved_loc}->{$loc_folder} = 1;
			# Show main folder location even if empty.

		$s->configure_scan_display($display,\@list_loc,\@list_type);

		my @list_select_loc;

		for my $loc (@list_loc)
			{
			next if $loc eq $loc_folder;
				# don't include ourself in drop points
			push @list_select_loc, $loc;
			}

		$display->{move_dialog} =
			$s->move_dialog(\@list_type,\@list_select_loc);

		# NOTE: We make ALL asset types show up in the drop-down menu.
		# That way you can move "0" quantity of it to a drop point when
		# you are creating an invitation and want the new user to inherit
		# that type, even when you have none of it yourself.
		}
	elsif ($display->{flavor} eq "zoom_contact")
		{
		my $loc = $s->map_nickname_to_id("loc",$display->{location_name});

		if ($loc ne "")
			{
			$display->{involved_loc}->{$loc} = 1;
				# Show location even if empty.

			$display->{contact_title} = "Refresh contact";
			$display->{show_raw_hex} = 0;

			$s->configure_scan_display($display,[$loc],\@list_type);
			}
		}
	elsif ($display->{flavor} eq "invite_location")  # LATER make obsolete
		{
		my $loc = $s->map_nickname_to_id("loc",$display->{location_name});

		if ($loc ne "")
			{
			$display->{show_raw_hex} = 0;
			$s->configure_scan_display($display,[$loc],\@list_type);
			}
		}
	elsif ($display->{flavor} eq "delete_type")
		{
		# Show all locations which have something of a given type.

		my @list_loc = $s->get_sorted_list_loc;

		my $type = $s->map_nickname_to_id("type",$display->{type_name});

		$display->{show_raw_hex} = 0;

		if ($type ne "")
			{
			$s->configure_scan_display($display,\@list_loc,[$type]);
			}
		}
	}

sub configure_scan_display
	{
	my $s = shift;
	my $display = shift;
	my $list_loc = shift;
	my $list_type = shift;

	# When we render the main wallet display, we compute the list of all zero-
	# value locations we find so we can reclaim (sell) them automatically.
	# We also compute a list of all unused (empty) cash locations so we can
	# delete those out of the contact list.

	$s->{reclaim_list} = [];
	$s->{unused_cash} = [];

	my $site = $s->{site};

	my $grid = $s->{grid};
	my $out = $s->{out};

	# We pass in the "1" flag to force the scan to show us 0-value locations
	# as well.

	my $rsp = $grid->scan($list_loc,$list_type,1);

	$out->put("scan_status",$rsp->get("status"));
	$out->put("scan_error",$rsp->get("error"));
	$out->put("scan_error_max",$rsp->get("error_max"));

	my $usage_type = "0" x 32;

	for my $loc (split(" ",$rsp->get("locs")))
		{
		my @items;

		for my $pair (split(" ",$rsp->get("loc/$loc")))
			{
			my ($value,$type) = split(":",$pair);

			if ($value eq "0")
				{
				if ($display->{flavor} eq "move_dialog")
					{
					# We found a 0-value location, so add it to the reclaim
					# list.

					push @{$s->{reclaim_list}}, [$loc,$type];
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

	if ($display->{flavor} eq "move_dialog")
	{
	for my $loc (@$list_loc)
		{
		my $name = $s->map_id_to_nickname("loc",$loc);
		if (!$display->{involved_loc}->{$loc})
			{
			if ($name =~ /^\001/ || $name =~ /^\002/)
				{
				# This cash location is now entirely vacant or zero for all
				# asset types, so let's put it on the unused_cash list for
				# automatic deletion from the Contact list.

				push @{$s->{unused_cash}}, [$loc,$name];
				}
			}
		}
	}

	return;
	}

sub move_dialog
	{
	my $s = shift;
	my $list_select_type = shift;
	my $list_select_loc = shift;
	
	my $site = $s->{site};

	my $type_selector = $site->simple_value_selector("type",
		"-- of this asset --",
		$s->map_ids_to_nicknames("type",$list_select_type));

	# Now we render the contact selector specially so we can insert the special
	# pseudo-contact name "\002" representing payment to Cash.

	my $loc_selector;

	{
	my $op = $site->{op};

	my $selector = "";
	$selector .= <<EOM;
<select name=loc>
<option value="">-- to this contact --</option>
EOM

	# Use the ASCII \002 binary character to represent [Cash: New].

	{
	my $selected = "";

	my $loc = $op->get("loc");

	if (($loc =~ /^\001/ || $loc =~ /^\002/)
		&& $s->map_id_to_nickname("loc",$loc) eq "")
		{
		# It's a cash location that doesn't exist.  Go ahead and select the
		# [Cash: New] option because this probably arose due to some error,
		# or right after claiming a piece of cash.

		$selected = " selected";
		}

	$selector .= <<EOM;
<option$selected value="&#02;">[Cash: New]</option>
EOM
	}

	for my $loc (@$list_select_loc)
		{
		my $name = $s->map_id_to_nickname("loc",$loc);

		next if $name =~ /^\001/;  # skip inbound cash

		my $q_value;
		my $q_display;

		if ($name =~ /^\002/)
			{
			$q_value = "&#02;".$s->{html}->quote(substr($name,1));
			$q_display = "[Cash: $loc]";
			}
		else
			{
			$q_value = $s->{html}->quote($name);
			$q_display = $q_value;
			}

		my $selected = "";
		$selected = " selected" if $op->get("loc") eq $name;

		$selector .= <<EOM;
<option$selected value="$q_value">$q_display</option>
EOM
		}

	$selector .= <<EOM;
</select>
EOM
	$loc_selector = $selector;
	}

	$site->set_focus("qty");

	my $op = $site->{op};
	my $out = $s->{out};

	my $qty = $op->get("qty");
	my $q_qty = $s->{html}->quote($qty);

	my $size = $s->{html}->display_length($q_qty) + 3;
	$size = 10 if $size < 10;

	my $message = "";

	{
	my $status = $out->get("status");
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
		$message = $out->get("error_move");

		if ($message eq "")
			{
			$message = "Fail";
			}
		elsif ($message eq "missing_qty")
			{
			$message = "Please enter a quantity.";
			}
		elsif ($message eq "invalid_qty")
			{
			$message = "Not a valid quantity";
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
<tr style='height:70px;'>
<td align=right>
<span class=small>Quantity:</span>&nbsp;<input type=text size=$size name=qty value="$q_qty" style='text-align:right'>
</td>

<td>

<table>

<tr>
<td>
$type_selector
</td>
<td rowspan=2>
<input type=submit name=give value="Pay">
</td>
</tr>

<tr>
<td>
$loc_selector
</td>
</tr>

</table>

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

sub map_id_to_nickname
	{
	my $s = shift;
	my $kind = shift;
	my $id = shift;

	my $site = $s->{site};
	my $folder = $s->{object};
	my $name = $folder->get($kind."_name.$id");
	return $name;
	}

sub map_nickname_to_id
	{
	my $s = shift;
	my $kind = shift;
	my $name = shift;

	my $site = $s->{site};
	my $folder = $s->{object};

	my $list = $folder->get("list_".$kind);
	my @list = split(" ",$list);

	for my $id (@list)
		{
		my $id_name = $folder->get($kind."_name.$id");
		return $id if $id_name eq $name;
		}

	return "";
	}

sub map_ids_to_nicknames
	{
	my $s = shift;
	my $kind = shift;
	my $ids = shift;

	my $names = [];
	for my $id (@$ids)
		{
		push @$names, $s->map_id_to_nickname($kind,$id);
		}

	return $names;
	}

sub page_login
	{
	my $s = shift;

	my $site = $s->{site};
	my $op = $site->{op};

	if ($op->get("help"))
		{
		$site->object("Loom::Site::Loom::Page_Help",$site,"index")->respond;   # LATER get rid
		return;
		}

	push @{$site->{top_links}},
		$site->highlight_link(
			$site->url,
			"Home", 1);

	if ($op->get("logout") ne "")
		{
		my $warning = <<EOM;
<span class=small>Please
<span class=alarm><b>close your browser window</b></span> now.</span>
EOM
		push @{$site->{top_links}}, $warning;
		}

	my $out = $s->{out};

	$site->set_focus("passphrase");

	my $error = $out->get("error_passphrase");

	if ($error eq "missing")
		{
		$error = "Please enter a passphrase.";
		}
	elsif ($error eq "too_small")
		{
		my $min_length = $out->get("error_passphrase_min_length");
		$error = "Please enter at least $min_length characters.";
		}
	elsif ($error eq "too_large")
		{
		my $max_length = $out->get("error_passphrase_max_length");
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

	my $hidden = $s->{html}->hidden_fields($op->slice(qw(function)));

	# Allow specifying partial or complete passphrase in URL.  That way you
	# could bookmark the first part of a passphrase, and type in the rest.

	my $q_passphrase = "";
	if ($op->get("login") eq "")
		{
		my $passphrase = $op->get("passphrase");
		$q_passphrase = $s->{html}->quote($passphrase);
		}

	my $link_folder_new = $site->highlight_link(
		$site->url(function => "folder", new_folder => 1),
		"sign up",
		0,
		"Become a brand new user",
		);

	my $login_greeting = $site->{login_greeting};
	if (!defined $login_greeting)
		{
		my $name = $site->{config}->get("system_name");
		$login_greeting = "<h2>\nWelcome to $name.</h2>";
		}

	$site->{need_keyboard} = 1;

	$site->{body} .= <<EOM;
$login_greeting
<p>
Please enter your folder passphrase and press Login.
For extra protection against keystroke loggers, click the keyboard
icon and enter some or all of your passphrase by clicking instead of typing.
<p>
<form method=post action="">
$hidden
<div>
<input type=password name=passphrase size=40 value="$q_passphrase" class="keyboardInput">
<input type=submit name=login value="Login">$error
</div>
</form>
<p>
EOM

	{
	my $color = "";
	my $msg = "";

	my $this_url = $site->{config}->get("this_url");

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

	$site->{body} .= <<EOM;
<span class=small style='color:$color; font-weight:bold; margin-left:20px;'>
$msg
</span>
EOM

	}

	# LATER: we'll spruce up sign-up process.

	$site->{body} .= <<EOM;
<h2>Are you a new user?</h2>
You may
$link_folder_new
if you have an invitation from somebody already in the system.
EOM

	push @{$site->{top_links}}, "";

	push @{$site->{top_links}},
		$site->highlight_link(
			$site->url(function => "folder", new_folder => 1),
			"Sign Up", 0, "Become a brand new user");

	push @{$site->{top_links}},
		$site->highlight_link(
			"/faq",
			"FAQ", 0, "Frequently Asked Questions");

	push @{$site->{top_links}},
		$site->highlight_link(
			$site->url(help => 1, topic => "contact_info"),
			"Contact", 0, "Contact someone for help with your questions");

	push @{$site->{top_links}},
		$site->highlight_link(
			"/news",
			"News", 0, "See the latest announcements and other useful information");
	push @{$site->{top_links}},
		$site->highlight_link(
			"/merchants",
			"Merchants", 0, "See who uses Loom");

	push @{$site->{top_links}},
		$site->highlight_link(
			$site->url(help => 1),
			"Advanced", 0,
			"Advanced functions which may interest experts and developers",
			);

	return;
	}

sub handle_login
	{
	my $s = shift;

	my $site = $s->{site};
	my $op = $site->{op};

	$op->put("session","");
	my $passphrase = $op->get("passphrase");

	my $min_length = 8;
	my $max_length = 255;

	die if $min_length > $max_length;

	my $out = $s->{out};

	if ($passphrase eq "")
		{
		$out->put("error_passphrase","missing");
		}
	elsif (length($passphrase) < $min_length)
		{
		$out->put("error_passphrase","too_small");
		$out->put("error_passphrase_min_length", $min_length);
		}
	elsif (length($passphrase) > $max_length)
		{
		$out->put("error_passphrase","too_large");
		$out->put("error_passphrase_max_length", $max_length);
		}
	else
		{
		my $session = $site->{login}->login($passphrase);

		if ($session eq "")
			{
			$out->put("error_passphrase","invalid");
			}

		$op->put("session",$session);
		}
	}

sub handle_new_folder
	{
	my $s = shift;

	my $site = $s->{site};

	my $op = $site->{op};
	my $out = $s->{out};

	$site->set_title("Create Folder");
	$site->set_focus("passphrase");

	$out->put("status","");

	# Normalize the usage parameter
	{
	my $usage = $op->get("usage");
	$usage = $s->{html}->trimblanks($usage);
	$op->put("usage",$usage);
	}

	my $build = $s->build_folder_template($op);

	if ($op->get("create_folder") ne "")
		{
		if ($out->get("status") eq "")
			{
			$site->set_focus("passphrase");

			my $passphrase = $op->get("passphrase");
			if (length($passphrase) < 8)
				{
				$out->put("status","fail");
				$out->put("error_passphrase","too_short");
				}
			elsif (length($passphrase) > 255)
				{
				$out->put("status","fail");
				$out->put("error_passphrase","too_long");
				}
			}

		if ($out->get("status") eq "")
			{
			my $passphrase = $op->get("passphrase");
			my $passphrase2 = $op->get("passphrase2");

			if ($passphrase2 ne $passphrase)
				{
				$out->put("status","fail");
				$out->put("error_passphrase2","no_match");
				}
			}

		if ($out->get("status") eq "")
			{
			$site->set_focus("usage");

			my $usage = $op->get("usage");
			$usage = $s->{html}->trimblanks($usage);
			$op->put("usage",$usage);

			if (!$s->{id}->valid_id($usage))
				{
				$out->put("status","fail");
				$out->put("error_usage","not_valid_id");
				}
			}

		if ($out->get("status") eq "")
			{
			# Everything looks good so far, let's see if the passphrase is
			# already taken.

			my $archive = $s->{archive};
			my $passphrase = $op->get("passphrase");

			my $loc_folder = $site->{login}->location($passphrase);

			$archive->touch($loc_folder);

			my $rsp = $archive->{api}->{rsp};
			my $status = $rsp->get("status");

			if ($rsp->get("status") eq "success")
				{
				# Something is already at this folder location, so ask
				# user to choose a different passphrase.

				$site->set_focus("passphrase");

				$out->put("status","fail");
				$out->put("error_passphrase","taken");
				}
			}

		if ($out->get("status") eq "")
			{
			# Double-checking
			my $passphrase = $op->get("passphrase");
			my $passphrase2 = $op->get("passphrase2");
			die if $passphrase ne $passphrase2;
			die if length($passphrase) < 8 || length($passphrase) > 255;
			}

		# See if there are enough usage tokens in this invitation to fund
		# the creation.

		if ($out->get("status") eq "")
			{
			my $sponsor = $op->get("usage");

			my $grid = $s->{grid};
			my $usage_type = "0" x 32;

			my $value = $grid->touch($usage_type,$sponsor);

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

				$grid->buy($usage_type,$sponsor,$sponsor);
				$value = $grid->touch($usage_type,$sponsor);
				}

			$value = "0" if $value eq "";

			if ($value !~ /^-/ && $value < $build->{min_usage})
				{
				$out->put("status","fail");
				$out->put("error_usage","insufficient");
				$out->put("error_usage_here",$value);
				$out->put("error_usage_min",$build->{min_usage});
				}
			}

		# If everything went well, go ahead and create the folder.

		if ($out->get("status") eq "")
			{
			my $archive = $s->{archive};
			my $grid = $s->{grid};

			my $sponsor = $op->get("usage");

			my $type_usage = "0" x 32;
			$archive->buy($build->{location},$sponsor);

			# Get the location "adjacent" to the folder itself and we'll
			# store the session id there.

			my $session_ptr = $s->{id}->xor_hex($build->{location},
				"0" x 31 . "1");

			# Create an initial session.

			my $session = $archive->random_vacant_location;

			# Store the session id adjacent to the folder.

			$archive->buy($session_ptr,$sponsor);
			$archive->write($session_ptr,$session,$sponsor);

			# Store the folder location at the session id.

			$archive->buy($session,$sponsor);
			$archive->write($session,$build->{location},$sponsor);

			# Write the folder text.

			$archive->write($build->{location},$build->{folder_text},$sponsor);

			# Buy the folder location for each asset type.

			for my $type (@{$build->{list_type}})
				{
				$grid->buy($type,$build->{location},$sponsor);
				}

			# Take all assets away from the sponsor drop point.

			for my $type (@{$build->{list_type}})
				{
				my $remain = $grid->touch($type,$sponsor);
				$grid->move($type,$remain,$sponsor,$build->{location});
				}

			$op->put("session",$session);  # TODO review this

			return;
			}
		}

	my $q_error_usage = "";
	my $q_error_passphrase = "";
	my $q_error_passphrase2 = "";

	if ($out->get("status") eq "fail")
		{
		my $error_usage = $out->get("error_usage");

		if ($error_usage eq "not_valid_id")
			{
			$error_usage = "Not a valid hexadecimal id";
			}
		elsif ($error_usage eq "insufficient")
			{
			my $min = $out->get("error_usage_min");
			my $here = $out->get("error_usage_here");

			$error_usage = "This invitation has $here usage tokens, but you ";
			$error_usage .= "need at least $min to create a folder.  ";

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

		my $error_passphrase = $out->get("error_passphrase");

		if ($error_passphrase eq "too_short")
			{
			$error_passphrase = "Please enter at least 8 characters.";
			}
		elsif ($error_passphrase eq "too_short")
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

		my $error_passphrase2 = $out->get("error_passphrase2");

		if ($error_passphrase2 eq "no_match")
			{
			$error_passphrase2 = "The passphrases did not match.";
			}

		if ($error_passphrase2 ne "")
			{
			$q_error_passphrase2 = qq{<br><span class=alarm>$error_passphrase2</span>};
			}
		}

	my $context = Loom::Context->new($op->slice(qw(function new_folder invite)));

	# Include extra type and location information supplied in the invitation.
	{
	$context->put($op->slice(qw(owner.name sponsor.name)));

	my $nT = $op->get("nT");
	$context->put("nT",$nT);

	$nT = 0 if $nT eq "";
	for my $type_no (1 .. $nT)
		{
		for my $field (qw(id name display))
			{
			my $key = "T$type_no.$field";
			$context->put($key, $op->get($key));
			}
		}
	}

	my $hidden = $s->{html}->hidden_fields($context->pairs);

	my $input_size_id = 32 + 4;

	my $usage = $op->get("usage");
	my $q_usage = $s->{html}->quote($usage);

	push @{$site->{top_links}},
		$site->highlight_link(
			$site->url,
			"Home");

	push @{$site->{top_links}},
		$site->highlight_link(
			$site->url($context->pairs, usage => $usage),
			"Sign Up", 1);

	$site->{body} .= <<EOM;
<h1> Create a New Folder </h1>

<hr>
<h2> Step 1:  Choose a passphrase </h2>

<p>
To create a new folder, you first need to choose a passphrase for it.
We advise you <em><b>not</b></em> to choose something off the top of your head,
such as a birthday or pet's name, because that would be too easy for
others to guess.  Instead, press the Random Passphrase button below.  That will
create a 5 word passphrase that is very easy to remember, yet very strong.
<p>
Guessing a 5-word passphrase is about like winning the lottery a million
million times in a row.  If you want an even stronger passphrase, you can
press the button again to gather more words.

EOM
	$site->{body} .= <<EOM;
<p>
<form method=post action="" autocomplete=off>
$hidden
EOM
	$site->{body} .= <<EOM;
<p>
<input type=submit name=random_passphrase value="Random Passphrase">
EOM
	if ($op->get("random_passphrase") ne "")
	{
	my $passphrase = $site->{diceware}->get(5);

	$site->{body} .= <<EOM;
<p>
<span class=tt>$passphrase</span>

<p>
We advise you to <em><b>write down</b></em> your new passphrase and keep it in a
<em><b>very safe</b></em> place.  (Do not tape it to your computer monitor.)
Eventually you may type the passphrase so many times that you'll feel safe in
destroying the original piece of paper, but we recommend keeping the paper
hidden for quite a while to ensure that you don't forget the passphrase.

<p class=alarm>
<b>WARNING:</b>
If you lose your passphrase, you lose all the assets in this folder.
There is <em><b>no way</b></em> to retrieve a lost passphrase.
</p>

EOM
	}

	$site->{body} .= <<EOM;
<hr>
<h2> Step 2: Enter the passphrase </h2>

<p>
Now type your chosen passphrase into the field below, and type it again
to make sure you entered it correctly.
EOM
	if ($op->get("random_passphrase") ne "")
	{
	$site->{body} .= <<EOM;
Make sure you <em><b>type</b></em> the passphrase using your keyboard &mdash;
<span class=alarm>do not</span> copy and paste it.
EOM
	}

	$site->{need_keyboard} = 1;

	$site->{body} .= <<EOM;

<table border=0 cellpadding=5 style='border-collapse:collapse'>

<colgroup>
<col width=250>
<col width=500>
</colgroup>

<tr>
<td>
Enter passphrase for this folder:
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

	if ($op->get("invite"))
	{
	}
	else
	{
	$site->{body} .= <<EOM;
<hr>
<h2> Step 3: Paste your invitation into the box and press Create Folder. </h2>

EOM
	}

	$site->{body} .= <<EOM;
<table border=0 cellpadding=5 style='border-collapse:collapse'>

<colgroup>
<col width=250>
<col width=500>
</colgroup>

EOM

	if ($op->get("invite"))
	{
	$site->{body} .= <<EOM;
<tr>
<td></td>
<td>
<input type=hidden name=usage value="$q_usage">
$q_error_usage
</td>
</tr>
EOM
	}
	else
	{
	$site->{body} .= <<EOM;
<tr>
<td>
Paste your invitation here:
</td>
<td>
<input type=text class=tt name=usage size=$input_size_id value="$q_usage">
$q_error_usage
</td>
</tr>
EOM
	}

	$site->{body} .= <<EOM;

<tr>
<td>
</td>
<td>
<input type=submit name=create_folder value="Create Folder">
</td>
</tr>

</table>
EOM

	{
	# Rig up the asset display parameters and call the display routine.

	my $display = {};
	$display->{flavor} = "invite_location";

	my $loc_name = $op->get("sponsor.name");
	$loc_name = "sponsor" if $loc_name eq "";
	$display->{location_name} = $loc_name;

	$s->{object} = $build->{object};
	$s->{location} = $build->{location};

	# Look first to see if anything is there.

	$s->configure_value_display($display);

	{
	my $sponsor = $op->get("usage");

	if ($sponsor eq "")
		{
		}
	elsif (!$s->{id}->valid_id($sponsor))
		{
		$site->{body} .= <<EOM;
<hr>
<h1 class=alarm> Warning </h1>
<p>
This is not a valid invitation code.
EOM
		}
	elsif ($display->{involved_loc}->{$sponsor})
		{
		# Check for sufficient usage.

		my $actual_usage = $display->{usage_count}->{$sponsor};
		$actual_usage = "0" if !defined $actual_usage;

		if ($actual_usage >= $build->{min_usage})
		{
		$site->{body} .= <<EOM;
<hr>
<h1>Assets you will receive</h1>
<p>
Your sponsor is offering you the following assets.  When you create your new
folder, you will be charged $build->{cost} usage tokens, and any remaining
assets will become yours.  
EOM
		}
		else
		{
		$site->{body} .= <<EOM;
<hr>
<h1>Not enough usage tokens here!</h1>
<p>
Your sponsor is offering you the following assets.  However, your sponsor must
move at least $build->{min_usage} usage tokens to this invitation before it
will work.
EOM
		}

		}
	else
		{
		$site->{body} .= <<EOM;
<hr>
<h1 class=alarm> Warning </h1>
<p>
There are no assets in this invitation.  Perhaps the invitation has already
been taken, or there was some mistake in transmission.  Please check with your
sponsor.
EOM
		}
	}

	$site->{body} .= $s->page_folder_value_table($display);

	$s->{object} = undef;
	$s->{location} = undef;
	}

	if ($op->get("invite"))
	{
	}
	elsif ($op->get("usage") eq "")
	{
	my $url = $site->url(help => 1, topic => "get_usage_tokens");
	my $link = qq{<a class=large href="$url">How do I get an invitation?</a>};

	$site->{body} .= <<EOM;
<p>
$link
EOM
	}

	$site->{body} .= <<EOM;
</form>
EOM

	return;
	}

sub build_folder_template
	{
	my $s = shift;
	my $op = shift;  # context

	my $site = $s->{site};

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
	my $passphrase = $op->get("passphrase");
	$build->{location} = $site->{login}->location($passphrase);

	$build->{object} = Loom::Context->new;

	# Build up the folder object in memory based on the invitation
	# parameters.

	{
	$build->{object}->put("Content-type", "loom/folder");

	# Build the list of asset types from the invitation url.

	my $install_types = [];

	{
	my $usage_type = "0" x 32;
	my $found_usage_type = 0;

	my $nT = $op->get("nT");
	$nT = 0 if $nT eq "";

	for my $type_no (1 .. $nT)
		{
		my $id = $op->get("T$type_no.id");
		my $name = $op->get("T$type_no.name");
		my $display = $op->get("T$type_no.display");

		next if $id eq "" || $name eq "";
		next if !$s->{id}->valid_id($id);

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
	$build->{object}->put("list_type", $list_type);

	for my $entry (@$install_types)
		{
		my ($type,$nickname,$scale,$min_precision) = @$entry;
		$build->{object}->put("type_name.$type",$nickname);
		$build->{object}->put("type_scale.$type", $scale);
		$build->{object}->put("type_min_precision.$type", $min_precision);
		}

	my $sponsor = $op->get("usage");

	my $install_locs = [];

	my $owner_name = $op->get("owner.name");
	$owner_name = "My New Folder" if $owner_name eq "";

	my $sponsor_name = $op->get("sponsor.name");
	$sponsor_name = "My Sponsor" if $sponsor_name eq "";

	push @$install_locs, [$build->{location},$owner_name];
	push @$install_locs, [$sponsor,$sponsor_name];

	for my $entry (@$install_locs)
		{
		my $loc = $entry->[0];
		push @{$build->{list_loc}}, $loc;
		}

	my $list_loc = join(" ",@{$build->{list_loc}});
	$build->{object}->put("list_loc", $list_loc);

	for my $entry (@$install_locs)
		{
		my ($loc,$nickname) = @$entry;
		$build->{object}->put("loc_name.$loc", $nickname);
		}

	# Enable transaction history by default.
	$build->{object}->put("recording",1);
	}

	# Now estimate cost of creation.

	my $archive = $s->{archive};
	$build->{folder_text} = $archive->object_text($build->{object});

	$build->{cost}++;  # will buy folder location in archive

	# Compute cost of folder object in archive.
	{
	my $blocks = $s->{quote}->pad_quote($build->{folder_text},16);

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

# Format a grid value for display according to the conventions of the current
# folder.
#
# If the value is negative, we take out the extra -1 which is due to the
# 2s-complement representation.  For example a raw -1 balance in the grid
# will show as -0 on the web page, which should be more clear to the issuer.

sub display_value
	{
	my $s = shift;
	my $value = shift;
	my $type = shift;

	my $site = $s->{site};

	die if !defined $type;

	my $folder = $s->{object};
	my $scale = $folder->get("type_scale.$type");
	my $min_precision = $folder->get("type_min_precision.$type");

	my $format = Loom::Qty->new;
	return $format->ones_complement_float($value,$scale,$min_precision);
	}

sub get_sorted_list_loc
	{
	my $s = shift;

	my $site = $s->{site};
	my $folder = $s->{object};

	my $list_loc = $folder->get("list_loc");
	my @list_loc = split(" ",$list_loc);

	return @list_loc if @list_loc == 0;

	my $first_loc = shift @list_loc;

	my @result =
		map { $_->[0] }
		sort { $a->[1] cmp $b->[1] }
		map { [$_, $s->map_id_to_nickname("loc",$_)] }
		@list_loc
		;

	unshift @result, $first_loc;
	return @result;
	}

sub get_sorted_list_type
	{
	my $s = shift;

	my $site = $s->{site};
	my $folder = $s->{object};

	my $list_type = $folder->get("list_type");
	my @list_type = split(" ",$list_type);

	my @result =
		map { $_->[0] }
		sort { $a->[1] cmp $b->[1] }
		map { [$_, $s->map_id_to_nickname("type",$_)] }
		@list_type
		;

	return @result;
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
