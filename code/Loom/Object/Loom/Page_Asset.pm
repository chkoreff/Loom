package Loom::Object::Loom::Page_Asset;
use strict;
use Loom::Context;
use Loom::Digest::SHA256;
use Loom::Qty;

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
	elsif ($action eq "accept")
		{
		$s->page_add_asset;
		}
	elsif ($action eq "create")
		{
		$s->page_create_asset;
		}
	elsif ($action eq "" || $action eq "rename" || $action eq "edit"
		|| $action eq "delete")
		{
		if ($op->get("name") ne "")
			{
			$s->page_zoom_asset;
			}
		else
			{
			$s->page_asset_list;
			}
		}
	else
		{
		$s->page_asset_list;
		}

	$s->top_links;

	return;
	}

sub top_links
	{
	my $s = shift;

	my $site = $s->{folder}->{site};
	my $op = $site->{op};

	# LATER consolidate menus

	push @{$site->{top_links}},
		$site->highlight_link(
			$site->url($op->slice("function","session")),
			"Asset Types",
			$s->{menu} eq "main",
			"Show entire list of assets",
			);

	if ($s->{menu} eq "zoom" || $s->{menu} eq "rename"
		|| $s->{menu} eq "edit" || $s->{menu} eq "delete")
		{
		my $name = $op->get("name");
		my $q_name = $s->{html}->quote($name);

		push @{$site->{top_links}},
			$site->highlight_link(
				$site->url($op->slice("function","name","session")),
				"Refresh",1) if $s->{menu} eq "zoom";

		push @{$site->{top_links}}, "" if $s->{menu} eq "zoom";

		if ($s->{menu} eq "zoom")
		{
		push @{$site->{top_links}},
			$site->highlight_link(
				$site->url(
					function => "folder",
					type => $name,
					$op->slice("session")),
				"Pay");
		}

		if ($s->{menu} eq "zoom" || $s->{menu} eq "rename")
		{
		push @{$site->{top_links}},
			$site->highlight_link(
				$site->url($op->slice("function","name","session"),
					action => "rename"),
				"Rename",
				$s->{menu} eq "rename", "Change the name of this asset");
		}

		if ($s->{menu} eq "zoom" || $s->{menu} eq "edit")
		{
		push @{$site->{top_links}},
			$site->highlight_link(
				$site->url($op->slice("function","name","session"),
					action => "edit"),
				"Edit",
				$s->{menu} eq "edit", "Edit all details of this asset");
		}

		if ($s->{menu} eq "zoom" || $s->{menu} eq "delete")
		{
		push @{$site->{top_links}},
			$site->highlight_link(
				$site->url($op->slice("function","name","session"),
					action => "delete"),
				"Delete",
				$s->{menu} eq "delete", "Delete this asset");
		}

		if ($s->{menu} eq "rename" || $s->{menu} eq "edit"
			|| $s->{menu} eq "delete")
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
				"Accept a new asset created by someone else",
				);
		}

	if ($s->{menu} eq "main" || $s->{menu} eq "create")
		{
		push @{$site->{top_links}},
			$site->highlight_link(
				$site->url($op->slice("function"),
					action => "create",
					$op->slice("session")),
				"Create",
				$s->{menu} eq "create",
				"Create a brand new asset which you issue!",
				);
		}

	if ($s->{menu} eq "accept" || $s->{menu} eq "create")
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

	return;
	}

sub page_asset_list
	{
	my $s = shift;

	my $site = $s->{folder}->{site};

	my $op = $site->{op};

	$site->set_title("Asset Types");

	# LATER use CSS style sheet

	# Blue scheme
	my $odd_color = "#efffff";
	my $even_color = "#e8f8fe";

	my $odd_row = 1;  # for odd-even coloring

	my $folder = $s->{folder}->{object};
	my $loc_folder = $s->{folder}->{location};

	my @list_type = $s->{folder}->get_sorted_list_type;

	my $table = "";
	$table .= <<EOM;
<p>
Here are the asset types which you have added to your folder.  Click an asset
name to view, edit, or delete that entry.

<p>
<table border=0 cellpadding=1 style='border-collapse:collapse;'>
<colgroup>
<col width=670>
</colgroup>
EOM

	my $context = Loom::Context->new($op->slice(qw(function session)));

	for my $type (@list_type)
	{
	my $type_name = $s->{folder}->map_id_to_nickname("type",$type);
	my $q_type_name = $s->{html}->quote($type_name);

	my $url = $site->url(function => $op->get("function"),
		name => $type_name, session => $op->get("session"));

	my $row_color = $odd_row ? $odd_color : $even_color;
	$odd_row = 1 - $odd_row;

	$table .= <<EOM;
<tr style='background-color:$row_color'>
<td>
<a href="$url" title="View/Edit Asset">$q_type_name</a>
</td>
</tr>
EOM
	}

	$table .= <<EOM;
</table>
EOM

	{
	my $hidden = $s->{html}->hidden_fields($op->slice(qw(function session)));

	$site->{body} .= <<EOM;
<form method=post action="" autocomplete=off>
$hidden
$table
</form>
EOM
	}

	}

sub help
	{
	my $s = shift;

	my $site = $s->{folder}->{site};
	my $op = $site->{op};

	$site->{printer_friendly} = 1 if $op->get("print");

	$s->{menu} = "help";

	$site->{body} .= <<EOM;
<h1> Assets </h1>
An asset is a type of value that can be moved around in the Loom system.
Before you can transact in a particular asset, you must explicitly accept it
into your folder.  Otherwise your folder will not recognize the asset, and you
will not see it even if someone moves it over to you through a contact point.

<h1> Accepting an asset </h1>

An asset description is a code which looks something like this:

<p class=tiny_mono style='margin-left:20px; color:blue'>
0f8fccf7c65e42d422c37ea222e700d5x2x2x466c6f77657220506574616c73x52c0dc51

<p>
Accepting that asset description into your folder is easy.  Click Assets,
then Accept.  Then copy and paste the asset description into the Description
field and press Save.  (Hint:  double-click the description to highlight it,
then right-click Copy, then right-click Paste into the Description field.)

<h1> Why must I add assets to my folder? </h1>
<p>
Loom users are creating new asset types all the time.  Most of these you will
never hear about.  But when you <em>do</em> hear about an asset and decide to
transact in it, you must add that asset to your folder so it can recognize it.
Otherwise you will never see that asset, even if someone tries to give some
of it to you.
<p>
We occasionally hear complaints that adding a new asset is a difficult and
mind-bending chore.  However, we think that adding a new asset to your Loom
folder is <em>far</em> easier than what you have to do now in non-Loom systems.
In the non-Loom world, every time you want to transact in a new type of asset,
you must create a brand new account in a totally separate system, with yet
another user name and password to track.
<p>
In Loom, all you have to do is copy and paste the asset description into your
<em>existing</em> folder.  It doesn't get any simpler than that!

<h1> Validating an asset </h1>
When you add a new asset to your folder, be sure you are getting the
information from a <em>reliable source</em>, preferably from the original
authoritative web site of the company issuing the asset.  You should not
trust asset descriptions recommended to you by strangers or even friends
without first checking with an authoritative source.
<p>
It is <span class=alarm>your responsibility</span> to avoid accepting a
counterfeit asset type.  For example, let's say that an online florist
has issued an asset type which they call "Flower Petals," and they accept
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
Keep in mind that once you've accepted the genuine asset into your folder, you
don't have to worry about it any more.  You only have to be careful when you
first accept it.
EOM
	return;
	}

sub page_zoom_asset
	{
	my $s = shift;

	my $folder = $s->{folder};
	my $site = $folder->{site};
	my $op = $site->{op};

	my $type_name = $op->get("name");
	my $q_type_name = $s->{html}->quote($type_name);

	my $type = $folder->map_nickname_to_id("type",$type_name);
	if ($type eq "")
		{
		$s->page_asset_list;
		return;
		}

	my $action = $op->get("action");

	my $edit_form = "";

	my $folder_object = $s->{folder}->{object};
	my $scale = $folder_object->get("type_scale.$type");
	my $precision = $folder_object->get("type_min_precision.$type");

	if ($action eq "rename")
		{
		my $length = $s->{html}->display_length($q_type_name);
		my $size = $length + 3;
		$size = 25 if $size < 25;
		$size = 70 if $size > 70;

		$site->set_focus("new_name");

		my $hidden = $s->{html}->hidden_fields(
			$op->slice(qw(function name action session)));

		my $q_new_name = $q_type_name;

		my $new_name = $op->get("new_name");

		my $error = "";

		my $rename_complete = 0;

		if ($new_name ne "")
		{
		$q_new_name = $s->{html}->quote($new_name);

		if ($new_name eq $type_name)
			{
			# No change
			$rename_complete = 1;
			}
		else
			{
			# Make sure the new name is not already used in the folder.
			my $new_type = $s->{folder}->map_nickname_to_id("type",$new_name);

			if ($new_type eq "")
				{
				# OK, we're good to go, let's save the new name.

				my $loc_folder = $s->{folder}->{location};

				$folder_object->put("type_name.$type",$new_name);

				my $archive = $s->{folder}->{archive};
				$archive->write_object($loc_folder,$folder_object,$loc_folder);
				$s->{folder}->{object} = $archive->touch_object($loc_folder);

				$op->put("name",$new_name);

				$type_name = $new_name;
				$q_type_name = $s->{html}->quote($type_name);

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
		$site->{body} .= <<EOM;
<p>
Enter the new name you would like to use for this asset:
<form method=post action="" autocomplete=off>
$hidden
<div>
<input type=text size=$size name=new_name value="$q_new_name">
<input type=hidden name=old_name value="$q_type_name">
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

	if ($action eq "accept")
	{
	$s->{menu} = "zoom";
	$site->{body} .= <<EOM;
<p>
You have now accepted the asset named <b>$q_type_name</b>.
EOM
	}
	elsif ($action eq "rename")
	{
	$s->{menu} = "zoom";
	$site->{body} .= <<EOM;
<p>
You have successfully renamed this asset as <b>$q_type_name</b>.
EOM
	}
	elsif ($action eq "create")
	{
	$s->{menu} = "zoom";
	$site->{body} .= <<EOM;
<p>
You have successfully created the new asset as <b>$q_type_name</b>.
EOM
	}
	elsif ($action eq "delete")
	{

	if ($op->get("confirm_delete") ne ""
		&& $op->get("delete_now") ne "")
		{
		# Confirmed delete

		my $found = 0;

		# First search the history to see if there's an entry with this
		# asset ID.

		{
		my $list_H = $folder->{object}->get("list_H");
		my @list_H = split(" ",$list_H);

		for my $h_id (@list_H)
			{
			my $this_type = $folder->{object}->get("H_type.$h_id");
			next if $this_type ne $type;
			$found = 1;
			last;
			}
		}

		my $folder_object = $s->{folder}->{object};
		my $loc_folder = $s->{folder}->{location};

		my $old_list_type = $folder_object->get("list_type");
		my @old_list_type = split(" ",$old_list_type);

		my @new_list_type = ();

		for my $item (@old_list_type)
			{
			next if $item eq $type;
			push @new_list_type, $item;
			}

		my $new_list_type = join(" ",@new_list_type);

		$folder_object->put("list_type",$new_list_type);

		if ($found)
			{
			# We still have a history entry which refers to this asset, so
			# let's just mark the asset as deleted instead of clearing all
			# the details.  That way we can still render history properly.

			$folder_object->put("type_del.$type",1);
			}
		else
			{
			$folder_object->put("type_name.$type","");
			$folder_object->put("type_scale.$type","");
			$folder_object->put("type_min_precision.$type","");
			}

		my $archive = $s->{folder}->{archive};
		my $grid = $s->{folder}->{grid};

		$archive->write_object($loc_folder,$folder_object,$loc_folder);
		$s->{folder}->{object} = $archive->touch_object($loc_folder);

		# Attempt to sell the underlying locations for this type.

		my @list_loc = split(" ",$folder_object->get("list_loc"));
		for my $loc (@list_loc)
			{
			$grid->sell($type,$loc,$loc_folder);
			}

		my $val = $grid->touch($type,$loc_folder);
		if ($val eq "-1")
			{
			# This is a brand new type with no outstanding liability, so let's
			# go ahead and move the issuer location back to zero.

			my $loc_zero = "0" x 32;
			$grid->buy($type, $loc_zero, $loc_folder);
			$grid->issuer($type,$loc_folder,$loc_zero);
			$grid->sell($type,$loc_folder,$loc_folder);
			$grid->sell($type,$loc_zero,$loc_folder);
			}

		$s->page_asset_list;
		return;
		}

	$s->{menu} = "delete";
	$site->{body} .= <<EOM;
<p>
You have decided to delete the asset named <b>$q_type_name</b>.
EOM
	}
	elsif ($action eq "edit")
	{
	my $updated;
	($updated,$edit_form) = $s->show_edit_form("edit");

	if ($updated)
		{
		# Read the name again in case it was changed.
		$type_name = $op->get("name");
		$q_type_name = $s->{html}->quote($type_name);

		$edit_form .= <<EOM;
<p>
<span style='color:green'>Changes saved.</span>
Press Cancel when you are done making changes.
EOM
		}

	$s->{menu} = "edit";
	$site->{body} .= <<EOM;
<p>
You are now editing the details of the asset named <b>$q_type_name</b>.
EOM
	}
	else
	{
	$s->{menu} = "zoom";
	$site->{body} .= <<EOM;
<p>
You have chosen the asset named <b>$q_type_name</b>.
EOM
	}

	# LATER set the title bar appropriately

	my $display = {};
	$display->{flavor} = "delete_type";  # LATER obsolete
	$display->{type_name} = $type_name;

	my $table = $folder->page_folder_value_table($display);

	# LATER maybe single out the issuer case specially.

	my $has_assets = $display->{involved_type}->{$type};

	if ($has_assets)
	{
	$site->{body} .= <<EOM;
You currently have some of this asset at these contact points:
$table
EOM
	}
	else
	{
	$site->{body} .= <<EOM;
You currently do not have any of this asset.
EOM
	}

	if ($action eq "delete")
	{
	my $hidden = $s->{html}->hidden_fields(
		$op->slice(qw(function name action session)));

	$site->{body} .= <<EOM;
<form method=post action="" autocomplete=off>
$hidden
EOM

	if ($has_assets)
	{
	$site->{body} .= <<EOM;
<h2 class=alarm>WARNING:</h2>
If you insist on deleting this asset, you risk <span class=alarm>losing</span>
all of the items listed here.  You could add the asset back in later and the
items would re-appear, but that is a dangerous practice.  We advise you not to
delete this asset unless you really want to forget about it and abandon these
items forever.
EOM
	}
	else
	{
	$site->{body} .= <<EOM;
<p>
Because you do not have any of this asset, it should be safe to delete it.
EOM
	}

	$site->{body} .= <<EOM;
<p>
To delete this asset now, check here
<input type=checkbox name=confirm_delete>
to confirm and then press
<input type=submit name=delete_now value="Delete Now" class=small>
EOM

	$site->{body} .= <<EOM;
</form>
EOM

	}
	elsif ($action eq "edit")
	{
	$site->{body} .= $edit_form;
	}
	else
	{
	my $hex_name = unpack("H*",$type_name);
	my $description = $type."x".$scale."x".$precision."x".$hex_name;

	# Now append a hash checksum of the main description.
	my $hasher = Loom::Digest::SHA256->new;
	my $checksum = substr(unpack("H*",$hasher->sha256($description)),0,8);

	$description .= "x$checksum";

	$site->{body} .= <<EOM;
<h2>How to introduce this asset to someone else</h2>
If you need to exchange this asset with someone who has not yet accepted it
into his own folder, send him this description:

<p class=mono style='margin-left:40px; color:#FAD805' title="Double-click, Copy and Paste this into a message">
$description
</p>

<p>
It should be easy to double-click, copy, and paste that description into an
email or chat.  You can also publish it on a blog or web site (along with
some explanatory text) so others can see it and investigate it for themselves.

<p>
When your contact receives the asset description, he can easily accept it into
his folder and then the two of you can click the asset back and forth through
your shared contact point.

<h2>What is an asset?</h2>
An asset is a type of value that can be paid (moved around between contacts)
in the Loom system.  An asset may represent something of value in the real
world.  The meaning of an asset is determined by the individual who created
it, known as the <em>issuer</em>.  You can issue new assets yourself if you
like, but it is more common to accept assets issued by other trusted parties.

<p>
Before you can transact in a particular asset, you must explicitly add it to
your folder.  Until then, you will not be able to see the asset even if
someone pays it to you!  That is for <em>your</em> protection.  In the Loom
system, <em>you</em> are completely responsible for adding new assets to your
folder.  You should only add assets which you receive from a trusted source
and verify yourself (e.g. through trusted web sites, blogs, mailing lists,
directories, friends, business associates, etc.).

EOM
	}

	return;
	}

sub page_add_asset
	{
	my $s = shift;

	my $site = $s->{folder}->{site};
	my $op = $site->{op};

	my $type = "";
	my $scale = "";
	my $min_precision = "";
	my $name = "";

	my $q_error_stanza = "";
	my $submitted_form = 0;
	my $duplicate_id = 0;
	my $duplicate_name = 0;

	my $entry_form = "";

	$s->{menu} = "accept";

	my $description = $op->get("description");

	# Translate all runs of non-printable characters to a single space.
	# This makes the code more forgiving, for example if someone copies
	# and pastes an asset description that has been wrapped across multiple
	# lines in an email.  Those can have embedded sequences such as \015\n.

	$description =~ s/[^ -~]+/ /g;
	$description = $s->{html}->trimblanks($description);

	$op->put("description",$description);

	my $q_description = $s->{html}->quote($description);

	$site->set_focus("description");

	my $hidden = $s->{html}->hidden_fields(
		$op->slice(qw(function action session)));

	$entry_form = <<EOM;
<p>
This is where you add an asset to your folder so you can transact in it.
You should only add assets which you receive from a trusted source and verify
yourself (e.g. through trusted web sites, blogs, mailing lists, directories,
friends, business associates, etc.).
<p>
Copy and paste the asset description into the field below and press Save.
<form method=post action="" autocomplete=off>
$hidden
<div>
<input class=tiny_mono type=text name=description size=100 value="$q_description">
<input type=submit name=save value="Save">
</div>
</form>
EOM

	if ($description ne "" || $op->get("save") ne "")
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
	$name = $s->{html}->remove_nonprintable($name);

	# Verify the checksum.

	# Chop off the checksum.
	my $inner_description = substr($description,0,-9);

	my $hasher = Loom::Digest::SHA256->new;
	my $expect_checksum = substr(unpack("H*",
		$hasher->sha256($inner_description)),0,8);

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
	elsif (!$s->{id}->valid_id($type))
		{
		$q_error_stanza .= <<EOM;
<p>
That asset ID is invalid.
EOM
		}
	else
		{
		my $old_name = $s->{folder}->map_id_to_nickname("type",$type);

		# If the asset is marked as deleted, pretend like you didn't see it
		# so it can be added again.

		if ($s->{folder}->{object}->get("type_del.$type"))
			{
			$old_name = "";
			}

		if ($old_name ne "")
			{
			my $q_old_name = $s->{html}->quote($old_name);
			my $q_name = $s->{html}->quote($name);

			$duplicate_id = 1;

			if ($old_name eq $name)
			{
			$q_error_stanza .= <<EOM;
<p>
You have already added this asset <b>$q_name</b> to your folder.
There is no need to add it again.
EOM
			}
			else
			{
			$q_error_stanza .= <<EOM;
<p>
You have already added this asset ID to your folder using the name
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
		my $other_type = $s->{folder}->map_nickname_to_id("type",$name);
		if ($other_type ne "" && $other_type ne $type)
			{
			$duplicate_name = 1;

			if (!$duplicate_id)
			{
			my $q_name = $s->{html}->quote($name);
			$q_error_stanza .= <<EOM;
<p>
This new asset is named <b>$q_name</b>, but you already have an asset with
that name in your folder.  This could be an innocent name conflict, since
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

	my $format = Loom::Qty->new;

	{
	$scale = $s->{html}->trimblanks($scale);

	if (!$format->valid_scale($scale))
		{
		$q_error_stanza .= <<EOM;
<p>
The scale number is invalid.
EOM
		}
	}

	{
	$min_precision = $s->{html}->trimblanks($min_precision);

	if (!$format->valid_scale($min_precision))
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

	my $result = $s->do_add_asset($type,$name,$scale,$min_precision);

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

		$op->put("name",$name);
		$s->page_zoom_asset;

		return;
		}
	}

	}

	$site->{body} .= $entry_form;
	$site->{body} .= $q_error_stanza if $q_error_stanza ne "";

	return;
	}

sub page_create_asset
	{
	my $s = shift;

	my $site = $s->{folder}->{site};
	my $op = $site->{op};

	$s->{menu} = "create";

	my ($updated,$edit_form) = $s->show_edit_form("create");

	if ($updated)
		{
		$s->page_zoom_asset;
		return;
		}

	$site->{body} .= $edit_form;

	return;
	}

sub do_add_asset
	{
	my $s = shift;
	my $type = shift;
	my $name = shift;
	my $scale = shift;
	my $min_precision = shift;

	my $result = {};
	$result->{error} = "";

	my $loc_folder = $s->{folder}->{location};
	my $folder_object = $s->{folder}->{object};

	my $list_type = $folder_object->get("list_type");
	my @list_type = split(" ",$list_type);
	push @list_type, $type;

	$list_type = join(" ",@list_type);

	$folder_object->put("list_type",$list_type);
	$folder_object->put("type_name.$type", $name);
	$folder_object->put("type_scale.$type", $scale);
	$folder_object->put("type_min_precision.$type", $min_precision);

	# Clear the deleted flag if any.
	$folder_object->put("type_del.$type","");

	my $archive = $s->{folder}->{archive};
	my $grid = $s->{folder}->{grid};

	$archive->write_object($loc_folder,$folder_object,$loc_folder);

	my $rsp = $archive->{api}->{rsp};
	my $status = $rsp->get("status");
	if ($status ne "success")
		{
		$result->{error} = "insufficient_usage";
		}

	$s->{folder}->{object} = $archive->touch_object($loc_folder);

	if ($result->{error} eq "")
		{
		# Now let's attempt to become the issuer for this type.

		# LATER perhaps ONLY with Create.  If you Accept an asset, just add it?

		my $loc_zero = "0" x 32;
		$grid->buy($type, $loc_zero, $loc_folder);
		$grid->buy($type, $loc_folder, $loc_folder);
		$grid->issuer($type,$loc_zero,$loc_folder);
		$grid->sell($type,$loc_zero,$loc_folder);
		}
	
	return $result;
	}

sub show_edit_form
	{
	my $s = shift;
	my $flavor = shift;   # edit or create

	die if $flavor ne "edit" && $flavor ne "create";

	my $folder = $s->{folder};
	my $site = $folder->{site};
	my $op = $site->{op};

	my $folder_object = $s->{folder}->{object};
	my $loc_folder = $s->{folder}->{location};

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
		$type_name = $op->get("name");
		$type = $folder->map_nickname_to_id("type",$type_name);

		die if $type eq "";

		$scale = $folder_object->get("type_scale.$type");
		$precision = $folder_object->get("type_min_precision.$type");
		}
	else
		{
		$type = $op->get("new_id");
		$type = $s->{html}->trimblanks($type);
		if ($type eq "")
			{
			$type = unpack("H*",$site->{random}->get);
			}

		$type_name = "";
		$scale = "";
		$precision = "";
		}

	my $new_name = $op->get("new_name");
	my $new_scale = $op->get("new_scale");
	my $new_precision = $op->get("new_precision");

	my $submitted_form =
		(
		$op->get("save") ne ""
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

			if (!$s->{id}->valid_id($type))
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
				my $other_name = $s->{folder}->map_id_to_nickname("type",$type);
				if ($other_name ne "")
					{
					$q_error_id = "Already used";
					$q_error_stanza .= <<EOM;
<p>
That ID is already used by another asset in your folder.
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
			my $other_type =
			$s->{folder}->map_nickname_to_id("type",$new_name);

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

		my $format = Loom::Qty->new;
		{
		$new_scale = $s->{html}->trimblanks($new_scale);

		if (!$format->valid_scale($new_scale))
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
		$new_precision = $s->{html}->trimblanks($new_precision);

		if (!$format->valid_scale($new_precision))
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

			$op->put("name",$new_name);

			if ($flavor eq "edit")
			{
			$folder_object->put("type_name.$type",$new_name);
			$folder_object->put("type_scale.$type",$new_scale);
			$folder_object->put("type_min_precision.$type",$new_precision);

			my $archive = $s->{folder}->{archive};
			$archive->write_object($loc_folder,$folder_object,$loc_folder);
			$s->{folder}->{object} = $archive->touch_object($loc_folder);
			}
			else
			{
			my $result = $s->do_add_asset($type,$new_name,$new_scale,
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

	my $hidden = $s->{html}->hidden_fields(
		$op->slice(qw(function name action session)));

	my $q_new_name = $s->{html}->quote($new_name);
	my $q_new_scale = $s->{html}->quote($new_scale);
	my $q_new_precision = $s->{html}->quote($new_precision);

	$q_error_id = qq{<span class=alarm>$q_error_id</span>}
		if $q_error_id ne "";
	$q_error_name = qq{<span class=alarm>$q_error_name</span>}
		if $q_error_name ne "";
	$q_error_scale = qq{<span class=alarm>$q_error_scale</span>}
		if $q_error_scale ne "";
	$q_error_precision = qq{<span class=alarm>$q_error_precision</span>}
		if $q_error_precision ne "";

	$site->set_focus("new_name");
	$site->set_focus("new_precision") if $q_error_precision ne "";
	$site->set_focus("new_scale") if $q_error_scale ne "";
	$site->set_focus("new_name") if $q_error_name ne "";
	$site->set_focus("new_id") if $q_error_id ne "";

	if ($flavor eq "edit")
	{
	$edit_form .= <<EOM;
<p style='margin-top:40px'>
You may change any details you like in the form below.  When you press Save,
you will remain on this page so you can see the effect of your changes.  To
leave this page, click the Cancel link above.
EOM
	}
	else
	{
	$edit_form .= <<EOM;
<p>
This is where you create a brand new asset type that has never been seen
before.  You become the sole issuer of the new asset, paying it into existence!
After you create the asset, you will see a <em>negative</em> balance on the
Home page.  That indicates that the asset is a <em>liability</em> to you.
Initially you'll have a balance of -0 (negative 0), because you haven't
spent any into existence yet.  But as you start paying the asset out, you'll
see your balance drop further negative.
<p>
Note that at all times, the magnitude of your negative balance will equal the
total quantity of the asset held by all others in the system.  That way, you
will always know how much is "out there" (currently issued).
<p>
Please enter the details of the new asset in the form below.
<p>
The <b>ID</b> is a number which uniquely identifies the asset.  It must be a
"hexadecimal" number, consisting of exactly 32 digits 0-9 or a-f.  Note that
we have automatically inserted a brand new random ID for you.
<p>
The <b>Name</b> can be anything you like.  This is just the name you are giving
the asset in your own folder.  It does not have to be unique across the entire
Loom system.  For example, if your name is Joe, you might want to call it
"Joe gold".  But it doesn't matter if several other Loom users named Joe also
use the name "Joe gold".  The ID is what truly distinguishes the asset, and you
(and others) can name this asset anything you like.
<p>
EOM
	}

	my $dsp_id;

	if ($flavor eq "edit")
		{
		$dsp_id = qq{<td class=large_mono>$type</td>};
		}
	else
		{
		my $input_size_id = 32 + 4;
		my $q_type = $s->{html}->quote($type);
		$dsp_id = <<EOM;
<td>
<input type=text class=tt name=new_id size=$input_size_id value="$q_type">
$q_error_id
</td>
EOM
		}

	$edit_form .= <<EOM;
<p>
The <b>Scale</b> is a number which tells the system where to put the decimal
point.  For example, if you have 123456789 units of the asset type and the
Scale is set to 7, the number will be displayed as 12.3456789 in your folder.
If you omit the Scale, it's the same as 0.
<p>
The <b>Min Precision</b> is optional.  This forces the system to display at
least a certain number of decimal places.  For example, if you set
Min Precision to 3, then the number "12.1" will be displayed as "12.100".

<form method=post action="" autocomplete=off>
$hidden

<table border=0 cellpadding=2 style='border-collapse:collapse; margin-left:20px'>
<colgroup>
<col width=100>
<col width=600>
</colgroup>

<tr>
<td>ID:</td>
$dsp_id
</tr>

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
<td>
Scale:
</td>
<td>
<input type=text name=new_scale size=5 value="$q_new_scale">
$q_error_scale
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
<td>
</td>
<td>
<input type=submit name=save value="Save">
</td>
</tr>

</table>

$q_error_stanza

</form>
EOM

	return ($update_folder,$edit_form);
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
