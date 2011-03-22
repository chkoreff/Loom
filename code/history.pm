use strict;

# Establish scroll position based on id h_pi and row number h_pn.

sub normalize_scroll_position
	{
	my $list = shift; # list of history ids

	{
	my $key = "h_pi";
	my $val = http_get($key);
	unless ($val =~ /^([a-f0-9]{8})$/ && length($1) == length($val))
		{
		http_put($key,"");
		}
	}

	{
	my $key = "h_pn";
	my $val = http_get($key);
	unless ($val =~ /^([0-9]{1,8})$/ && length($1) == length($val))
		{
		http_put($key,"");
		}
	}

	{
	my $key = "h_pi";
	my $val = http_get($key);

	if ($val ne "")
		{
		my $time = folder_get("H_time.$val");
		if ($time eq "")
			{
			http_put($key,"");
			}
		}
	}

	{
	my $h_pi = http_get("h_pi");

	if ($h_pi ne "")
		{
		my $pos = 0;
		for my $h_id (@$list)
			{
			last if $h_id eq $h_pi;
			$pos++;
			}

		my $num_items = scalar(@$list);

		if ($pos < $num_items)
			{
			http_put("h_pn",$num_items - $pos);
			}
		else
			{
			http_put("h_pi","");
			}
		}
	}

	{
	my $h_pn = http_get("h_pn");

	if ($h_pn ne "")
		{
		my $num_items = scalar(@$list);

		if ($h_pn < 1)
			{
			http_put("h_pn","");
			}
		elsif ($h_pn > $num_items)
			{
			http_put("h_pn",$num_items);
			}
		}
	}

	{
	my $h_pi = http_get("h_pi");
	my $h_pn = http_get("h_pn");

	if ($h_pi eq "" && $h_pn ne "")
		{
		my $num_items = scalar(@$list);
		$h_pi = $list->[$num_items - $h_pn];
		http_put("h_pi",$h_pi);
		}
	}

	return;
	}

# Display history.

sub show_history
	{
	my $odd_color = loom_config("odd_row_color");
	my $even_color = loom_config("even_row_color");

	my $now_recording = folder_get("recording");
	my $table = "";

	$table .= <<EOM;
<table border=0 cellpadding=0 style='border-collapse:collapse;'>
<colgroup>
<col width=50>
<col width=140>
<col width=110>
<col width=175>
<col width=175>
</colgroup>

EOM

	if ($now_recording)
	{
	my $history_control = "";

	# Establish history control links.
	{
	my @params = http_slice(qw(function h_pi h_pn session));

	if (http_get("h_only"))
		{
		my $url = top_url(@params);

		$history_control .=
		qq{<a href="$url" title="Show wallet also.">Show wallet also</a>};
		}
	else
		{

		{
		my $url = top_url(@params, "h_only",1);

		$history_control .=
		qq{<a href="$url" title="Show history only">Show history only</a>};
		}

		{
		my $url = top_url(
			"function",http_get("function"),
			"set_recording",0,
			http_slice(qw(qty type loc)),
			"session",http_get("session"),
			);

		$history_control .=
		qq{<a href="$url" style='padding-left:15px' }
		.qq{title="Disable transaction history">Disable history</a>};
		}

		}
	}

	my $val_list_H = folder_get("list_H");
	my $list_H = [ split(" ",$val_list_H) ];

	normalize_scroll_position($list_H);

	my $num_items = scalar(@$list_H);

	# Establish first absolute row number to display.
	my $h_pn = http_get("h_pn");
	$h_pn = $num_items if $h_pn eq "";

	my $rows_per_page = 20;  # LATER configurable

	my $max_row = $h_pn;
	my $min_row = $max_row - $rows_per_page + 1;
	$min_row = 1 if $min_row < 1;

	# Establish links for scrolling through history.

	my @scroll_links = ();

	{
	my @params = http_slice(qw(function h_only session));

	# Newest
	{
	my $title = "Newest";
	my $label = "|&lt;";

	my $attr = "";
	$attr = " style='color:gray'" if $max_row == $num_items;

	my $context = op_new(@params);

	my $url = top_url(op_pairs($context));
	my $link = qq{<a$attr href="$url" title="$title">$label</a>};

	push @scroll_links, $link;
	}

	# Newer
	{
	my $title = "Newer";
	my $label = "&lt;newer";

	my $attr = "";
	$attr = " style='color:gray'" if $max_row == $num_items;

	my $row_no = $max_row + $rows_per_page;
	$row_no = $num_items if $row_no > $num_items;
	my $h_id = $list_H->[$num_items-$row_no];

	my $context = op_new(@params,
		"h_pi",$h_id, "h_pn",$row_no);

	my $url = top_url(op_pairs($context));
	my $link = qq{<a$attr href="$url" title="$title">$label</a>};

	push @scroll_links, $link;
	}

	# Older
	{
	my $title = "Older";
	my $label = "older&gt;";

	my $attr = "";
	$attr = " style='color:gray'" if $min_row == 1;

	my $row_no = $min_row - 1;
	$row_no = $rows_per_page if $row_no < $rows_per_page;
	$row_no = 1 if $row_no < 1;
	my $h_id = $list_H->[$num_items-$row_no];

	my $context = op_new(@params,
		"h_pi",$h_id, "h_pn",$row_no);

	my $url = top_url(op_pairs($context));
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

	my $context = op_new(@params, "h_pn",$rows_per_page);

	my $url = top_url(op_pairs($context));
	my $link = qq{<a$attr href="$url" title="$title">$label</a>};

	push @scroll_links, $link;
	}
	}

	my $scroll_panel = <<EOM;
<table border=0 style='border-collapse:collapse'>
<colgroup>
<col width=23>
<col width=59>
<col width=54>
<col width=23>
</colgroup>
<tr>
<td class=wallet_small_clean align=left> $scroll_links[0] </td>
<td class=wallet_small_clean align=left> $scroll_links[1] </td>
<td class=wallet_small_clean align=right> $scroll_links[2] </td>
<td class=wallet_small_clean align=right> $scroll_links[3] </td>
</tr>
</table>
EOM

	if (http_get("edit_history_items") eq "")
	{
	$table .= <<EOM;
<tr>
<td class=wallet_bold_clean align=right>
<input class=smaller type=submit name=edit_history_items value="Edit">
</td>
<td class=wallet_bold_clean align=right>
History
</td>
<td colspan=2 align=left class=wallet_small_clean>
$history_control
</td>
<td class=wallet_small_clean align=right>
$scroll_panel
</td>
</tr>

EOM
	}
	else
	{
	$table .= <<EOM;
<tr>
<td class=wallet_small_clean>
<input class=smaller type=submit name=edit_history_items value="Edit">
</td>
<td class=wallet_small_clean>
<input class=small type=submit name=save_history_items value="Save Changes">
</td>
<td align=left class=wallet_small_clean>
<input class=small type=submit name=cancel_history_items value="Cancel">
</td>
<td align=left class=wallet_small_clean>
</td>
<td class=wallet_small_clean align=right>
<input class=small type=submit name=delete_history_items value="Delete Chosen Items Now!">
</td>
</tr>

EOM
	}

	$table .= <<EOM;
<tr>
<td class=wallet_small_clean align=right>
<span style='color:green'>choices:</span>
</td>
<td class=wallet_bold_clean align=right>
Time (UTC)
</td>
<td class=wallet_bold_clean align=right>
<span style='margin-right:11px'>Quantity</span>
</td>
<td class=wallet_bold_clean align=left>
<span style='margin-right:14px'>Asset</span>
</td>
<td class=wallet_bold_clean align=left>
<span style='margin-right:8px'>Contact</span>
</td>
</tr>

EOM

	my $first_memo = "";  # track where to set focus
	my $odd_row = 1;  # for odd-even coloring

	my $min_pos = $num_items - $max_row;
	my $max_pos = $num_items - $min_row;

	for my $pos ($min_pos .. $max_pos)
	{
	my $h_id = $list_H->[$pos];

	my $row_color = $odd_row ? $odd_color : $even_color;
	$odd_row = 1 - $odd_row;

	my $time = folder_get("H_time.$h_id");
	my $qty = folder_get("H_qty.$h_id");
	my $type = folder_get("H_type.$h_id");
	my $loc = folder_get("H_loc.$h_id");

	my $q_loc_name;
	my $q_type_name;

	{
	my $type_name = map_id_to_nickname("type",$type);

	if ($type_name eq "")
		{
		$q_type_name = html_quote($type);
		my $scale = folder_get("type_scale.$type");
		$q_type_name = qq{<span class=tiny_mono>$q_type_name $scale</span>};
		}
	else
		{
		$q_type_name = html_quote($type_name);

		if (folder_get("type_del.$type"))
			{
			# Deleted asset: show the name in italics with ID and scale.
			$q_type_name = qq{<i>$q_type_name</i>};

			my $scale = folder_get("type_scale.$type");
			$q_type_name .= qq{<br><span class=tiny_mono>$type $scale</span>};
			}
		}
	}

	{
	my $loc_name = map_id_to_nickname("loc",$loc);

	if ($loc_name eq "")
		{
		# Render unnamed contacts as raw hex.
		$q_loc_name = html_quote($loc);
		$q_loc_name = qq{<span class=tiny_mono>$q_loc_name</span>};
		}
	else
		{
		$q_loc_name = html_quote($loc_name);

		if (folder_get("loc_del.$loc"))
			{
			# Deleted contact: show the name in italics with ID.
			$q_loc_name = qq{<i>$q_loc_name</i>};
			$q_loc_name .= qq{<br><span class=tiny_mono>$loc</span>};
			}
		}
	}

	# LATER Search on Asset, Contact, and Time.

	# Here we build the link that lets you bring a history entry to the top
	# of the display.

	my $dttm = dttm_as_gmt($time);

	my $row_context = op_new(
		http_slice(qw(function h_pi h_pn h_only session)));
	op_put($row_context,"h_pi",$h_id);

	my $url = top_url(op_pairs($row_context));
	my $q_dttm =
		qq{<a href="$url" title="Show this entry at the top.">$dttm</a>};

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

	my $dsp_qty = $sign.display_value($abs_qty,$type);

	{
	my $color = $sign eq "+" ? "green" : "red";
	$dsp_qty = qq{<span style='color:$color'>$dsp_qty</span>};
	}

	my $is_checked = http_get("choose_$h_id") ne "" ? 1 : 0;
	my $q_checked = $is_checked ? " checked" : "";

	$table .= <<EOM;
<tr valign=middle style='background-color:$row_color; height:28px;'>
<td align=right>
<input$q_checked type=checkbox name=choose_$h_id>
</td>
<td align=right>
$q_dttm
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

	if ($is_checked && http_get("edit_history_items") ne "")
	{
	$first_memo = $h_id if $first_memo eq "";
		# Set focus to first open memo.

	my $memo = folder_get("H_memo.$h_id");
	my $q_memo = html_semiquote($memo);

	my @lines = split("\n",$memo);
	my $num_lines = scalar(@lines);

	my $num_rows = $num_lines;
	$num_rows = 1 if $num_rows < 1;
	$num_rows = 20 if $num_rows > 20;

	$table .= <<EOM;
<tr style='background-color:$row_color'>
<td></td>
<td colspan=4>
<textarea name=memo_$h_id rows=$num_rows cols=80>
$q_memo</textarea>
</td>
</tr>
EOM
	}
	else
	{

	my $memo = folder_get("H_memo.$h_id");

	if ($memo ne "")
	{
	my $q_memo = html_semiquote($memo);
	$q_memo =~ s/\n/<br>/g;

	# We use the "overflow" style attribute on the memo to prevent very wide
	# non-breakable memos from messing up the table appearance.

	$table .= <<EOM;
<tr style='background-color:$row_color; height:28px;'>
<td></td>
<td colspan=4>
<div style='overflow: auto; font-size:10pt; display:block; margin-top: 0px; margin-bottom:2px'>
$q_memo
</div>
</td>
</tr>
EOM
	}

	}

	}

	if ($first_memo ne "")
		{
		set_focus("memo_$first_memo");
		}

	}
	else
	{
	my $url = top_url(
		"function",http_get("function"),
		"set_recording",1,
		http_slice(qw(qty type loc)),
		"session",http_get("session"),
		);

	my $link_enable =
	qq{<a href="$url" title="Enable history">}
	.qq{Enable history</a>};

	$table .= <<EOM;
<tr>
<td class=wallet_small_clean>
</td>
<td class=wallet_bold_clean align=right>
History
</td>
<td class=wallet_small_clean>
$link_enable
</td>
<td class=wallet_small_clean>
</td>
<td class=wallet_small_clean align=right>
</td>
</tr>

EOM
	}

	$table .= <<EOM;
</table>
EOM

	emit(<<EOM
$table
EOM
);

	return;
	}

sub new_history_id
	{
	my $max_tries = 200;
	my $num_tries = 0;

	while (1)
		{
		my $h_id = unpack("H*",random_id());
		$h_id = substr($h_id,0,8);

		$num_tries++;

		my $time = folder_get("H_time.$h_id");
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

sub add_history_entry
	{
	my $qty = shift;
	my $type = shift;
	my $loc = shift;

	my $h_id = new_history_id();

	return if $h_id eq "";

	my $list_H = folder_get("list_H");
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

	folder_put("list_H",$list_H);
	folder_put("H_time.$h_id",$time);
	folder_put("H_qty.$h_id",$qty);
	folder_put("H_type.$h_id",$type);
	folder_put("H_loc.$h_id",$loc);

	return;
	}

sub save_history_item
	{
	my $h_id = shift;
	my $memo = shift;

	my $time = folder_get("H_time.$h_id");
	return 0 if $time eq "";

	$memo =~ s/\015//g;

	folder_put("H_memo.$h_id",$memo);

	return 1;
	}

sub delete_history_item
	{
	my $h_id = shift;

	my $list_H = folder_get("list_H");
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

	return 0 if !$found;

	{
	my $loc = folder_get("H_loc.$h_id");

	if (folder_get("loc_del.$loc"))
		{
		# We're about to delete a history entry which points to a deleted
		# contact.  Now let's check the history to see if this is the *last*
		# entry which refers to that contact.  If so, then we'll go ahead
		# and clear the contact completely.

		my $count = 0;
		for my $this_h_id (@list_H)
			{
			my $this_loc = folder_get("H_loc.$this_h_id");
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

			folder_put("loc_name.$loc","");
			folder_put("loc_del.$loc","");
			}
		}
	}

	{
	my $type = folder_get("H_type.$h_id");

	if (folder_get("type_del.$type"))
		{
		# We're about to delete a history entry which points to a deleted
		# asset.  Now let's check the history to see if this is the *last*
		# entry which refers to that asset.  If so, then we'll go ahead
		# and clear the asset completely.

		my $count = 0;
		for my $this_h_id (@list_H)
			{
			my $this_type = folder_get("H_type.$this_h_id");
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

			folder_put("type_name.$type","");
			folder_put("type_scale.$type","");
			folder_put("type_min_precision.$type","");
			folder_put("type_del.$type","");
			}
		}
	}

	my $new_list_H = join(" ",@new_list_H);

	folder_put("list_H",$new_list_H);
	folder_put("H_time.$h_id","");
	folder_put("H_qty.$h_id","");
	folder_put("H_type.$h_id","");
	folder_put("H_loc.$h_id","");
	folder_put("H_memo.$h_id","");

	return 1;
	}

return 1;
