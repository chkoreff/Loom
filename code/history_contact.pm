package history_contact;
use strict;
use dttm;
use html;
use loom_config;
use page;
use page_folder;

# Display history.

sub show
	{
	my $curr_loc = shift;
	my $now_recording = page_folder::get("recording");
	return if !$now_recording;

	my $val_list_H = page_folder::get("list_H");
	my $list_H = [ split(" ",$val_list_H) ];

	my $num_items = scalar(@$list_H);

	my $odd_color = loom_config::get("odd_row_color");
	my $even_color = loom_config::get("even_row_color");

	my $table = "";
	$table .= <<EOM;
<table border=0 cellpadding=0 style='border-collapse:collapse;'>
<colgroup>
<col width=150>
<col width=110>
<col width=170>
<col width=170>
</colgroup>
<tr>
<td class=wallet_bold_clean align=left>
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

	my $odd_row = 1;  # for odd-even coloring

	my $min_pos = 0;
	my $max_pos = $num_items - 1;

	my $count = 0; # count matching rows

	for my $pos ($min_pos .. $max_pos)
	{
	my $h_id = $list_H->[$pos];

	my $row_color = $odd_row ? $odd_color : $even_color;
	$odd_row = 1 - $odd_row;

	my $time = page_folder::get("H_time.$h_id");
	my $qty = page_folder::get("H_qty.$h_id");
	my $type = page_folder::get("H_type.$h_id");
	my $loc = page_folder::get("H_loc.$h_id");

	next if $loc ne $curr_loc;
	$count++;

	my $q_loc_name;
	my $q_type_name;

	{
	my $type_name = page_folder::map_id_to_nickname("type",$type);

	if ($type_name eq "")
		{
		$q_type_name = html::quote($type);
		my $scale = page_folder::get("type_scale.$type");
		$q_type_name = qq{<span class=tiny_mono>$q_type_name $scale</span>};
		}
	else
		{
		$q_type_name = html::quote($type_name);

		if (page_folder::get("type_del.$type"))
			{
			# Deleted asset: show the name in italics with ID and scale.
			$q_type_name = qq{<i>$q_type_name</i>};

			my $scale = page_folder::get("type_scale.$type");
			$q_type_name .= qq{<br><span class=tiny_mono>$type $scale</span>};
			}
		}
	}

	{
	my $loc_name = page_folder::map_id_to_nickname("loc",$loc);

	if ($loc_name eq "")
		{
		# Render unnamed contacts as raw hex.
		$q_loc_name = html::quote($loc);
		$q_loc_name = qq{<span class=tiny_mono>$q_loc_name</span>};
		}
	else
		{
		$q_loc_name = html::quote($loc_name);

		if (page_folder::get("loc_del.$loc"))
			{
			# Deleted contact: show the name in italics with ID.
			$q_loc_name = qq{<i>$q_loc_name</i>};
			$q_loc_name .= qq{<br><span class=tiny_mono>$loc</span>};
			}
		}
	}

	my $dttm = dttm::as_gmt($time);

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

	my $dsp_qty = $sign.page_folder::display_value($abs_qty,$type);

	{
	my $color = $sign eq "+" ? "green" : "red";
	$dsp_qty = qq{<span style='color:$color'>$dsp_qty</span>};
	}

	$table .= <<EOM;
<tr valign=middle style='background-color:$row_color; height:28px;'>
<td align=left>
$dttm
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

	{
	my $memo = page_folder::get("H_memo.$h_id");

	if ($memo ne "")
	{
	my $q_memo = html::semiquote($memo);
	$q_memo =~ s/\n/<br>/g;

	# We use the "overflow" style attribute on the memo to prevent very wide
	# non-breakable memos from messing up the table appearance.

	$table .= <<EOM;
<tr style='background-color:$row_color; height:28px;'>
<td colspan=4>
<div style='overflow: auto; font-size:10pt; display:block; margin-top: 0px; margin-left:20px; margin-bottom:2px'>
$q_memo
</div>
</td>
</tr>
EOM
	}

	}

	}

	$table .= <<EOM;
</table>
EOM

	if ($count > 0)
		{
		page::emit($table);
		}
	return;
	}

return 1;
