package Loom::Site::Loom::Page_Edit;
use strict;
use Loom::Context;
use Loom::Digest::SHA256;
use Loom::Site::Loom::EZ_Archive;
use Loom::Site::Loom::EZ_Grid;

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

sub new
	{
	my $class = shift;
	my $site = shift;

	my $s = bless({},$class);
	$s->{site} = $site;
	$s->{id} = $site->{id};
	$s->{html} = $site->{html};
	$s->{hasher} = Loom::Digest::SHA256->new;
	return $s;
	}

sub respond
	{
	my $s = shift;

	my $site = $s->{site};
	my $op = $site->{op};

	if ($op->get("help"))
		{
		$site->object("Loom::Site::Loom::Page_Help",$site,"index")->respond;
		return;
		}

	$site->set_title("Edit Content");

	my $q = {};   # for page rendering

	my $api = Loom::Context->new;
	$api->put(function => "archive");

	$site->set_focus("content");

	# If usage not specified, use location by default.
	{
	my $usage = $op->get("usage");
	if ($usage eq "")
		{
		my $loc = $op->get("loc");
		if ($s->{id}->valid_id($loc))
			{
			$op->put("usage",$loc);
			}
		}
	}

	my $function = $op->get("function");

	if ($op->get("random"))
		{
		my $archive = Loom::Site::Loom::EZ_Archive->new($site->{loom});
		my $loc = $archive->random_vacant_location;
		$op->put("loc",$loc);
		}

	if ($op->get("buy") ne "")
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
	elsif ($op->get("delete") ne "")
		{
		if ($op->get("confirm_delete") ne "")
			{
			$op->put("content","");
			$api->put(action => "write");
			}
		}
	else
		{
		if ($function eq "edit" && $op->get("write") ne "")
			{
			$api->put(action => "write");
			}
		elsif ($function eq "upload" && $op->get("upload") ne "")
			{
			my $filename = $op->get("filename");
			my $uploaded_content = $site->{http}->{upload}->get($filename);

			my $full_content = $s->full_uploaded_content($filename,
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
				$op->put("content" => $full_content);
				$api->put(action => "write");
				}
			}
		}

	if ($api->get("action") eq "write")
		{
		$api->put(usage => $op->get("usage"));
		$api->put(loc => $op->get("loc"));
		$api->put(content => $op->get("content"));
		$api->put(guard => $op->get("guard"));
		}
	elsif ($api->get("action") eq "")
		{
		$api->put(action => "touch");
		$api->put(loc => $op->get("loc"));
		}

	$site->{loom}->run_op($api);

	$op->put("hash",$api->get("hash"));

	my $usage_balance = "";
	my $operation_cost = $api->get("cost");

	my $enable_buy = 0;
	my $enable_sell = 0;

	{
	my $status = $api->get("status");

	if ($status eq "fail")
		{
		my $error_loc = $api->get("error_loc");
		if ($error_loc ne "" && $error_loc ne "vacant"
			&& $error_loc ne "occupied")
			{
			$op->put("change_loc", 1);
			}

		my $error_usage = $api->get("error_usage");
		if ($error_usage ne "")
			{
			$op->put("change_usage", 1);
			}
		}

	my $action = $api->get("action");

	if ($action eq "touch")
		{
		my $content = $api->get("content");
		$op->put("content",$content);
		if ($status eq "fail")
			{
			my $error_loc = $api->get("error_loc");
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
			my $error_loc = $api->get("error_loc");
			my $error_usage = $api->get("error_usage");

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
			my $error_loc = $api->get("error_loc");
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
			my $error_loc = $api->get("error_loc");
			$enable_buy = 1 if $error_loc eq "vacant";
			}

		if ($status eq "success")
			{
			my $content = $op->get("content");
			if ($content eq "")
				{
				$enable_sell = 1;
				}
			}
		}
	}

	{
	my $grid = Loom::Site::Loom::EZ_Grid->new($site->{loom});
	$usage_balance = $grid->touch("0"x32, $op->get("usage"));
	}

	for my $field (qw(usage loc))
		{
		$q->{$field} = $s->{html}->quote($op->get($field));
		}

	{
	my $entered_content = $op->get("content");

	my @lines = split("\n",$entered_content);

	my $num_lines = scalar(@lines);

	my $num_rows = $num_lines;
	$num_rows = 20 if $num_rows < 20;
	$num_rows = 50 if $num_rows > 50;

	$q->{content} = $s->{html}->quote($entered_content);
	$q->{num_content_rows} = $num_rows;
	}

	my $input_size_id = 32 + 4;

	{
	my $context = Loom::Context->new($op->slice(qw(function)));
	if (!$op->get("change_usage"))
		{
		$context->put("usage",$op->get("usage"));
		}
	if (!$op->get("change_loc"))
		{
		$context->put("loc",$op->get("loc"));
		}

	# LATER I have noticed a diff between upload and edit on certain files.

	my $hidden = $s->{html}->hidden_fields($context->pairs);

	$site->{body} .= <<EOM;
<form method=post action="" autocomplete=off enctype="multipart/form-data">
$hidden

EOM
	}

	my $dsp_status = "";

	{
	my $action = $api->get("action");
	my $status = $api->get("status");
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
		my $error_loc = $api->get("error_loc");
		my $error_usage = $api->get("error_usage");
		my $error_guard = $api->get("error_guard");

		if ($error_loc eq "not_valid_id")
			{
			if ($api->get("loc") eq "")
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

	# Now take a look at the Content-type to see if we should enable editing
	# in a text box.

	my ($header_op,$header_text,$payload) =
		$site->split_content($op->get("content"));

	my $content_type = $header_op->get("Content-type");
	$content_type = $header_op->get("Content-Type") if $content_type eq "";

	my $len_content = length($op->get("content"));
	my $guard = unpack("H*",$s->{hasher}->sha256($op->get("content")));

	{
	my $link_edit = $site->highlight_link(
		$site->url(function => "edit", $op->slice(qw(loc usage))),
		"Edit", ($function eq "edit"), "Edit web page",
		);

	my $link_upload = $site->highlight_link(
		$site->url(function => "upload", $op->slice(qw(loc usage))),
		"Upload", ($function eq "upload"), "Upload document",
		);

	my $link_view;
	{
	# LATER probably need to make a simple ultra-reliable path-quotation thing.
	my $q_hash = $site->{html}->quote($op->get("hash"));
	my $url = "/view/$q_hash";

	$link_view = $site->highlight_link(
		$url,
		"View", 0, "View as web page",
		);
	}

	my $link_change_loc = $site->highlight_link(
		$site->url(function => $function,
			change_loc => 1,
			$op->slice(qw(loc usage))),
		"Location", 0, "Change editing location",
		);

	my $link_change_usage = $site->highlight_link(
		$site->url(function => $function,
			change_usage => 1,
			$op->slice(qw(loc usage))),
		"Usage", 0, "Change usage location",
		);

	# LATER smooth out Edit/Upload/Delete distinctions.
	# I think instead of doing it based on content type you can do it
	# based on current $function -- but what about switching between
	# Edit and Upload capability?  Perhaps user should just Delete the
	# document in that case and start fresh.  For now I just added the
	# clause || $function eq "edit" so I can see an edit link on types
	# like loom/folder etc.

	my @links;

	push @links,
		$site->highlight_link(
			$site->url,
			"Home");

	push @links,
		$site->highlight_link(
			$site->url(help => 1),
			"Advanced");

	push @links, "";

	my $enable_edit = 0;

	if ($content_type eq "" || $content_type eq "text/plain"
		|| $content_type eq "text/html" || $function eq "edit")
		{
		$enable_edit = 1;
		}

	push @links, $link_edit if $enable_edit;
	push @links, $link_upload;
	push @links, $link_view;
	push @links, $link_change_loc;
	push @links, $link_change_usage;
	$site->{top_links} = \@links;
	}

	my $archive_table = "";
	$archive_table .= <<EOM;
<table border=0 style='border-collapse:collapse'>
<colgroup>
<col width=200>
<col width=365>
<col width=95>
<col width=95>
<col width=95>
</colgroup>

EOM

	if ($op->get("change_loc"))
	{
	$site->set_focus("loc");

	$archive_table .= <<EOM;
<tr>
<td>
Change Location:
</td>
<td colspan=4>
<input type=text class=tt name=loc size=$input_size_id value="$q->{loc}">
<input type=submit name=go value="Go">
<input type=submit name=random value="Random">
</td>
</tr>

EOM
	}

	if ($op->get("change_usage"))
	{
	$site->set_focus("usage");

	$archive_table .= <<EOM;
<tr>
<td>
Change Usage:
</td>
<td colspan=4>
<input type=text class=tt name=usage size=$input_size_id value="$q->{usage}">
<input type=submit name=go value="Go">
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
<input type=file size=40 name=filename>
<input type=submit name=upload value="Upload">
<input type=hidden name=guard value="$guard">
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
<input type=submit name=write value="Write">
EOM
	}

	if ($enable_buy)
	{
	$archive_table .= <<EOM;
<input type=submit name=buy value="Buy">
EOM
	}

	if ($enable_sell)
	{
	$archive_table .= <<EOM;
<input type=submit name=sell value="Sell">
EOM
	}
	elsif ($function eq "upload" && !$enable_buy)
	{
	$archive_table .= <<EOM;
<input type=submit name=delete value="Delete">
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
<textarea name=content class=small rows=$q->{num_content_rows} cols=120>
$q->{content}</textarea>
</td>
</tr>
EOM
	}

	$archive_table .= <<EOM;

</table>
EOM

	$site->{body} .= <<EOM;
$archive_table

</form>
EOM

	return;
	}

sub full_uploaded_content
	{
	my $s = shift;
	my $filename = shift;
	my $uploaded_content = shift;

	# Don't override any existing content headers in the uploaded data.

	my ($header_op,$header_text,$content) =
		$s->{site}->split_content($uploaded_content);

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
			$inferred_header = "Content-type: $content_type\n\n"
			}
		}

	my $full_content = $inferred_header . $uploaded_content;

	return $full_content;
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
