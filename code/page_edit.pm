use strict;

# LATER it's somewhat annoying that when you press Enter, the Random Passphrase
# button is selected because it's first on the page.  Perhaps the accesskey
# attribute can be used to make Create Folder the default button.  (I know
# tabindex doesn't work.)  But how does one specify "Enter" for an accesskey?

# LATER a way to edit the content headers on uploaded document?

# LATER
# One way to support extremely large files from the *user's* perspective is to
# chunk them internally in the archive, but feed them out to the user in a
# streaming manner when the user asks for a single large logical file.  The
# upload is a little different, because it demands a streaming handling of the
# HTTP post with no max post size imposed.  This would have to be done in a
# higher-level API/interface though, because it is a layer of abstraction on
# top of the raw archive.

sub full_uploaded_content
	{
	my $filename = shift;
	my $uploaded_content = shift;

	# Don't override any existing content headers in the uploaded data.

	my ($header_op,$header_text,$content) = split_content($uploaded_content);

	my $inferred_header = "";

	if ($header_text eq "" && $filename ne "")
		{
		# Did not find any content headers, so infer the content
		# type from the suffix of the uploaded file name.

		my ($suffix) = ($filename =~ /.*\.(.*)$/);
		$suffix = "" if !defined $suffix;
		$suffix = lc($suffix);

		my $content_type =
			(
			$suffix eq "jpg" ? "image/jpg" :
			$suffix eq "jpeg" ? "image/jpg" :
			$suffix eq "gif" ? "image/gif" :
			$suffix eq "png" ? "image/png" :
			$suffix eq "ico" ? "image/png" :
			$suffix eq "pdf" ? "application/pdf" :
			$suffix eq "txt" ? "text/plain" :
			$suffix eq "xls" ? "xls" :
			$suffix eq "doc" ? "doc" :
			$suffix eq "htm" ? "text/html" :
			$suffix eq "html" ? "text/html" :
			""
			);

		if ($content_type ne "")
			{
			$inferred_header = "Content-Type: $content_type\n\n"
			}
		}

	my $full_content = $inferred_header . $uploaded_content;

	return $full_content;
	}

sub page_edit_respond
	{
	set_title("Edit Content");

	my $q = {};   # for page rendering

	my $api = op_new();
	op_put($api,"function","archive");

	set_focus("content");

	# If usage not specified, use location by default.
	{
	my $usage = http_get("usage");
	if ($usage eq "")
		{
		my $loc = http_get("loc");
		if (valid_id($loc))
			{
			http_put("usage",$loc);
			}
		}
	}

	my $function = http_get("function");

	if (http_get("random"))
		{
		my $loc = archive_random_vacant_location();
		http_put("loc",$loc);
		}

	if (http_get("buy") ne "")
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
	elsif (http_get("delete") ne "")
		{
		if (http_get("confirm_delete") ne "")
			{
			http_put("content","");
			op_put($api,"action","write");
			}
		}
	else
		{
		if ($function eq "edit" && http_get("write") ne "")
			{
			my $content = http_get("content");
			$content =~ s/\015//g;
			http_put("content",$content);

			op_put($api,"action","write");
			}
		elsif ($function eq "upload" && http_get("upload") ne "")
			{
			my $filename = http_get("filename");
			my $uploaded_content = http_upload("filename");
			my $full_content = full_uploaded_content($filename,
				$uploaded_content);

			# Watch out for user just pressing the Upload button without
			# selecting a file.  We don't want to write null string to the
			# archive in that case.  But we are careful to *allow* writing
			# null string, for example if the users deliberately uploads a
			# null file with no suffix.

			if ($full_content eq "" && $filename eq "")
				{
				# User pressed Upload without choosing a file.  Do nothing.
				}
			else
				{
				http_put("content",$full_content);
				op_put($api,"action","write");
				}
			}
		}

	if (op_get($api,"action") eq "write")
		{
		op_put($api,"usage",http_get("usage"));
		op_put($api,"loc",http_get("loc"));
		op_put($api,"content",http_get("content"));
		op_put($api,"guard",http_get("guard"));
		}
	elsif (op_get($api,"action") eq "")
		{
		op_put($api,"action","touch");
		op_put($api,"loc",http_get("loc"));
		}

	api_respond($api);

	http_put("hash",op_get($api,"hash"));

	my $usage_balance = "";
	my $operation_cost = op_get($api,"cost");

	my $enable_buy = 0;
	my $enable_sell = 0;

	{
	my $status = op_get($api,"status");

	if ($status eq "fail")
		{
		my $error_loc = op_get($api,"error_loc");
		if ($error_loc ne "" && $error_loc ne "vacant"
			&& $error_loc ne "occupied")
			{
			http_put("change_loc", 1);
			}

		my $error_usage = op_get($api,"error_usage");
		if ($error_usage ne "")
			{
			http_put("change_usage", 1);
			}
		}

	my $action = op_get($api,"action");

	if ($action eq "touch")
		{
		my $content = op_get($api,"content");
		http_put("content",$content);
		if ($status eq "fail")
			{
			my $error_loc = op_get($api,"error_loc");
			$enable_buy = 1 if $error_loc eq "vacant";
			}

		if ($status eq "success")
			{
			$enable_sell = 1 if $content eq "";
			}
		}
	elsif ($action eq "buy")
		{
		if ($status eq "fail")
			{
			my $error_loc = op_get($api,"error_loc");
			my $error_usage = op_get($api,"error_usage");

			$enable_buy = 1 if $error_loc eq "not_valid_id";
			$enable_buy = 1 if $error_usage ne "";
			}

		if ($status eq "success")
			{
			$enable_sell = 1;
			}
		}
	elsif ($action eq "sell")
		{
		if ($status eq "fail")
			{
			my $error_loc = op_get($api,"error_loc");
			$enable_sell = 1 if $error_loc ne "vacant";
			$enable_buy = 1 if $error_loc eq "vacant";
			}

		if ($status eq "success")
			{
			$enable_buy = 1;
			}
		}
	elsif ($action eq "write")
		{
		if ($status eq "fail")
			{
			my $error_loc = op_get($api,"error_loc");
			$enable_buy = 1 if $error_loc eq "vacant";
			}

		if ($status eq "success")
			{
			my $content = http_get("content");
			if ($content eq "")
				{
				$enable_sell = 1;
				}
			}
		}
	}

	# LATER make a function to return type_zero
	$usage_balance = grid_touch("0"x32,http_get("usage"));

	for my $field (qw(usage loc))
		{
		$q->{$field} = html_quote(http_get($field));
		}

	{
	my $entered_content = http_get("content");

	my @lines = split("\n",$entered_content);

	my $num_lines = scalar(@lines);

	my $num_rows = $num_lines;
	$num_rows = 20 if $num_rows < 20;
	$num_rows = 50 if $num_rows > 50;

	$q->{content} = html_quote($entered_content);
	$q->{num_content_rows} = $num_rows;
	}

	my $input_size_id = 32 + 4;

	{
	my $context = op_new(http_slice(qw(function)));
	if (!http_get("change_usage"))
		{
		op_put($context,"usage",http_get("usage"));
		}

	if (!http_get("change_loc"))
		{
		op_put($context,"loc",http_get("loc"));
		}

	# I need this flag to detect if a button was pressed, because query
	# parameters such as "change_loc" can stay around in the URL.

	op_put($context,"pressed_button",1);

	# LATER I have noticed a diff between upload and edit on certain files.

	my $hidden = html_hidden_fields(op_pairs($context));

	emit(<<EOM
<form method=post action="" autocomplete=off enctype="multipart/form-data">
$hidden

EOM
);
	}

	my $dsp_status = "";

	{
	my $action = op_get($api,"action");
	my $status = op_get($api,"status");
	my $color = $status eq "success" ? "green" : "red";

	my $msg = $status;

	if ($status eq "success")
		{
		if ($action eq "touch")
			{
			$msg = "";
			}
		}

	if ($status eq "fail")
		{
		my $error_loc = op_get($api,"error_loc");
		my $error_usage = op_get($api,"error_usage");
		my $error_guard = op_get($api,"error_guard");

		if ($error_loc eq "not_valid_id")
			{
			if (op_get($api,"loc") eq "")
				{
				$msg = "Please enter location";
				}
			else
				{
				$msg = "Invalid location";
				}
			}

		if ($error_usage eq "insufficient")
			{
			$msg = "Insufficient usage tokens";
			}

		if ($error_guard eq "changed")
			{
			$msg = "The content changed since you looked at it.";
			if ($function eq "upload")
				{
				# LATER test a refresh after uploading.  I would think this
				# should work without a warning.  After all, you have just
				# uploaded the document, and then pressed Refresh, so why
				# should it think "the document has changed?"

				$msg .= "  Click Upload to re-load this page and start again.";
				}
			else
				{
				$msg .=
				"  To resolve the conflict, right-click Edit to open"
				." a new window, and integrate your work here into"
				." that window."
				;
				}
			}

		if ($action eq "touch")
			{
			if ($error_loc eq "vacant")
				{
				$msg = "Vacant location";
				}
			}
		elsif ($action eq "buy")
			{
			if ($error_loc eq "occupied")
				{
				$msg = "Already bought this location";
				}
			}
		elsif ($action eq "sell")
			{
			if ($error_loc eq "vacant")
				{
				$msg = "Already sold this location";
				}
			elsif ($error_loc eq "not_empty")
				{
				$msg = "Cannot sell non-empty location";
				}
			}
		}

	$dsp_status = "<span style='color:$color'>$msg</span>";
	}

	# Now take a look at the Content-Type to see if we should enable editing
	# in a text box.

	my ($header_op,$header_text,$payload) =
		split_content(http_get("content"));

	my $content_type = op_get($header_op,"Content-Type");
	$content_type = op_get($header_op,"Content-type")
		if $content_type eq "";

	my $len_content = length(http_get("content"));
	my $guard = unpack("H*",sha256(http_get("content")));

	{
	my $link_edit = highlight_link(
		top_url("function","edit", http_slice(qw(loc usage))),
		"Edit", ($function eq "edit"), "Edit web page",
		);

	my $link_upload = highlight_link(
		top_url("function","upload", http_slice(qw(loc usage))),
		"Upload", ($function eq "upload"), "Upload document",
		);

	my $link_view;
	{
	# LATER probably need to make a simple ultra-reliable path-quotation thing.
	my $q_hash = html_quote(http_get("hash"));
	my $url = "/view/$q_hash";

	$link_view = highlight_link(
		$url,
		"View", 0, "View as web page",
		);
	}

	my $link_object;
	{
	# LATER probably need to make a simple ultra-reliable path-quotation thing.
	my $q_hash = html_quote(http_get("hash"));
	my $url = "/object/$q_hash";

	$link_object = highlight_link(
		$url,
		"Object", 0, "View as a rendered object",
		);
	}

	my $link_change_loc = highlight_link(
		top_url("function",$function,
			"change_loc",1,
			http_slice(qw(loc usage))),
		"Location", 0, "Change editing location",
		);

	my $link_change_usage = highlight_link(
		top_url("function",$function,
			"change_usage",1,
			http_slice(qw(loc usage))),
		"Usage", 0, "Change usage location",
		);

	# LATER smooth out Edit/Upload/Delete distinctions.
	# I think instead of doing it based on content type you can do it
	# based on current $function -- but what about switching between
	# Edit and Upload capability?  Perhaps user should just Delete the
	# document in that case and start fresh.  For now I just added the
	# clause || $function eq "edit" so I can see an edit link on types
	# like loom/folder etc.

	top_link(highlight_link(top_url(),"Home"));
	top_link(highlight_link(top_url("help",1),"Advanced"));
	top_link("");

	my $enable_edit = 0;

	if ($content_type eq "" || $content_type eq "text/plain"
		|| $content_type eq "text/html" || $function eq "edit")
		{
		$enable_edit = 1;
		}

	top_link($link_edit) if $enable_edit;
	top_link($link_upload);
	top_link($link_view);
	top_link($link_object);
	top_link($link_change_loc);
	top_link($link_change_usage);
	}

	my $archive_table = "";
	$archive_table .= <<EOM;
<table border=0 style='border-collapse:collapse'>
<colgroup>
<col width=160>
<col width=295>
<col width=65>
<col width=65>
<col width=65>
</colgroup>

EOM

	if (http_get("change_loc") && !http_get("pressed_button"))
	{
	set_focus("loc");

	$archive_table .= <<EOM;
<tr>
<td>
Change Location:
</td>
<td colspan=4>
<input type=text class=mono name=loc size=$input_size_id value="$q->{loc}">
<input type=submit class=small name=go value="Go">
<input type=submit class=small name=random value="Random">
</td>
</tr>

EOM
	}

	if (http_get("change_usage") && !http_get("pressed_button"))
	{
	set_focus("usage");

	$archive_table .= <<EOM;
<tr>
<td>
Change Usage:
</td>
<td colspan=4>
<input type=text class=mono name=usage size=$input_size_id value="$q->{usage}">
<input type=submit class=small name=go value="Go">
</td>
</tr>
EOM
	}

	if (!$enable_buy && $function eq "upload")
	{
	$archive_table .= <<EOM;

<tr>
<td>
Choose document:
</td>
<td colspan=4>
<input type=file class=small size=40 name=filename>
<input type=submit class=small name=upload value="Upload">
<input type=hidden class=small name=guard value="$guard">
</td>
</tr>
EOM

	}

	$archive_table .= <<EOM;
<tr>
<td>
EOM

	if (!$enable_buy && $function eq "edit")
	{
	$archive_table .= <<EOM;
<input type=submit class=small name=write value="Write">
EOM
	}

	if ($enable_buy)
	{
	$archive_table .= <<EOM;
<input type=submit class=small name=buy value="Buy">
EOM
	}

	if ($enable_sell)
	{
	$archive_table .= <<EOM;
<input type=submit class=small name=sell value="Sell">
EOM
	}
	elsif ($function eq "upload" && !$enable_buy)
	{
	$archive_table .= <<EOM;
<input type=submit class=small name=delete value="Delete">
<span class=small> Confirm: </span>
<input type=checkbox name=confirm_delete>
EOM
	}

	my $dsp_cost = "";
	$dsp_cost = $operation_cost eq "" ? "" : "cost $operation_cost";

	my $dsp_usage = "";
	$dsp_usage = $usage_balance eq "" ? "no usage" : "usage $usage_balance";

	$archive_table .= <<EOM;
</td>
<td>
$dsp_status
</td>
<td class=small align=right>
$dsp_cost
</td>
<td class=small align=right>
$dsp_usage
</td>
<td class=small align=right>
size $len_content
</td>
</tr>
EOM

	if (!$enable_buy && $function eq "edit")
	{
	$archive_table .= <<EOM;

<tr>
<td colspan=5>
<input type=hidden name=guard value="$guard">
<textarea name=content class=small rows=$q->{num_content_rows} cols=80>
$q->{content}</textarea>
</td>
</tr>
EOM
	}

	$archive_table .= <<EOM;

</table>
EOM

	emit(<<EOM
$archive_table

</form>
EOM
);

	return;
	}

return 1;
