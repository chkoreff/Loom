package page_contact;
use strict;
use archive;
use context;
use grid;
use html;
use http;
use id;
use loom_config;
use page;
use page_folder; # TODO
use random;

sub help_contact
	{
	page::printer_friendly() if http::get("print");

	page::emit(<<EOM
<h1> Contacts </h1>
A contact is a point through which two individuals may move assets back and
forth to each other.  A contact has a specific identifier (ID) which is a
hexadecimal number consisting of exactly 32 digits 0-9 or a-f.  Both parties
who wish to exchange value must add this same contact point to their respective
wallets.  When one party moves assets to the contact, the other party will see
the assets there and can claim them with a single click.
<p>
<b>Note:</b> When you hover over an entry in your contact list, it shows up as
a link which you can click to edit or see further details.

<h1> Establishing contact </h1>
Let us say that two business partners Alice and Bob wish to establish contact
so they may exchange value with each other on an ongoing basis.  It doesn't
matter who creates the new contact point, so in this example we'll assume
Alice does it.  Here are the steps:

<h2> Alice creates a new contact in her wallet </h2>
<ul>
<li> Alice clicks Contacts, then Create.  A brand new random contact point
appears.
<li> Alice enters the name "Bob" to help her remember who the contact is.
<li> Alice presses Save.
</ul>

<h2> Alice sends the new contact point to Bob </h2>
<ul>
<li> Alice copies the contact point (using Ctrl-C or right-click/Copy), pastes
it into a message, and sends it to Bob.  Alice should do this as
<em>securely</em> as possible (see below for a discussion of this).
<li> Bob receives the message from Alice.
</ul>

<h2> Bob adds the new contact to his wallet </h2>
<ul>
<li> Bob clicks "Accept" in his contact list.
<li> Bob copies the contact point out of Alice's message and pastes it into the
ID field on the form.
<li> Bob enters the name "Alice" to help him remember who the contact is.
<li> Bob presses Save.
</ul>

<p>
At this point, both Alice and Bob have entered the <em>identical</em> contact
ID into their respective wallets.  Alice has named the contact "Bob", and
Bob has named the contact "Alice".  Now they can pay assets back and forth to
each other on the Home page.  When Alice pays something to Bob, Bob will see it
and he can claim it with a single click (under "Assets In Transit").  Same
thing when Bob pays Alice.

<h1> Communicating securely </h1>

When Alice communicates the new contact point to Bob, she should do so as
<em>securely</em> as possible.  Ideally she would send it by encrypted email,
but using a messaging program such as Skype is probably acceptable.
<p>
Alice might choose to send it by normal unencrypted email, but that is not
advisable.  There is some chance that a hacker might view the email and add the
contact point to his own wallet.  If the hacker happens to be looking at that
contact point while Alice or Bob are moving assets through it, he could claim
the assets for himself.  This scenario should be fairly unlikely, but if it is
at all practical to avoid unencrypted emails, please do so.
<p>
Alice could call Bob on the telephone and read the contact point to him, and
even that is more secure than normal email.  If Alice were especially cautious,
she might insist on meeting Bob <em>in person</em> and giving him the new
contact point on a slip of paper.
EOM
);
	return;
	}

sub page_contact_list
	{
	# LATER use CSS style sheet

	my $odd_color = loom_config::get("odd_row_color");
	my $even_color = loom_config::get("even_row_color");

	my $odd_row = 1;  # for odd-even coloring

	my $table = "";

	my $link_create = page::highlight_link(
		html::top_url(http::slice("function"),
			"action","invite",
			"default_include_usage_tokens","1",
			http::slice("session")),
		"Create a new contact point.");

	my $link_accept = page::highlight_link(
		html::top_url(http::slice("function"),
			"action","accept",
			http::slice("session")),
		"Accept a contact point that someone sent to you.");

	my $hidden = html::hidden_fields(
		http::slice(qw(function session)));

	$table .= <<EOM;
<h1> Contact List </h1>
These are the contact points where you may store and move assets.  The first
contact is the secret location where you store your own personal assets.  Each
of the other contacts is a location that you share with a single individual,
allowing you to pay each other.
<p>$link_create</p>
<p>$link_accept</p>
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
<td class=wallet_bold_clean>
Name
</td>
</tr>
EOM

	my @list_loc = page_folder::get_sorted_list_loc();
	my $loc_folder = page_folder::current_location();

	my $save_enabled = http::get("save_enabled") ne "";

	for my $loc (@list_loc)
	{
	my $loc_name = page_folder::map_id_to_nickname("loc",$loc);

	my $q_loc_name = html::quote($loc_name);

	my $url = html::top_url("function",http::get("function"),
		"name",$loc_name, "session",http::get("session"));

	$q_loc_name =
	qq{<a href="$url" title="View or edit this contact.">$q_loc_name</a>};

	my $row_color = $odd_row ? $odd_color : $even_color;
	$odd_row = 1 - $odd_row;

	my $enable_control;
	if ($loc eq $loc_folder)
		{
		$enable_control = "";
		$q_loc_name = "<b>$q_loc_name</b>";
		}
	else
		{
		my $is_disabled = page_folder::get("loc_disable.$loc");
		my $is_enabled = !$is_disabled;

		if ($save_enabled)
			{
			$is_enabled = http::get("enable_$loc") ne "";
			my $disable_flag = $is_enabled ? "" : "1";
			page_folder::put("loc_disable.$loc",$disable_flag);
			}

		my $checked = $is_enabled ? " checked" : "";

		$enable_control =
		qq{<input$checked type=checkbox name=enable_$loc>};
		}

	$table .= <<EOM;
<tr style='background-color:$row_color'>
<td align=center>
$enable_control
</td>
<td style='padding:5px'>
$q_loc_name
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

sub page_zoom_contact_heading
	{
	my $loc_name = http::get("name");
	my $loc = page_folder::map_nickname_to_id("loc",$loc_name);
	my $loc_folder = page_folder::current_location();
	my $q_loc_name = html::quote($loc_name);

	my $q_title;
	my $q_loc_id;

	if ($loc ne $loc_folder)
		{
		$q_title = qq{ title="Send to recipient of payment."};
		$q_loc_id = $loc;
		}
	else
		{
		$q_title = "";
		$q_loc_id = "(Secret)";
		}
	
	page::emit(<<EOM
<h1> Contact : $q_loc_name </h1>
<p> Location :
<span class=mono style='color:green; font-weight:bold'$q_title>$q_loc_id</span>
</p>
EOM
);
	}

sub page_zoom_contact
	{
	my $loc_name = http::get("name");

	my $loc = page_folder::map_nickname_to_id("loc",$loc_name);
	if ($loc eq "")
		{
		page_contact_list();
		return;
		}

	my $loc_folder = page_folder::current_location();
	my $q_loc_name = html::quote($loc_name);

	my $action = http::get("action");

	if ($action eq "rename")
		{
		my $length = html::display_length($q_loc_name);
		my $size = $length + 3;
		$size = 25 if $size < 25;
		$size = 70 if $size > 70;

		page::set_focus("new_name");

		my $hidden = html::hidden_fields(
			http::slice(qw(function name action session)));

		my $q_new_name = $q_loc_name;

		my $new_name = http::get("new_name");

		my $error = "";

		my $rename_complete = 0;

		if ($new_name ne "")
		{
		$q_new_name = html::quote($new_name);

		if ($new_name eq $loc_name)
			{
			# No change
			$rename_complete = 1;
			}
		else
			{
			# Make sure the new name is not already used in the folder.
			my $new_loc = page_folder::map_nickname_to_id("loc",$new_name);

			if ($new_loc eq "")
				{
				# OK, we're good to go, let's save the new name.

				page_folder::put("loc_name.$loc",$new_name);

				page_folder::save();

				http::put("name",$new_name);

				$loc_name = $new_name;
				$q_loc_name = html::quote($loc_name);

				$rename_complete = 1;
				}
			else
				{
				$error = <<EOM;
<p>
Sorry, that name is already used for another contact.  Please try a different
name.
EOM
				}
			}
		}

		# LATER simplify all this logic.

		if (!$rename_complete)
		{
		# LATER 0514 A friend discovered that this form doesn't work with
		# the native Blackberry browser (v 4.5) -- whether you press Enter
		# key or Save button.  However, it did work in Opera on Blackberry.

		my $link_cancel;
		{
		my $url = html::top_url(http::slice("function","name","session"));
		$link_cancel = qq{<a class=large style='padding-left:20px' href="$url">Cancel</a>};
		}

		page_zoom_contact_heading();

		page::emit(<<EOM
<p>
Enter the new name you would like to use for this contact:
<form method=post action="" autocomplete=off>
$hidden
<div>
<input type=text size=$size name=new_name value="$q_new_name">
<input type=hidden name=old_name value="$q_loc_name">
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
	elsif ($action eq "delete")
		{

		if ($loc eq $loc_folder)
		{
		# Cannot delete your own folder location.
		page::emit(<<EOM
<p>
Sorry, we cannot allow you to delete your main contact point where all your
personal assets are stored.
EOM
);
		return;
		}

		if (http::get("confirm_delete") ne "" && http::get("delete_now") ne "")
		{
		# Confirmed delete

		my $found = 0;

		# First search the history to see if there's an entry with this
		# contact point.

		{
		my $list_H = page_folder::get("list_H");
		my @list_H = split(" ",$list_H);

		for my $h_id (@list_H)
			{
			my $this_loc = page_folder::get("H_loc.$h_id");
			next if $this_loc ne $loc;
			$found = 1;
			last;
			}
		}

		my $old_list_loc = page_folder::get("list_loc");
		my @old_list_loc = split(" ",$old_list_loc);

		my @new_list_loc = ();

		for my $item (@old_list_loc)
			{
			next if $item eq $loc;
			push @new_list_loc, $item;
			}

		my $new_list_loc = join(" ",@new_list_loc);

		page_folder::put("list_loc",$new_list_loc);

		if ($found)
			{
			# We still have a history entry which refers to this contact, so
			# let's just mark the contact as deleted instead of clearing all
			# the details.  That way we can still render history properly.

			page_folder::put("loc_del.$loc",1);
			}
		else
			{
			page_folder::put("loc_name.$loc","");
			}

		page_folder::save();

		# Attempt to sell the underlying location for all assets in folder.

		my @list_type = split(" ",page_folder::get("list_type"));
		for my $type (@list_type)
			{
			grid::sell($type,$loc,$loc_folder);
			}

		page_contact_list();
		return;
		}

		}

	my $display = {};
	$display->{flavor} = "zoom_contact";
	$display->{location_name} = $loc_name;

	my $table = page_folder::value_table($display);
	my $items = $display->{location_items}->{$loc};
	$items = [] if !defined $items;
	my $num_items = scalar(@$items);

	page_zoom_contact_heading();

	if ($action eq "delete" && $loc ne $loc_folder)
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

	if ($num_items > 0)
	{
	page::emit(<<EOM
If you insist on deleting this contact, you risk <span class=alarm>losing</span>
all of the assets below.  We advise you to click Home and reclaim the assets
first, then come back here and delete the contact when it's empty.
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

	if ($action ne "delete")
	{
	my $link_refresh = page::highlight_link(
		html::top_url(http::slice("function","name","session")),
		"Refresh",
		);

	my $link_rename = page::highlight_link(
		html::top_url(http::slice("function","name","session"), "action","rename"),
		"Rename");

	if ($loc eq $loc_folder)
	{
	page::emit(<<EOM
<p>
<b>Options:</b>
<span style='padding-left:15px'> $link_refresh </span>
<span style='padding-left:15px'> $link_rename </span>
</p>
EOM
);
	}
	else
	{
	my $link_pay = page::highlight_link(
		html::top_url("function","folder", "loc",http::get("name"),
			http::slice("session")),
		"Pay");

	my $link_delete = page::highlight_link(
		html::top_url(http::slice("function","name","session"), "action","delete"),
		"Delete");

	page::emit(<<EOM
<p>
<b>Options:</b>
<span style='padding-left:15px'> $link_refresh </span>
<span style='padding-left:15px'> $link_pay </span>
<span style='padding-left:15px'> $link_rename </span>
<span style='padding-left:15px'> $link_delete </span>
</p>
EOM
);
	}

	}

	if ($num_items > 0)
		{
		page::emit($table);
		}

	# NOTE: I am keeping the elaborate Invitation Link mechanism because it's
	# good for automated invitation systems.  However, I am disabling its
	# display for now because it doesn't flow smoothly here.
	# LATER: maybe put this somewhere else.

	if (0)  # LATER disabled for now
	{

	if ($loc ne $loc_folder)
	{

	if ($action ne "accept" && $action ne "invite" && $action ne "delete")
	{
	my $loc_folder = page_folder::current_location();

	my $loc = page_folder::map_nickname_to_id("loc",$display->{location_name});

	my @list_type = page_folder::get_sorted_list_type_enabled();

	my $owner_name = $display->{location_name};
	my $sponsor_name = page_folder::map_id_to_nickname("loc",$loc_folder);

	my $context = context::new();

	context::put($context,"function","folder", "invite",1);

	context::put($context,"owner.name",$owner_name);
	context::put($context,"sponsor.name",$sponsor_name);

	my $type_no = 0;

	context::put($context,"nT","0");

	my @used_types;
	my %used_type;

	my $scan = grid::scan([$loc],\@list_type,1);
		# Scan all types including 0-values.

	for my $loc (split(" ",context::get($scan,"locs")))
		{
		for my $pair (split(" ",context::get($scan,"loc/$loc")))
			{
			my ($value,$type) = split(":",$pair);

			next if $used_type{$type};

			push @used_types, $type;
			$used_type{$type} = 1;
			}
		}

	for my $type (@used_types)
		{
		$type_no++;
		my $type_name = page_folder::map_id_to_nickname("type",$type);

		my $scale = page_folder::get("type_scale.$type");
		$scale = "0" if $scale eq "";

		my $min_precision = page_folder::get("type_min_precision.$type");
		$min_precision = "0" if $min_precision eq "";

		my $type_display = "";
		if ($scale ne "0" || $min_precision ne "0")
			{
			$type_display = "$scale.$min_precision";
			}

		context::put($context,"T$type_no.id",$type);
		context::put($context,"T$type_no.name",$type_name);
		context::put($context,"T$type_no.display",$type_display);
		}

	context::put($context,"nT",$type_no);

	context::put($context,"usage", $loc);

	my $url = html::top_url(context::pairs($context));

	my $build = page_folder::build_template($context);

	my $min_usage = $build->{min_usage};

	my $actual_usage = $display->{usage_count}->{$loc};
	$actual_usage = "0" if !defined $actual_usage;

	page::emit(<<EOM
<h2> Inviting a new user </h2>
If your contact has never used the Loom system before, he will need to sign up
and create his own Loom wallet.  For that he will need at least 100
usage tokens.
EOM
);
	if ($actual_usage >= 100)
	{
	page::emit(<<EOM
Since this contact already contains $actual_usage usage tokens, you can send
him the contact point and it will work just fine.
EOM
);
	}
	else
	{
	page::emit(<<EOM
So if you are sending this contact point to a brand new user, be sure to pay
at least 100 usage tokens to this contact first.  Then send him the contact
location.
EOM
);
	}

	if ($actual_usage >= $min_usage)
	{
	page::emit(<<EOM
<p>
Alternatively, you could send him this entire
<a href="$url" target=_invite>Invitation Link</a> which has
all the asset types listed above built in so he does not have to add them.
(Hint: to send the link, right-click on it and click "Copy Link" in the
pop-up menu.  Compose a message to your contact, right-click in the message
window and click "Paste" in the pop-up menu.)
EOM
);
	}
	else
	{
	page::emit(<<EOM
<p>
Alternatively, you could send him an entire invitation link with all the asset
types built in so he does not have to add them.  But first you must pay at
least $min_usage usage tokens to this contact.  Then click the contact name
again and an invitation link will appear here.
EOM
);
	}

	}

	}

	}

	return;
	}

sub page_add_contact
	{
	my $action = http::get("action");

	return if $action ne "accept" && $action ne "invite";

	my $loc = http::get("loc");
	$loc = html::trimblanks($loc);
	http::put("loc",$loc);

	my $nickname = http::get("name");

	my $q_error_stanza = "";
	my $q_error_loc = "";
	my $q_error_name = "";

	if ($action eq "invite" && $loc eq "")
		{
		# Generate a new random ID.  In the off chance that we generate one
		# already used in this folder, the user will get an error message.
		# Slightly confusing, but highly improbable.

		$loc = random::hex();
		}

	if (http::get("save") ne ""
		|| http::get("loc") ne "" || http::get("name") ne "")
		{
		# User submitted the form.

		if ($loc eq "")
		{
		page::set_focus("loc");
		$q_error_loc = "Missing ID";
		$q_error_stanza .= <<EOM;
<p>
Please enter the ID which your contact sent to you.
EOM
		}
		elsif (!id::valid_id($loc))
		{
		page::set_focus("loc");
		$q_error_loc = "Invalid ID";
		$q_error_stanza .= <<EOM;
<p>
That ID is invalid.  It should be a "hexadecimal" number, consisting of exactly
32 digits 0-9 or a-f.
EOM
		}

		my $old_name = page_folder::map_id_to_nickname("loc",$loc);

		# If the contact is marked as deleted, pretend like you didn't see it
		# so it can be added again.

		if (page_folder::get("loc_del.$loc"))
			{
			$old_name = "";
			}

		if ($old_name ne "")
		{
		page::set_focus("loc");
		$q_error_loc = "Already used";

		my $q_old_name = html::quote($old_name);

		$q_error_stanza .= <<EOM;
<p>
You have already added this contact point into your wallet and named it
<b>$q_old_name</b>.  You cannot add the same contact point again.
EOM
		}

		if ($q_error_loc eq "")
		{

		if ($nickname eq "")
		{
		page::set_focus("name");
		$q_error_name = "Missing name";
		$q_error_stanza .= <<EOM;
<p>
Please enter a name for this contact.
EOM
		}
		else
		{
		my $old_loc = page_folder::map_nickname_to_id("loc",$nickname);
		if ($old_loc ne "")
			{
			page::set_focus("name");
			$q_error_name = "Already used";
			$q_error_stanza .= <<EOM;
<p>
You have already used that name for another contact.  Please try a different
name.
EOM
			}
		}

		}

		if ($q_error_stanza eq "")
		{
		# Save the new entry.

		my $list_loc = page_folder::get("list_loc");
		my @list_loc = split(" ",$list_loc);
		push @list_loc, $loc;

		$list_loc = join(" ",@list_loc);

		page_folder::put("list_loc",$list_loc);
		page_folder::put("loc_name.$loc", $nickname);

		# Clear the deleted flag if any.
		page_folder::put("loc_del.$loc","");

		my $write = page_folder::save();

		if (context::get($write,"status") ne "success")
			{
			$q_error_stanza .= <<EOM;
<h2 class=alarm>ERROR:</h2>
Sorry, I could not add this contact to your wallet because
EOM
			if (context::get($write,"error_usage") eq "insufficient")
				{
				$q_error_stanza .= <<EOM;
you do not have enough usage tokens.
EOM
				}
			else
				{
				$q_error_stanza .= <<EOM;
some kind of internal error occurred.
EOM
				}
			}

		if ($q_error_stanza eq "" && $action eq "invite"
			&& http::get("include_usage_tokens") ne "")
			{
			my $type = "0" x 32;  # usage tokens
			my $qty = 100;

			my $loc_folder = page_folder::current_location();
			grid::buy($type,$loc,$loc_folder);
			my $move = grid::move($type,$qty,$loc_folder,$loc);

			if (context::get($move,"status") eq "fail")
				{
				$q_error_stanza .= <<EOM;
<h2 class=alarm>ERROR:</h2>
Sorry, I was unable to pay $qty usage tokens to your new contact.
EOM
				}
			}

		if ($q_error_stanza eq "")
			{
			# Contact added successfully, now zoom in on it.
			page_zoom_contact();
			return;
			}
		}

		}

	if ($action eq "accept")
	{
	page::emit(<<EOM
<h1>Accept a contact point that someone sent to you.</h1>
EOM
);
	}
	else
	{
	page::emit(<<EOM
<h1>Create a new contact point.</h1>
EOM
);
	}

	if ($q_error_stanza eq "")
		{
		if ($loc eq "")
			{
			page::set_focus("loc");
			}
		else
			{
			page::set_focus("name");
			}
		}

	my $q_loc = html::quote($loc);
	my $q_nickname = html::quote($nickname);

	my $table = "";
	$table .= <<EOM;
<table border=0 cellpadding=2 style='border-collapse:collapse'>
<colgroup>
<col width=100>
</colgroup>
EOM

	my $input_size_id = 32 + 4;
	my $dsp_id =
	qq{<input type=text class=mono name=loc size=$input_size_id value="$q_loc">};

	$q_error_loc = qq{<span class=alarm>$q_error_loc</span>}
		if $q_error_loc ne "";

	$q_error_name = qq{<span class=alarm>$q_error_name</span>}
		if $q_error_name ne "";

	$table .= <<EOM;
<tr>
<td>
ID:
</td>
<td>
$dsp_id
$q_error_loc
</td>
</tr>

<tr>
<td></td>
<td style='padding-bottom:15px'>
EOM

	if ($action eq "accept")
	{
	$table .= <<EOM;
Copy and paste the ID number here.
EOM
	}
	else
	{
	$table .= <<EOM;
Here we have conveniently inserted a new random contact point.
EOM
	}

	$table .= <<EOM;
</td>
</tr>

<tr>
<td>
Name:
</td>
<td>
<input type=text name=name size=40 value="$q_nickname">
$q_error_name
</td>
</tr>

<tr>
<td></td>
<td style='padding-bottom:15px'>
Enter a nickname for the contact to remind you who it is.
</td>
</tr>
EOM

	if ($action eq "invite")
	{
	my $checked = http::get("default_include_usage_tokens") ne "" ? " checked" : "";
	$table .= <<EOM;
<tr>
<td align=right valign=top>
<input$checked type=checkbox name=include_usage_tokens>
</td>
<td style='padding-bottom:15px'>
Click this checkbox if you are inviting a brand new user.
This will include 100 usage tokens at the contact point.
</td>
</tr>
EOM
#Click this checkbox if you are inviting a brand new user who has never
#used Loom before.  This will include 100 usage tokens at the contact point,
#enabling the user to Sign Up and create a brand new wallet.
	}

	my $link_cancel;
	{
	my $url = html::top_url(http::slice("function","session"));
	$link_cancel = qq{<a class=large style='padding-left:20px' href="$url">Cancel</a>};
	}

	$table .= <<EOM;
<tr>
<td> </td>
<td>
<input type=submit name=save value="Save">
$link_cancel
</td>
</tr>

<tr>
<td colspan=2>
$q_error_stanza
</td>
</tr>
EOM
	$table .= <<EOM;
</table>
EOM

	my $hidden = html::hidden_fields(
		http::slice(qw(function action default_include_usage_tokens session)));

	page::emit(<<EOM
<form method=post action="" autocomplete=off>
$hidden
$table
</form>
EOM
);

	return;
	}

# LATER 20110313 consider simply refusing to delete a contact or asset if
# there's something there.

sub respond
	{
	page::set_title("Contacts");

	my $action = http::get("action");

	# Normalize.
	if ($action ne ""
		&& $action ne "rename"
		&& $action ne "delete"
		&& $action ne "accept"
		&& $action ne "invite"
		)
		{
		$action = "";
		http::put("action","");
		}

	if (http::get("help"))
		{
		help_contact();
		}
	elsif ($action eq "" || $action eq "rename" || $action eq "delete")
		{
		if (http::get("name") ne "")
			{
			page_zoom_contact();
			}
		else
			{
			page_contact_list();
			}
		}
	elsif ($action eq "accept" || $action eq "invite")
		{
		page_add_contact();
		}
	else
		{
		page_contact_list();
		}

	return;
	}

return 1;
