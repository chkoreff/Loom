package Loom::Site::Loom::Page_Contact;
use strict;
use Loom::Context;

sub new
	{
	my $class = shift;
	my $folder = shift;

	my $s = bless({},$class);
	$s->{folder} = $folder;
	$s->{id} = $folder->{id};
	$s->{html} = $folder->{html};
	return $s;
	}

sub respond
	{
	my $s = shift;

	my $site = $s->{folder}->{site};
	my $op = $site->{op};

	$s->{menu} = "main";

	my $action = $op->get("action");

	if ($op->get("help"))
		{
		$s->help;
		}
	elsif ($action eq "" || $action eq "rename" || $action eq "delete")
		{
		if ($op->get("name") ne "")
			{
			$s->page_zoom_contact;
			}
		else
			{
			$s->page_contact_list;
			}
		}
	elsif ($action eq "accept" || $action eq "invite")
		{
		$s->page_add_contact;
		}
	else
		{
		$s->page_contact_list;
		}

	$s->top_links;

	return;
	}

sub top_links
	{
	my $s = shift;

	my $site = $s->{folder}->{site};
	my $op = $site->{op};

	push @{$site->{top_links}},
		$site->highlight_link(
			$site->url($op->slice("function","session")),
			"Contacts",
			$s->{menu} eq "main",
			"Show entire list of contacts",
			);

	if ($s->{menu} eq "zoom"
		|| $s->{menu} eq "rename" || $s->{menu} eq "delete")
		{
		my $name = $op->get("name");
		my $q_name = $s->{html}->quote($name);

		push @{$site->{top_links}},
			$site->highlight_link(
				$site->url($op->slice("function","name","session")),
				$q_name,
				$s->{menu} eq "zoom");

		push @{$site->{top_links}}, "" if $s->{menu} eq "zoom";

		if ($s->{menu} eq "zoom" && !$s->{menu_disable_delete})
		{
		push @{$site->{top_links}},
			$site->highlight_link(
				$site->url(
					function => "folder",
					loc => $name,
					$op->slice("session")),
				"Pay");
		}

		if ($s->{menu} eq "zoom" || $s->{menu} eq "rename")
		{
		# LATER more titles on links
		push @{$site->{top_links}},
			$site->highlight_link(
				$site->url($op->slice("function","name","session"),
					action => "rename"),
				"Rename",
				$s->{menu} eq "rename");
		}
			
		if ($s->{menu} eq "zoom" || $s->{menu} eq "delete")
		{

		if (!$s->{menu_disable_delete})
		{
		push @{$site->{top_links}},
			$site->highlight_link(
				$site->url($op->slice("function","name","session"),
					action => "delete"),
				"Delete",
				$s->{menu} eq "delete");
		}

		}

		if ($s->{menu} eq "rename" || $s->{menu} eq "delete")
		{
		push @{$site->{top_links}}, "";
		push @{$site->{top_links}},
			$site->highlight_link(
				$site->url($op->slice("function","name","session")),
				"Cancel", 0, "Cancel this operation");
		}

		}

	push @{$site->{top_links}}, "" if $s->{menu} eq "main";

	if ($s->{menu} eq "main" || $s->{menu} eq "accept")
		{
		push @{$site->{top_links}},
			$site->highlight_link(
				$site->url($op->slice("function"),
					action => "accept",
					$op->slice("session")),
				"Accept",
				$s->{menu} eq "accept",
				"Accept a contact which someone else sent to you",
				);
		}

	if ($s->{menu} eq "main" || $s->{menu} eq "invite")
		{
		push @{$site->{top_links}},
			$site->highlight_link(
				$site->url($op->slice("function"),
					action => "invite",
					include_usage_tokens => "on",
					$op->slice("session")),
				"Invite",
				$s->{menu} eq "invite",
				"Invite someone else to be your contact",
				);
		}

	if ($s->{menu} eq "accept" || $s->{menu} eq "invite")
		{
		push @{$site->{top_links}}, "";

		push @{$site->{top_links}},
			$site->highlight_link(
				$site->url($op->slice("function","session")),
				"Cancel", 0, "Cancel this operation");
		}

	if ($s->{menu} eq "main" || $s->{menu} eq "help")
		{
		push @{$site->{top_links}},
			$site->highlight_link(
				$site->url($op->slice("function","session"), help => 1),
				"Help",
				$s->{menu} eq "help");
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

sub page_contact_list
	{
	my $s = shift;

	my $site = $s->{folder}->{site};
	my $op = $site->{op};

	$site->set_title("Contacts");

	# LATER use CSS style sheet

	# Blue scheme
	my $odd_color = "#efffff";
	my $even_color = "#e8f8fe";

	my $odd_row = 1;  # for odd-even coloring

	my $table = "";
	$table .= <<EOM;
<p>
Here are the contacts which you have added to your folder.  Click a contact
name to view, edit, or delete that entry.  To add a new entry, click Accept
or Invite above.

<p>
<table border=0 cellpadding=1 style='border-collapse:collapse;'>
<colgroup>
<col width=650>
</colgroup>
EOM

	my @list_loc = $s->{folder}->get_sorted_list_loc;
	my $loc_folder = $s->{folder}->{location};

	for my $loc (@list_loc)
	{
	my $loc_name = $s->{folder}->map_id_to_nickname("loc",$loc);

	next if $loc_name =~ /^\001/;  # skip inbound cash locations
	next if $loc_name =~ /^\002/;  # skip outbound cash locations

	my $q_loc_name = $s->{html}->quote($loc_name);
	$q_loc_name = "<b>$q_loc_name</b>" if $loc eq $loc_folder;

	my $url = $site->url(function => $op->get("function"),
		name => $loc_name, session => $op->get("session"));

	my $row_color = $odd_row ? $odd_color : $even_color;
	$odd_row = 1 - $odd_row;

	$table .= <<EOM;
<tr style='background-color:$row_color'>
<td>
<a href="$url" title="View/Edit Contact">$q_loc_name</a>
</td>
</tr>
EOM
	}

	$table .= <<EOM;
</table>
EOM

	$site->{body} .= $table;

	return;
	}

sub help
	{
	my $s = shift;

	my $site = $s->{folder}->{site};
	my $op = $site->{op};

	$site->{printer_friendly} = 1 if $op->get("print");

	$s->{menu} = "help";

	$site->{body} .= <<EOM;
<h1> Contacts </h1>
A contact is a point through which two individuals may move assets back and
forth to each other.  A contact has a specific identifier (ID) which is a
hexadecimal number consisting of exactly 32 digits 0-9 or a-f.  Both parties
who wish to exchange value must add this same contact ID to their respective
folders.  When one party moves assets to the contact, the other party will see
the assets there and can claim them with a single click.
<p>
<b>Note:</b> When you hover over an entry in your contact list, it shows up as
a link which you can click to edit or see further details.

<h1> Establishing contact </h1>
Let us say that two business partners Alice and Bob wish to establish contact
so they may exchange value with each other on an ongoing basis.  It doesn't
matter who creates the new contact point, so in this example we'll assume
Alice does it.  Here are the steps:

<h2> Alice creates a new contact in her folder </h2>
<ul>
<li> Alice clicks Contacts, then Invite.  A brand new random contact ID appears.
<li> Alice enters the name "Bob" to help her remember who the contact is.
<li> Alice presses Save.
</ul>

<h2> Alice sends the new contact ID to Bob </h2>
<ul>
<li> Alice copies the contact ID (using Ctrl-C or right-click/Copy), pastes
it into a message, and sends it to Bob.  Alice should do this as
<em>securely</em> as possible (see below for a discussion of this).
<li> Bob receives the message from Alice.
</ul>

<h2> Bob adds the new contact to his folder </h2>
<ul>
<li> Bob clicks "Accept" in his contact list.
<li> Bob copies the contact ID out of Alice's message and pastes it into the
ID field on the form.
<li> Bob enters the name "Alice" to help him remember who the contact is.
<li> Bob presses Save.
</ul>

<p>
At this point, both Alice and Bob have entered the <em>identical</em> contact
ID into their respective folders.  Alice has named the contact "Bob", and
Bob has named the contact "Alice".  Now they can pay assets back and forth to
each other on the Home page.  When Alice pays something to Bob, Bob will see it
and he can claim it with a single click (under "Assets In Transit").  Same
thing when Bob pays Alice.

<h1> Communicating securely </h1>

When Alice communicates the new contact ID to Bob, she should do so as
<em>securely</em> as possible.  Ideally she would send it by encrypted email,
but using a messaging program such as Skype is probably acceptable.
<p>
Alice might choose to send it by normal unencrypted email, but that is not
advisable.  There is some chance that a hacker might view the email and add
the contact ID to his own folder.  If the hacker happens to be looking at that
contact point while Alice or Bob are moving assets through it, he could claim
the assets for himself.  This scenario should be fairly unlikely, but if it
is at all practical to avoid unencrypted emails, please do so.
<p>
Alice could call Bob on the telephone and read the contact ID to him, and even
that is more secure than normal email.  If Alice were especially cautious, she
might insist on meeting Bob <em>in person</em> and giving him the new contact
ID on a slip of paper.
EOM
	return;
	}

sub page_zoom_contact
	{
	my $s = shift;

	my $folder = $s->{folder};
	my $site = $folder->{site};
	my $op = $site->{op};

	my $loc_name = $op->get("name");

	my $loc = $folder->map_nickname_to_id("loc",$loc_name);
	if ($loc eq "")
		{
		$s->page_contact_list;
		return;
		}

	my $loc_folder = $folder->{location};
	my $q_loc_name = $s->{html}->quote($loc_name);

	my $action = $op->get("action");
	if ($action eq "")
		{
		$s->{menu} = "zoom";
		}
	elsif ($action eq "rename")
		{
		my $length = $s->{html}->display_length($q_loc_name);
		my $size = $length + 3;
		$size = 25 if $size < 25;
		$size = 70 if $size > 70;

		$site->set_focus("new_name");

		my $hidden = $s->{html}->hidden_fields(
			$op->slice(qw(function name action session)));

		my $q_new_name = $q_loc_name;

		my $new_name = $op->get("new_name");

		my $error = "";

		my $rename_complete = 0;

		if ($new_name ne "")
		{
		$q_new_name = $s->{html}->quote($new_name);

		if ($new_name eq $loc_name)
			{
			# No change
			$rename_complete = 1;
			}
		else
			{
			# Make sure the new name is not already used in the folder.
			my $new_loc = $s->{folder}->map_nickname_to_id("loc",$new_name);

			if ($new_loc eq "")
				{
				# OK, we're good to go, let's save the new name.

				my $folder_object = $s->{folder}->{object};
				$folder_object->put("loc_name.$loc",$new_name);

				my $archive = $s->{folder}->{archive};
				$archive->write_object($loc_folder,$folder_object,$loc_folder);
				$s->{folder}->{object} = $archive->touch_object($loc_folder);

				$op->put("name",$new_name);

				$loc_name = $new_name;
				$q_loc_name = $s->{html}->quote($loc_name);

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

		if (!$rename_complete)
		{
		$site->{body} .= <<EOM;
<p>
Enter the new name you would like to use for this contact:
<form method=post action="" autocomplete=off>
$hidden
<div>
<input type=text size=$size name=new_name value="$q_new_name">
<input type=hidden name=old_name value="$q_loc_name">
<input type=submit name=save value="Save" class=small>
</div>
$error
</form>
EOM
		$s->{menu} = "rename";
		return;
		}

		$s->{menu} = "zoom";
		}
	elsif ($action eq "delete")
		{

		if ($loc eq $loc_folder)
		{
		# Cannot delete your own folder location.
		$site->{body} .= <<EOM;
<p>
Sorry, we cannot allow you to delete your main contact point where all your
personal assets are stored.
EOM
		$s->{menu} = "delete";
		return;
		}

		if ($op->get("confirm_delete") ne ""
			&& $op->get("delete_now") ne "")
		{
		# Confirmed delete

		my $found = 0;

		# First search the history to see if there's an entry with this
		# contact ID.

		{
		my $list_H = $folder->{object}->get("list_H");
		my @list_H = split(" ",$list_H);

		for my $h_id (@list_H)
			{
			my $this_loc = $folder->{object}->get("H_loc.$h_id");
			next if $this_loc ne $loc;
			$found = 1;
			last;
			}
		}

		my $folder_object = $s->{folder}->{object};

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

		if ($found)
			{
			# We still have a history entry which refers to this contact, so
			# let's just mark the contact as deleted instead of clearing all
			# the details.  That way we can still render history properly.

			$folder_object->put("loc_del.$loc",1);
			}
		else
			{
			$folder_object->put("loc_name.$loc","");
			}

		my $archive = $s->{folder}->{archive};
		my $grid = $s->{folder}->{grid};

		$archive->write_object($loc_folder,$folder_object,$loc_folder);
		$s->{folder}->{object} = $archive->touch_object($loc_folder);

		# Attempt to sell the underlying location for all assets in folder.

		my @list_type = split(" ",$folder_object->get("list_type"));
		for my $type (@list_type)
			{
			$grid->sell($type,$loc,$loc_folder);
			}

		$s->page_contact_list;
		return;
		}

		$s->{menu} = "delete";
		}
	else
		{
		$s->{menu} = "zoom";
		}

	my $display = {};
	$display->{flavor} = "zoom_contact";
	$display->{location_name} = $loc_name;

	# LATER set the title bar appropriately

	if ($action eq "")
	{
	$site->{body} .= <<EOM;
<p>
You have chosen your contact named <b>$q_loc_name</b>.
EOM
	}
	elsif ($action eq "rename")
	{
	$site->{body} .= <<EOM;
<p>
You have successfully renamed this contact as <b>$q_loc_name</b>.
EOM
	}
	elsif ($action eq "delete")
	{
	die if $loc eq $loc_folder;  # cannot happen

	$site->{body} .= <<EOM;
<p>
You have decided to delete your contact named <b>$q_loc_name</b>.
EOM
	}
	elsif ($action eq "accept")
	{
	$site->{body} .= <<EOM;
<p>
You have accepted a new contact named <b>$q_loc_name</b>.
EOM
	}
	elsif ($action eq "invite")
	{
	$site->{body} .= <<EOM;
<p>
You have now invited a new contact named <b>$q_loc_name</b>.
EOM
	}
	else
	{
	$site->{body} .= <<EOM;
<p>
You have chosen your contact named <b>$q_loc_name</b>.
EOM
	}

	if ($loc eq $loc_folder)
	{
	$s->{menu_disable_delete} = 1;

	$site->{body} .= <<EOM;
This is a special contact which represents <em>yourself</em>, and it is where
your own personal assets are stored.  Because this contact is not meant to be
shared, we do not display the contact identifier (ID) here.  You also cannot
delete this contact.
<p>
EOM
	}
	else
	{
	$site->{body} .= <<EOM;
The identifier
(ID) of this contact is:
<div class=large_mono style='margin-left:40px; margin-bottom:10px;'>
$loc
</div>
EOM
	}

	my $table = $folder->page_folder_value_table($display);

	my $num_items = scalar(@{$display->{location_items}->{$loc}});

	if ($action eq "delete")
		{
		# Confirmation form
		}

	if ($num_items == 0)
		{
		$site->{body} .= <<EOM;
This contact point currently contains no assets.
EOM
		}
	else
		{
		$site->{body} .= <<EOM;
This contact point currently contains these assets:
EOM

		$site->{body} .= $table;
		}

	if ($loc eq $loc_folder)
	{
	$site->{body} .= <<EOM;
<p>
These are your own <em>personal</em> assets.  If you would like to pay some of
those assets to one of your contacts, click Home and make the payment there.
EOM
	}
	elsif ($action eq "delete")
	{
	my $hidden = $s->{html}->hidden_fields(
		$op->slice(qw(function name action session)));

	$site->{body} .= <<EOM;
<form method=post action="" autocomplete=off>
$hidden
EOM

	if ($num_items == 0)
	{
	$site->{body} .= <<EOM;
<p>
Because there are no assets here, it should be safe to delete this contact.
EOM
	}
	else
	{
	$site->{body} .= <<EOM;
<h2 class=alarm>WARNING:</h2>
If you insist on deleting this contact, you risk <span class=alarm>losing</span>
all of the items listed here.  You could add the contact back in later and the
items would re-appear, but that is a dangerous practice.  We advise you to
click Home and reclaim the assets first, then come back here and delete the
contact when it's empty.
EOM
	}

	$site->{body} .= <<EOM;
<p>
To delete this contact now, check here
<input type=checkbox name=confirm_delete>
to confirm and then press
<input type=submit name=delete_now value="Delete Now" class=small>
EOM

	$site->{body} .= <<EOM;
</form>
EOM

	}
	else
	{

	if ($action eq "accept")
	{
	$site->{body} .= <<EOM;
<p>
You and your contact can now move assets back and forth through this shared
contact point.
EOM
	}

	if ($action eq "invite")
	{
	$site->{body} .= <<EOM;
<p>
Your next step is to copy and paste that contact ID into a message and send it
to your new contact.  He will then add it to his own Loom folder, and then the
two of you can move assets back and forth through your shared contact point.
EOM
	}

	if ($action ne "accept" && $action ne "invite")
	{
	$site->{body} .= <<EOM;
<h2> What is a contact? </h2>
A contact is a shared point where two people may exchange assets.  To share
this contact with a friend or business associate, copy and paste the ID above
into a message and send it to him.  He will then add it to his own Loom
folder, and then the two of you can move assets back and forth through your
shared contact point.
EOM
	}

	if ($action ne "accept")
	{
	$site->{body} .= <<EOM;
<h2> Sending a contact </h2>
When you send him the contact ID, try to send it fairly <em>securely</em> so
no one else can see it.  You could send it using a chat program such as Skype
or Pidgin, or in a PGP-encrypted email.  You could even call him on the phone
and read it to him, send it in a letter, or deliver it in person.
<p>
If you must send the ID by normal email, keep in mind that someone else who
might be monitoring email traffic could intercept it and pick up any assets
sitting at the contact point.  Normally this isn't a big problem, because the
only time assets are at the contact point is during an exchange, and those tend
to be brief and infrequent.  If you are especially cautious, you can notify
your contact right before you're about to pay him, then move the assets to the
contact point.  If he doesn't pick up the assets quickly (say within 5 minutes),
just take the assets back and try again later.
EOM
	}

	# NOTE: I am keeping this Invitation Link mechanism around for a while.
	# It's good for automated invitation systems.

	if ($action ne "accept" && $action ne "invite")
	{
	my $grid = $folder->{grid};
	my $loc_folder = $folder->{location};

	my $loc = $folder->map_nickname_to_id("loc",$display->{location_name});

	my @list_type = $folder->get_sorted_list_type;

	my $owner_name = $display->{location_name};
	my $sponsor_name = $folder->map_id_to_nickname("loc",$loc_folder);

	my $context = Loom::Context->new;

	$context->put(function => "folder", invite => 1);

	$context->put("owner.name" => $owner_name);
	$context->put("sponsor.name" => $sponsor_name);

	my $type_no = 0;

	$context->put("nT","0");

	my @used_types;
	my %used_type;

	my $rsp = $grid->scan([$loc],\@list_type,1);
		# Scan all types including 0-values.

	for my $loc (split(" ",$rsp->get("locs")))
		{
		for my $pair (split(" ",$rsp->get("loc/$loc")))
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
		my $type_name = $folder->map_id_to_nickname("type",$type);

		my $scale = $folder->{object}->get("type_scale.$type");
		$scale = "0" if $scale eq "";

		my $min_precision = $folder->{object}->get("type_min_precision.$type");
		$min_precision = "0" if $min_precision eq "";

		my $type_display = "";
		if ($scale ne "0" || $min_precision ne "0")
			{
			$type_display = "$scale.$min_precision";
			}

		$context->put("T$type_no.id",$type);
		$context->put("T$type_no.name",$type_name);
		$context->put("T$type_no.display",$type_display);
		}

	$context->put("nT",$type_no);

	$context->put("usage", $loc);

	my $url = $site->url($context->pairs);

	my $build = $folder->build_folder_template($context);

	my $min_usage = $build->{min_usage};

	my $actual_usage = $display->{usage_count}->{$loc};
	$actual_usage = "0" if !defined $actual_usage;

	$site->{body} .= <<EOM;
<h2> Inviting a new user </h2>
If your contact has never used the Loom system before, he will need to sign up
and create his own Loom folder.  For that he will need at least 100
usage tokens.
EOM
	if ($actual_usage >= 100)
	{
	$site->{body} .= <<EOM;
Since this contact already contains $actual_usage usage tokens, you can send
him the contact ID and it will work just fine.
EOM
	}
	else
	{
	$site->{body} .= <<EOM;
So if you are sending this contact ID to a brand new user, be sure to pay at
least 100 usage tokens to this contact first.  Then send him the contact ID.
EOM
	}

	if ($actual_usage >= $min_usage)
	{
	$site->{body} .= <<EOM;
<p>
Alternatively, you could send him this entire
<a class=label_link href="$url" target=_invite>Invitation Link</a> which has
all the asset types listed above built in so he does not have to add them.
(Hint: to send the link, right-click on it and click "Copy Link" in the
pop-up menu.  Compose a message to your contact, right-click in the message
window and click "Paste" in the pop-up menu.)
EOM
	}
	else
	{
	$site->{body} .= <<EOM;
<p>
Alternatively, you could send him an entire invitation link with all the asset
types built in so he does not have to add them.  But first you must pay at
least $min_usage usage tokens to this contact.  Then click the contact name
again and an invitation link will appear here.
EOM
	}

	}

	if ($action ne "accept")
	{
	$site->{body} .= <<EOM;

<h2> Using a contact ID for online shopping </h2>
You can also use a contact ID to make a payment in a shopping cart.  It acts
just like a debit card!  Simply copy and paste the ID into the merchant's
payment form and press the payment button there.  The merchant's web site will
then "debit" the contact ID for the purchase amount.  You can load the contact
ID with as much money as you like &mdash; even the exact amount of this one
purchase.  We recommend that you create a separate contact for each of your
favorite merchants, but you might prefer to use a single contact for all your
online shopping.
EOM
	}

	}

	return;
	}

sub page_add_contact
	{
	my $s = shift;

	my $site = $s->{folder}->{site};
	my $op = $site->{op};

	my $action = $op->get("action");

	return if $action ne "accept" && $action ne "invite";

	my $loc = $op->get("loc");
	$loc = $s->{html}->trimblanks($loc);
	$op->put("loc",$loc);

	my $nickname = $op->get("name");

	my $q_error_stanza = "";
	my $q_error_loc = "";
	my $q_error_name = "";

	if ($action eq "invite" && $loc eq "")
		{
		# Generate a new random ID.  In the off chance that we generate one
		# already used in this folder, the user will get an error message.
		# Slightly confusing, but highly improbable.

		$loc = unpack("H*",$site->{random}->get);
		}

	if ($op->get("save") ne ""
		|| $op->get("loc") ne "" || $op->get("name") ne "")
		{
		# User submitted the form.

		if ($loc eq "")
		{
		$site->set_focus("loc");
		$q_error_loc = "Missing ID";
		$q_error_stanza .= <<EOM;
<p>
Please enter the ID which your contact sent to you.
EOM
		}
		elsif (!$s->{id}->valid_id($loc))
		{
		$site->set_focus("loc");
		$q_error_loc = "Invalid ID";
		$q_error_stanza .= <<EOM;
<p>
That ID is invalid.  It should be a "hexadecimal" number, consisting of exactly
32 digits 0-9 or a-f.
EOM
		}

		my $old_name = $s->{folder}->map_id_to_nickname("loc",$loc);

		# If the contact is marked as deleted, pretend like you didn't see it
		# so it can be added again.

		if ($s->{folder}->{object}->get("loc_del.$loc"))
			{
			$old_name = "";
			}

		if ($old_name ne "")
		{
		$site->set_focus("loc");
		$q_error_loc = "Already used";

		my $q_old_name = $s->{html}->quote($old_name);

		$q_error_stanza .= <<EOM;
<p>
You have already accepted that contact ID into your folder and named it
<b>$q_old_name</b>.  You cannot add the same contact ID again.
EOM
		if ($action eq "invite")
		{
		$q_error_stanza .= <<EOM;
Please click the Invite link again to generate a new contact ID.
EOM
		}

		}

		if ($q_error_loc eq "")
		{

		if ($nickname eq "")
		{
		$site->set_focus("name");
		$q_error_name = "Missing name";
		$q_error_stanza .= <<EOM;
<p>
Please enter a name for this contact.
EOM
		}
		else
		{
		my $old_loc = $s->{folder}->map_nickname_to_id("loc",$nickname);
		if ($old_loc ne "")
			{
			$site->set_focus("name");
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

		my $folder_object = $s->{folder}->{object};
		my $loc_folder = $s->{folder}->{location};

		my $list_loc = $folder_object->get("list_loc");
		my @list_loc = split(" ",$list_loc);
		push @list_loc, $loc;

		$list_loc = join(" ",@list_loc);

		$folder_object->put("list_loc",$list_loc);
		$folder_object->put("loc_name.$loc", $nickname);

		# Clear the deleted flag if any.
		$folder_object->put("loc_del.$loc","");

		my $archive = $s->{folder}->{archive};

		$archive->write_object($loc_folder,$folder_object,$loc_folder);

		{
		my $rsp = $archive->{api}->{rsp};
		my $status = $rsp->get("status");

		if ($status ne "success")
			{
			$q_error_stanza .= <<EOM;
<h2 class=alarm>ERROR:</h2>
Sorry, I could not add this contact to your folder because
EOM
			if ($rsp->get("error_usage") eq "insufficient")
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
		}

		if ($q_error_stanza eq "" && $action eq "invite"
			&& $op->get("include_usage_tokens") ne "")
		{
		my $grid = $s->{folder}->{grid};
		my $type = "0" x 32;  # usage tokens
		my $qty = 100;

		$grid->buy($type,$loc,$loc_folder);
		$grid->move($type,$qty,$loc_folder,$loc);

		my $rsp = $grid->{api}->{rsp};
		if ($rsp->get("status") eq "fail")
			{
			$q_error_stanza .= <<EOM;
<h2 class=alarm>ERROR:</h2>
Sorry, I was unable to pay $qty usage tokens to your new contact.
EOM
			}
		}

		$s->{folder}->{object} = $archive->touch_object($loc_folder);

		if ($q_error_stanza eq "")
			{
			# Contact added successfully, now zoom in on it.
			$s->page_zoom_contact;
			return;
			}

		}

		}

	if ($action eq "accept")
	{
	$s->{menu} = "accept";
	$site->set_title("Accept Contact");

	$site->{body} .= <<EOM;
<p>
This is where you accept a contact ID number which someone else created and
sent to you.  Copy and paste the contact ID number you received into the ID
field below.  Enter the name of the contact so you know who it is.  Then press
Save, and the new contact will be added to your list.  Then the two of you will
have a shared contact point through which you can exchange assets back and
forth.
EOM
	}
	else
	{
	$s->{menu} = "invite";
	$site->set_title("Invite Contact");

	$site->{body} .= <<EOM;
<p>
This is where you invite someone else to be your contact.  We have already
inserted a new random contact ID into the form.  Please enter a name for 
the contact to help you remember who it is.  Then press Save, and the contact
will be added to your list.
<p>
After saving this entry, send the ID as securely as possible to your contact.
When he receives the ID, he will accept it into his own folder.  Then the two
of you will have a shared contact point through which you can exchange assets
back and forth.
<p>
You can also create a contact for online shopping.  The contact ID acts like a
"debit card" which you can copy and paste into the merchant's shopping cart.
<p>
EOM
	}

	if ($q_error_stanza eq "")
		{
		if ($loc eq "")
			{
			$site->set_focus("loc");
			}
		else
			{
			$site->set_focus("name");
			}
		}

	my $q_loc = $s->{html}->quote($loc);
	my $q_nickname = $s->{html}->quote($nickname);

	my $table = "";
	$table .= <<EOM;
<table border=0 cellpadding=2 style='border-collapse:collapse'>
<colgroup>
<col width=100>
<col width=600>
</colgroup>
EOM

	my $input_size_id = 32 + 4;
	my $dsp_id =
	qq{<input type=text class=tt name=loc size=$input_size_id value="$q_loc">};

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
<td>
Name:
</td>
<td>
<input type=text name=name size=40 value="$q_nickname">
$q_error_name
</td>
</tr>
EOM

	if ($action eq "invite")
	{
	my $checked = $op->get("include_usage_tokens") ne "" ? " checked" : "";
	$table .= <<EOM;
<tr>
<td align=right>
<input$checked type=checkbox name=include_usage_tokens>
</td>
<td>
This is a brand new user, so include 100 usage tokens to enable Sign Up.
</td>
</tr>
EOM
	}

	$table .= <<EOM;
<tr>
<td>
</td>
<td>
<input type=submit name=save value="Save">
</td>
</tr>

</table>
EOM

	my $hidden = $s->{html}->hidden_fields(
		$op->slice(qw(function action session)));

	$site->{body} .= <<EOM;
<form method=post action="" autocomplete=off>
$hidden
$table
$q_error_stanza
</form>
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
