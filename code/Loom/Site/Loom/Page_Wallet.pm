package Loom::Site::Loom::Page_Wallet;
use strict;
use Loom::Context;

sub new
	{
	my $class = shift;
	my $folder = shift;

	my $s = bless({},$class);
	$s->{folder} = $folder;
	return $s;
	}

sub respond
	{
	my $s = shift;

	my $site = $s->{folder}->{site};
	my $op = $site->{op};

	$s->{menu} = "main";

	if ($op->get("help"))
		{
		$s->help;
		}
	else
		{
		$s->handle_receive_cash;
		$s->handle_move_assets;
		$s->handle_history;
		$s->page_folder_main;
		}

	$s->top_links;

	return;
	}

sub top_links
	{
	my $s = shift;

	my $site = $s->{folder}->{site};
	my $op = $site->{op};

	if ($s->{menu} eq "main")
		{
		push @{$site->{top_links}}, "";

		push @{$site->{top_links}},
			$site->highlight_link(
				$site->url(function => "contact", $op->slice("session")),
				"Contacts", 0, "Manage contacts, invite new users");

		push @{$site->{top_links}},
			$site->highlight_link(
				$site->url(function => "asset", $op->slice("session")),
				"Asset Types", 0, "Manage asset types");
		}

	if ($s->{menu} eq "main" || $s->{menu} eq "help")
		{
		push @{$site->{top_links}},
			$site->highlight_link(
				$site->url($op->slice("function","session"), help => 1),
				"Help",
				$s->{menu} eq "help",
				"Describe how this page is used",
				);
		}

	if ($s->{menu} eq "help")
		{
		push @{$site->{top_links}}, "";
		push @{$site->{top_links}},
			$site->highlight_link(
				$site->url($op->slice("function","session"), help => 1,
					print => 1),
				"Print");
		}
	}

sub page_folder_main
	{
	my $s = shift;

	my $folder = $s->{folder};
	my $site = $folder->{site};

	my $op = $site->{op};

	my $display = {};
	$display->{flavor} = "move_dialog";

	my $hidden = $folder->{html}->hidden_fields(
		$op->slice(qw(function h_id h_pi h_pn h_only session)));

	$site->{body} .= <<EOM;
<form method=post action="" autocomplete=off>
$hidden
EOM

	$site->{body} .= $folder->page_folder_value_table($display)
		if !$op->get("h_only");
	$s->show_history;

	$site->{body} .= <<EOM;
</form>
EOM

	return;
	}

# Display history.

sub show_history
	{
	my $s = shift;

	my $folder = $s->{folder};
	my $site = $folder->{site};
	my $op = $site->{op};

	my $even_color = "#E8F8FE";
	my $odd_color = "#FFFFFF";

	my $now_recording = $folder->{object}->get("recording");
	my $table = "";

	$table .= <<EOM;
<table border=0 cellpadding=0 style='border-collapse:collapse;'>
<colgroup>
<col width=150>
<col width=110>
<col width=220>
<col width=220>
</colgroup>

EOM

	if ($now_recording)
	{
	my $history_control = "";

	# Establish history control links.
	{
	my @params = $op->slice(qw(function h_pi h_pn session));

	if ($op->get("h_only"))
		{
		my $url = $site->url(@params);

		$history_control .=
		qq{<a href="$url" title="Restore wallet display">Show wallet</a>};
		}
	else
		{

		{
		my $url = $site->url(@params, h_only => 1);

		$history_control .=
		qq{<a href="$url" title="Show history only">Zoom</a>};
		}

		{
		my $url = $site->url(
			function => $op->get("function"),
			set_recording => 0,
			$op->slice(qw(qty type loc)),
			session => $op->get("session"),
			);

		$history_control .=
		qq{<a href="$url" style='padding-left:10px' }
		.qq{title="Disable transaction history">Disable</a>};
		}

		}
	}

	{
	my $list_H = $folder->{object}->get("list_H");
	my @list_H = split(" ",$list_H);
	$s->{list_H} = \@list_H;
	$s->{count_H} = scalar(@list_H);
	}

	$s->normalize_scroll_position;

	my $num_items = $s->{count_H};
	my $list_H = $s->{list_H};

	# Establish first absolute row number to display.
	my $h_pn = $op->get("h_pn");
	$h_pn = $num_items if $h_pn eq "";

	my $rows_per_page = 20;  # LATER configurable

	my $max_row = $h_pn;
	my $min_row = $max_row - $rows_per_page + 1;
	$min_row = 1 if $min_row < 1;

	# Establish links for scrolling through history.

	my @scroll_links = ();

	{
	my @params = $op->slice(qw(function h_only session));

	# Newest
	{
	my $title = "Newest";
	my $label = "|&lt;";

	my $attr = "";
	$attr = " style='color:gray'" if $max_row == $num_items;

	my $context = Loom::Context->new(@params);

	my $url = $site->url($context->pairs);
	my $link = qq{<a$attr href="$url" title="$title">$label</a>};

	push @scroll_links, $link;
	}

	# Newer
	{
	my $title = "Newer";
	my $label = "&lt;";

	my $attr = "";
	$attr = " style='color:gray'" if $max_row == $num_items;

	my $row_no = $max_row + $rows_per_page;
	$row_no = $num_items if $row_no > $num_items;
	my $h_id = $list_H->[$num_items-$row_no];

	my $context = Loom::Context->new(@params,
		h_pi => $h_id, h_pn => $row_no);

	my $url = $site->url($context->pairs);
	my $link = qq{<a$attr href="$url" title="$title">$label</a>};

	push @scroll_links, $link;
	}

	# Older
	{
	my $title = "Older";
	my $label = "&gt;";

	my $attr = "";
	$attr = " style='color:gray'" if $min_row == 1;

	my $row_no = $min_row - 1;
	$row_no = $rows_per_page if $row_no < $rows_per_page;
	$row_no = 1 if $row_no < 1;
	my $h_id = $list_H->[$num_items-$row_no];

	my $context = Loom::Context->new(@params,
		h_pi => $h_id, h_pn => $row_no);

	my $url = $site->url($context->pairs);
	my $link = qq{<a$attr href="$url" title="$title">$label</a>};

	push @scroll_links, $link;
	}

	# Oldest
	{
	my $title = "Oldest";
	my $label = "&gt;|";

	my $attr = "";
	$attr = " style='color:gray'" if $min_row == 1;

	my $row_no = $rows_per_page;

	my $context = Loom::Context->new(@params, h_pn => $rows_per_page);

	my $url = $site->url($context->pairs);
	my $link = qq{<a$attr href="$url" title="$title">$label</a>};

	push @scroll_links, $link;
	}
	}

	my $scroll_panel = <<EOM;
<table border=0 style='border-collapse:collapse'>
<colgroup>
<col width=25>
<col width=25>
<col width=25>
<col width=25>
</colgroup>
<tr>
<td align=left> $scroll_links[0] </td>
<td align=left> $scroll_links[1] </td>
<td align=right> $scroll_links[2] </td>
<td align=right> $scroll_links[3] </td>
</tr>
</table>
EOM

	$table .= <<EOM;
<tr>
<td colspan=2 class=folder_section>
Transaction History
</td>
<td align=left class=folder_section_links>
$scroll_panel
</td>
<td align=right class=folder_section_links>
$history_control
</td>
</tr>

<tr style='background-color:$even_color; height:30px;'>
<th align=left>
Time (UTC)
</th>
<th align=right>
<span style='margin-right:11px'>Quantity</span>
</th>
<th align=left>
<span style='margin-right:14px'>Asset</span>
</th>
<th align=left>
<span style='margin-right:8px'>To/From Contact</span>
</th>
</tr>

EOM

	my $row_context = Loom::Context->new(
		$op->slice(qw(function h_pi h_pn h_only session)));
	my $odd_row = 1;  # for odd-even coloring

	my $min_pos = $num_items - $max_row;
	my $max_pos = $num_items - $min_row;

	for my $pos ($min_pos .. $max_pos)
	{
	my $h_id = $list_H->[$pos];

	my $row_color = $odd_row ? $odd_color : $even_color;
	$odd_row = 1 - $odd_row;

	my $time = $folder->{object}->get("H_time.$h_id");
	my $qty = $folder->{object}->get("H_qty.$h_id");
	my $type = $folder->{object}->get("H_type.$h_id");
	my $loc = $folder->{object}->get("H_loc.$h_id");

	my $dttm = Loom::Dttm->new($time)->as_gmt;

	my $q_loc_name;
	my $q_type_name;

	{
	my $type_name = $folder->map_id_to_nickname("type",$type);

	if ($type_name eq "")
		{
		$q_type_name = $folder->{html}->quote($type);
		my $scale = $folder->{object}->get("type_scale.$type");
		$q_type_name = qq{<span class=tiny_mono>$q_type_name $scale</span>};
		}
	else
		{
		$q_type_name = $folder->{html}->quote($type_name);

		if ($folder->{object}->get("type_del.$type"))
			{
			# Deleted asset: show the name in italics.
			$q_type_name = qq{<i>$q_type_name</i>};

			if ($h_id eq $op->get("h_id"))
				{
				# User clicked on this history entry, so show the ID and scale
				# of the deleted asset as well.

				my $scale = $folder->{object}->get("type_scale.$type");
				$q_type_name .= qq{<br><span class=tiny_mono>$type $scale</span>};
				}
			}
		}
	}

	{
	my $loc_name = $folder->map_id_to_nickname("loc",$loc);

	if ($loc_name eq "")
		{
		$q_loc_name = $folder->{html}->quote($loc);
		$q_loc_name = qq{<span class=tiny_mono>$q_loc_name</span>};
		}
	elsif ($loc_name =~ /^\001/ || $loc_name =~ /^\002/)
		{
		# We render cash locations as raw hex ID as well.

		$q_loc_name = $folder->{html}->quote($loc);
		$q_loc_name = qq{<span class=tiny_mono>$q_loc_name</span>};
		}
	else
		{
		$q_loc_name = $folder->{html}->quote($loc_name);

		if ($folder->{object}->get("loc_del.$loc"))
			{
			# Deleted contact: show the name in italics.
			$q_loc_name = qq{<i>$q_loc_name</i>};

			if ($h_id eq $op->get("h_id"))
				{
				# User clicked on this history entry, so show the ID of the
				# deleted contact as well.
				$q_loc_name .= qq{<br><span class=tiny_mono>$loc</span>};
				}
			}
		}
	}

	# LATER put in the time-based page navigation thing like you did for
	# Receivables system.

	$row_context->put(h_id => $h_id);

	my $url = $site->url($row_context->pairs);
	my $link =
	qq{<a href="$url" title="Edit this entry">$dttm</a>};

	my $abs_qty = $qty;
	my $sign = "";
	if ($qty =~ /^-/)
		{
		$sign = "-";
		$abs_qty = substr($qty,1);
		}
	else
		{
		$sign = "+";
		}

	my $dsp_qty = $sign.$folder->display_value($abs_qty,$type);

	{
	my $color = $sign eq "+" ? "green" : "red";
	$dsp_qty = qq{<span style='color:$color'>$dsp_qty</span>};
	}

	$table .= <<EOM;
<tr valign=middle style='background-color:$row_color; height:23px;'>
<td>
$link
</td>
<td align=right>
<span style='margin-right:11px'>$dsp_qty</span>
</td>
<td>
<span style='margin-right:14px'>$q_type_name</span>
</td>
<td>
$q_loc_name
</td>
</tr>
EOM

	if ($h_id eq $op->get("h_id"))
	{
	$site->set_focus("memo");

	my $memo = $folder->{object}->get("H_memo.$h_id");
	my $q_memo = $folder->{html}->semiquote($memo);

	my @lines = split("\n",$memo);
	my $num_lines = scalar(@lines);

	my $num_rows = $num_lines;
	$num_rows = 1 if $num_rows < 1;
	$num_rows = 20 if $num_rows > 20;

	# LATER special History menu item

	# LATER when you click the entry, scroll it to the top?

	$table .= <<EOM;
<tr style='background-color:$row_color'>
<td colspan=4>
<textarea name=memo rows=$num_rows cols=80 style='margin-left:20px;'>
$q_memo</textarea>
</td>
</tr>
<tr style='background-color:$row_color'>
<td colspan=2 align=right>
<input type=submit name=save_history value="Save">
<input type=submit name=cancel_history value="Cancel">
</td>
<td align=right>
<input type=submit name=delete_history value="Delete">
</td>
<td>
</td>
<td>
</td>
</tr>
EOM
	}
	else
	{

	my $memo = $folder->{object}->get("H_memo.$h_id");

	if ($memo ne "")
	{
	my $q_memo = $folder->{html}->semiquote($memo);
	$q_memo =~ s/\n/<br>/g;

	# We use the "overflow" style attribute on the memo to prevent very wide
	# non-breakable memos from messing up the table appearance.

	$table .= <<EOM;
<tr style='background-color:$row_color'>
<td colspan=5>
<div style='overflow: auto; font-size:10pt; display:block; margin-left:20px; margin-top: 0px; margin-bottom:2px'>
$q_memo
</div>
</td>
</tr>
EOM
	}

	}

	}

	}
	else
	{
	my $url = $site->url(
		function => $op->get("function"),
		set_recording => 1,
		$op->slice(qw(qty type loc)),
		session => $op->get("session"),
		);

	my $link_enable =
	qq{<a href="$url" title="Enable transaction history">}
	.qq{[Enable transaction history]</a>};

	$table .= <<EOM;
<tr>
<td colspan=3>
</td>
<td align=right>
$link_enable
</td>
</tr>

EOM
	}

	$table .= <<EOM;
</table>
EOM

	$site->{body} .= <<EOM;
<p>
$table
EOM

	return;
	}

# Establish scroll position based on id h_pi and row number h_pn.

sub normalize_scroll_position
	{
	my $s = shift;

	my $folder = $s->{folder};
	my $site = $folder->{site};
	my $op = $site->{op};

	{
	my $key = "h_pi";
	my $val = $op->get($key);
	unless ($val =~ /^([a-f0-9]{8})$/ && length($1) == length($val))
		{
		$op->put($key,"");
		}
	}

	{
	my $key = "h_pn";
	my $val = $op->get($key);
	unless ($val =~ /^([0-9]{1,8})$/ && length($1) == length($val))
		{
		$op->put($key,"");
		}
	}

	{
	my $key = "h_pi";
	my $val = $op->get($key);

	if ($val ne "")
		{
		my $time = $folder->{object}->get("H_time.$val");
		if ($time eq "")
			{
			$op->put($key,"");
			}
		}
	}

	{
	my $h_pi = $op->get("h_pi");

	if ($h_pi ne "")
		{
		my $list = $s->{list_H};
		my $pos = 0;
		for my $h_id (@$list)
			{
			last if $h_id eq $h_pi;
			$pos++;
			}

		my $num_items = $s->{count_H};

		if ($pos < $num_items)
			{
			$op->put("h_pn",$num_items - $pos);
			}
		else
			{
			$op->put("h_pi","");
			}
		}
	}

	{
	my $h_pn = $op->get("h_pn");

	if ($h_pn ne "")
		{
		my $num_items = $s->{count_H};

		if ($h_pn < 1)
			{
			$op->put("h_pn","");
			}
		elsif ($h_pn > $num_items)
			{
			$op->put("h_pn",$num_items);
			}
		}
	}

	{
	my $h_pi = $op->get("h_pi");
	my $h_pn = $op->get("h_pn");

	if ($h_pi eq "" && $h_pn ne "")
		{
		my $list = $s->{list_H};
		my $num_items = $s->{count_H};
		$h_pi = $list->[$num_items - $h_pn];
		$op->put("h_pi",$h_pi);
		}
	}

	return;
	}

sub handle_receive_cash
	{
	my $s = shift;

	my $folder = $s->{folder};
	my $site = $folder->{site};
	my $op = $site->{op};
	my $out = $folder->{out};

	$out->put("status_receive","");

	my $loc = $op->get("received_cash_token");
	$loc = $folder->{html}->trimblanks($loc);
	return if $loc eq "";

	$op->put("received_cash_token",$loc);

	if (!$s->{folder}->{id}->valid_id($loc))
		{
		$out->put("status_receive","fail");
		$out->put("error_token","malformed");
		return;
		}

	my $loc_name = $s->{folder}->map_id_to_nickname("loc",$loc);

	if ($loc_name ne "")
		{
		$out->put("status_receive","fail");
		$out->put("error_token","already_exists");
		return;
		}

	my $time = time();
	my $new_name = "\001$time $loc";  # inbound cash

	my $folder_object = $s->{folder}->{object};
	my $loc_folder = $s->{folder}->{location};

	my $list_loc = $folder_object->get("list_loc");
	my @list_loc = split(" ",$list_loc);
	push @list_loc, $loc;

	$list_loc = join(" ",@list_loc);

	$folder_object->put("list_loc",$list_loc);
	$folder_object->put("loc_name.$loc", $new_name);

	my $archive = $s->{folder}->{archive};

	$archive->write_object($loc_folder,$folder_object,$loc_folder);

	{
	my $rsp = $archive->{api}->{rsp};
	if ($rsp->get("status") ne "success")
		{
		# Insufficent usage.  Let's see if the received cash location
		# itself has enough usage tokens.

		$archive->write_object($loc_folder,$folder_object,$loc);

		$rsp = $archive->{api}->{rsp};
		if ($rsp->get("status") ne "success")
			{
			$out->put("status_receive","fail");
			$out->put("error_token","insufficent_usage");
			}
		}
	}

	$s->{folder}->{object} = $archive->touch_object($loc_folder);

	return if $out->get("status_receive") ne "";

	$out->put("status_receive","success");

	return;
	}

sub handle_move_assets
	{
	my $s = shift;

	my $folder = $s->{folder};
	my $site = $folder->{site};
	my $op = $site->{op};
	my $out = $folder->{out};

	$out->put("status","");
	$out->put("error_move","");

	return if $op->get("give") eq "" && $op->get("take") eq "";

	# Clear the history scroll/edit status.
	$op->put("h_id","");
	$op->put("h_pi","");
	$op->put("h_pn","");

	my $qty = $op->get("qty");
	$qty = $folder->{html}->trimblanks($qty);
	$op->put("qty",$qty);

	if ($qty eq "")
		{
		$out->put("status","fail");
		$out->put("error_move","missing_qty");
		return;
		}

	# We allow a negative quantity in a Pay operation.  Sometimes a user
	# wants to move only a portion of the assets away from a contact point,
	# instead of clicking to take the whole thing.

	my $is_negative_qty = ($qty =~ /^-/);

	my $type_name = $op->get("type");
	my $loc_name = $op->get("loc");

	my $type = $folder->map_nickname_to_id("type",$type_name);
	my $loc = $folder->map_nickname_to_id("loc",$loc_name);

	if ($loc_name eq "\002" && $type ne "")
	{
	# Paying to cash.  Make a new contact with a special name starting with
	# \002 meaning outbound cash.

	my $time = time();
	my $new_loc = unpack("H*",$site->{random}->get);
	my $new_name = "\002$time $new_loc";  # outbound cash

	# Save the new entry.
	# LATER unify with other add contact routine

	my $folder_object = $s->{folder}->{object};
	my $loc_folder = $s->{folder}->{location};

	my $list_loc = $folder_object->get("list_loc");
	my @list_loc = split(" ",$list_loc);
	push @list_loc, $new_loc;

	$list_loc = join(" ",@list_loc);

	$folder_object->put("list_loc",$list_loc);
	$folder_object->put("loc_name.$new_loc", $new_name);

	my $archive = $s->{folder}->{archive};

	$archive->write_object($loc_folder,$folder_object,$loc_folder);

	{
	my $rsp = $archive->{api}->{rsp};
	if ($rsp->get("status") ne "success")
		{
		$out->put("status","fail");
		$out->put("error_move","insufficent_usage");
		}
	}

	$s->{folder}->{object} = $archive->touch_object($loc_folder);

	return if $out->get("status") ne "";

	$op->put("loc",$new_name);
	$loc = $new_loc;
	}

	my $scale = $folder->{object}->get("type_scale.$type");

	my $format = Loom::Qty->new;
	$qty = $format->float_to_int($qty,$scale);

	if ($qty eq "")
		{
		$out->put("status","fail");
		$out->put("error_move","invalid_qty");
		return;
		}

	if ($op->get("take") ne "")
		{
		$qty = "-$qty";
		$qty = "0" if $qty eq "-0";
		}

	my $grid = $folder->{grid};
	my $loc_folder = $folder->{location};

	$grid->move($type,$qty,$loc_folder,$loc);

	my $rsp = $grid->{api}->{rsp};

	if ($rsp->get("status") eq "fail")
		{
		# Move might have failed because one of the locations was vacant
		# (not bought).  Buy the offending location(s) automatically and
		# try the move again.

		my $try_again = 0;

		if ($rsp->get("value_orig") eq "")
			{
			$grid->buy($type,$loc_folder,$loc_folder);

			if ($grid->{api}->{rsp}->get("status") eq "fail")
				{
				# Not enough usage tokens in main stash, so try to buy it
				# with usage tokens at the destination.

				$grid->buy($type,$loc_folder,$loc);
				}

			$try_again = 1;
			}

		if ($rsp->get("value_dest") eq "")
			{
			$grid->buy($type,$loc,$loc_folder);

			if ($grid->{api}->{rsp}->get("status") eq "fail")
				{
				# Not enough usage tokens in main stash, so try to buy it
				# with usage tokens at the destination.

				$grid->buy($type,$loc,$loc);
				}

			$try_again = 1;
			}

		if ($try_again)
			{
			$grid->move($type,$qty,$loc_folder,$loc);
			$rsp = $grid->{api}->{rsp};
			}
		}

	my $status = $rsp->get("status");
	$out->put("status",$status);

	if ($status eq "fail")
		{
		if ($out->get("error_move") eq "")
			{
			my $error_type = $rsp->get("error_type");
			if ($error_type eq "")
				{
				}
			elsif ($error_type eq "not_valid_id")
				{
				$out->put("error_move","Please choose an asset.");
				}
			}

		if ($out->get("error_move") eq "")
			{
			my $error_qty = $rsp->get("error_qty");
			if ($error_qty eq "")
				{
				}
			elsif ($error_qty eq "not_valid_int")
				{
				if ($qty eq "")
					{
					$out->put("error_move","Please enter a quantity.");
					}
				else
					{
					$out->put("error_move","Not a valid quantity");
					}
				}
			elsif ($error_qty eq "insufficient")
				{
				if ($op->get("give") ne "")
					{
					if ($is_negative_qty)
						{
						$out->put("error_move",
						"You cannot take more assets from the contact point "
						."than are actually there.");
						}
					else
						{
						$out->put("error_move",
						"You cannot pay more assets to the contact point "
						."than you actually have.");
						}
					}
				else
					{
					$op->put("qty","");
					$out->put("error_move",
					"Some assets have been taken from the contact point "
					."since you last refreshed your Wallet display.");
					}
				}
			}

		if ($out->get("error_move") eq "")
			{
			my $error_dest = $rsp->get("error_dest");
			if ($error_dest eq "")
				{
				}
			elsif ($error_dest eq "not_valid_id")
				{
				$out->put("error_move","Please choose a contact.");
				}
			}
		}

	if ($status eq "success")
		{
		# LATER we don't use these colors anymore -- red is too alarming.
		my $orig_color = "green";  # green-ish
		my $dest_color = "red";  # red-ish

		if ($op->get("give") ne "")
			{
			# swap colors
			($orig_color,$dest_color) = ($dest_color,$orig_color);
			}

		$out->put("color.$type.$loc_folder",$orig_color);
		$out->put("color.$type.$loc",$dest_color);

		if ($folder->{object}->get("recording"))
			{
			$s->save_history_entry($qty,$type,$loc);
			}

		if ($op->get("give") ne "")
			{
			if (!$is_negative_qty)
				{
				# Clear the qty field to avoid paying again if user presses
				# Enter.
				$op->put("qty","");
				}
			else
				{
				# On a negative Pay, flip the quantity to positive so it's
				# easy to pay it right back out.
				$op->put("qty",substr($op->get("qty"),1));
				}
			}
		}
	}

sub handle_history
	{
	my $s = shift;

	my $folder = $s->{folder};
	my $site = $folder->{site};
	my $op = $site->{op};

	if ($op->get("set_recording") ne "")
	{
	my $set_recording = $op->get("set_recording") ? 1 : "";

	$folder->{object}->put("recording",$set_recording);
	$s->save_folder;

	return;
	}

	my $h_id = $op->get("h_id");
	return if $h_id eq "";

	if ($op->get("delete_history") ne "")
	{
	my $list_H = $folder->{object}->get("list_H");
	my @list_H = split(" ",$list_H);

	my $found = 0;
	my @new_list_H = ();

	for my $item (@list_H)
		{
		if ($item eq $h_id)
			{
			$found = 1;
			next;
			}
		push @new_list_H, $item;
		}

	return if !$found;

	{
	my $loc = $folder->{object}->get("H_loc.$h_id");

	if ($folder->{object}->get("loc_del.$loc"))
		{
		# We're about to delete a history entry which points to a deleted
		# contact.  Now let's check the history to see if this is the *last*
		# entry which refers to that contact.  If so, then we'll go ahead
		# and clear the contact completely.

		my $count = 0;
		for my $this_h_id (@list_H)
			{
			my $this_loc = $folder->{object}->get("H_loc.$this_h_id");
			if ($this_loc eq $loc)
				{
				$count++;
				last if $count > 1;
				}
			}

		if ($count <= 1)
			{
			# Now we can clear the contact because we're about to delete the
			# last history entry which points to it.

			$folder->{object}->put("loc_name.$loc","");
			$folder->{object}->put("loc_del.$loc","");
			}
		}
	}

	{
	my $type = $folder->{object}->get("H_type.$h_id");

	if ($folder->{object}->get("type_del.$type"))
		{
		# We're about to delete a history entry which points to a deleted
		# asset.  Now let's check the history to see if this is the *last*
		# entry which refers to that asset.  If so, then we'll go ahead
		# and clear the asset completely.

		my $count = 0;
		for my $this_h_id (@list_H)
			{
			my $this_type = $folder->{object}->get("H_type.$this_h_id");
			if ($this_type eq $type)
				{
				$count++;
				last if $count > 1;
				}
			}

		if ($count <= 1)
			{
			# Now we can clear the asset because we're about to delete the
			# last history entry which points to it.

			$folder->{object}->put("type_name.$type","");
			$folder->{object}->put("type_scale.$type","");
			$folder->{object}->put("type_min_precision.$type","");
			$folder->{object}->put("type_del.$type","");
			}
		}
	}

	my $new_list_H = join(" ",@new_list_H);

	$folder->{object}->put("list_H",$new_list_H);
	$folder->{object}->put("H_time.$h_id","");
	$folder->{object}->put("H_qty.$h_id","");
	$folder->{object}->put("H_type.$h_id","");
	$folder->{object}->put("H_loc.$h_id","");
	$folder->{object}->put("H_memo.$h_id","");

	$s->save_folder;
	}
	elsif ($op->get("save_history") ne "")
	{
	my $list_H = $folder->{object}->get("list_H");
	my @list_H = split(" ",$list_H);

	my $found = 0;
	for my $item (split(" ",$list_H))
		{
		next if $item ne $h_id;
		$found = 1;
		last;
		}

	$op->put("h_id","");

	return if !$found;

	$folder->{object}->put("H_memo.$h_id",$op->get("memo"));

	$s->save_folder;
	}
	elsif ($op->get("cancel_history") ne "")
	{
	$op->put("h_id","");
	}

	}

sub save_history_entry
	{
	my $s = shift;
	my $qty = shift;
	my $type = shift;
	my $loc = shift;

	my $folder = $s->{folder};
	my $site = $folder->{site};

	my $h_id = $s->new_history_id;

	return if $h_id eq "";

	my $list_H = $folder->{object}->get("list_H");
	$list_H = "$h_id $list_H";

	# Negate the quantity because positive values are in folder's favor.

	if ($qty =~ /^-/)
		{
		$qty = substr($qty,1);
		}
	else
		{
		$qty = "-$qty";
		}

	my $time = time();

	$folder->{object}->put("list_H",$list_H);
	$folder->{object}->put("H_time.$h_id",$time);
	$folder->{object}->put("H_qty.$h_id",$qty);
	$folder->{object}->put("H_type.$h_id",$type);
	$folder->{object}->put("H_loc.$h_id",$loc);

	$s->save_folder;
	}

sub save_folder
	{
	my $s = shift;

	my $folder = $s->{folder};
	my $site = $folder->{site};
	my $loc_folder = $folder->{location};

	my $archive = $folder->{archive};
	$archive->write_object($loc_folder,$folder->{object},$loc_folder);
	$folder->{object} = $archive->touch_object($loc_folder);

	return;
	}

sub new_history_id
	{
	my $s = shift;

	my $folder = $s->{folder};
	my $site = $folder->{site};

	my $max_tries = 200;
	my $num_tries = 0;

	while (1)
		{
		my $h_id = unpack("H*",$site->{random}->get);
		$h_id = substr($h_id,0,8);

		$num_tries++;

		my $time = $folder->{object}->get("H_time.$h_id");
		if ($time ne "")
			{
			return "" if $num_tries >= $max_tries;
			}
		else
			{
			return $h_id;
			}
		}

	return "";
	}

sub help
	{
	my $s = shift;

	my $site = $s->{folder}->{site};
	my $op = $site->{op};

	$site->{printer_friendly} = 1 if $op->get("print");

	$s->{menu} = "help";

	$site->{body} .= <<EOM;
<h1> How the wallet display is organized </h1>
Your wallet display consists of four sections:

<ul>
<li> A dialog box for making payments
<li> The assets in your wallet
<li> Any assets in transit between you and your contacts
<li> Your personal transaction history
</ul>

<h1> Paying an asset to a contact </h1>
<ul>
<li> Enter the quantity into the text box labeled "Quantity".
<li> Choose the asset in the drop-down menu.
<li> Choose the contact in the drop-down menu. 
<li> Press <b>Pay</b>
</ul>
<p>
You will see the asset move out of your wallet and down to the designated
contact point.  The asset will remain at that contact point until the other
party takes them, or you take them back, whichever comes first.

<h1> Taking an asset from a contact </h1>

When a contact pays <em>you</em> something, you will see the assets sitting at
the contact point.  You will need to <em>take</em> the assets away from the
contact point and into your wallet.  Only then do those assets become fully
your property.  If you don't take them, the contact could take them back.

<p>
To take the asset, click the asset name at the contact point.  You will see the
asset move away from the contact point and into your wallet.

<h1> Making a payment in a shopping cart </h1>

We recommend that you create a contact point for each of your favorite
merchants.  When you shop at a merchant's web site and go to the checkout
form, it will tell you the total amount required.  It will also display a
field where you can paste in a Loom <b>ID</b> which has the required amount.

<p>
So, in a separate window, login into your Loom folder and pay the required
amount to that merchant's contact point.  Then, to get the <b>ID</b> number,
click the contact name in the gray bar.  Copy the <b>ID</b> number, using
either Ctrl-C or Right-click/Copy, and then Paste it into the merchant's
web form.  Then press the merchant's Pay button, and the merchant site
will debit the required amount from the <b>ID</b> you pasted in.

<p>
Quite simply, the <b>ID</b> of the merchant contact point acts like a
"debit card" with that particular merchant.  You "fund" the debit card in your
Loom folder, and then copy and paste the debit card number into the merchant's
web form.  It is very much like using a normal debit or credit card in a
traditional shopping cart, except that a Loom <b>ID</b> can be funded with
<em>exactly</em> the amount you intend to pay, and there is no possibility of
overcharging or identity theft like you might have with a credit card.


<h1> Using history </h1>
<p>
You may enable or disable history as you wish.  Note that <em>only you</em>
can see your history records, and you can delete records any time you like.
<p>
If you enable history, the system will record your transactions and display
them in reverse chronological order, with the most recent entries at the top
of the list.  Each transaction record will show the date, time, quantity,
asset, and contact.  When you take an asset for yourself, the quantity will
be positive and colored green.  When you pay an asset to a contact, the
quantity will be negative and colored red.
<p>
If you hover over a date-time stamp in your history, you will notice that it
shows up as a link.  If you click that link, you can add a memo to the
transaction to help you remember what it was about.  You can even add long
multi-line memos, for example you could enter the entire details of an order
including a customer's full shipping address.  Again, <em>only you</em>
can see this memo.  You can edit the memo later if you like, for example to
add a tracking number for shipping.  You can even delete the entire memo by
simply clearing it out.  Later, you can delete the entire transaction from your
history altogether.  This will save space and refund valuable usage tokens
to you!
<p>
If you disable history, the history display is hidden and no records are kept
as you move assets around.  All your old records are still there, but the
system does not display them or add any new records while history is disabled.
You can easily enable history again with a single click.
EOM
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
