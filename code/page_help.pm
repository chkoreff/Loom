use strict;
use help_archive;
use help_grid;

sub get_email_support
	{
	my $email_support = loom_config("email_support");

	my @email_links = ();

	for my $email (split(" ",$email_support))
		{
		push @email_links, qq{<a href="mailto:$email">$email</a>};
		}

	my $result = join(" or ",@email_links);
	return $result;
	}

sub help_index
	{
	set_title("Advanced");

	top_link(highlight_link(top_url(),"Home"));

	my $topic = http_get("topic");

	if ($topic eq "contact_info" || $topic eq "pgp")
		{
		top_link(highlight_link(
			top_url("help",1, "topic","contact_info"),
			"Contact", $topic eq "contact_info"));

		top_link("") if $topic eq "contact_info";

		top_link(highlight_link(
			top_url("help",1, "topic","pgp"),
			"PGP", $topic eq "pgp"));
		}
	else
		{
		top_link(highlight_link(top_url("help",1),"Advanced", 1));

		my $link_grid_api = highlight_link(
			top_url("function","grid_tutorial", "help",1),
			"Grid");

		my $link_archive_api = highlight_link(
			top_url("function","archive_tutorial", "help",1),
			"Archive");

		my $link_cms = highlight_link(
			top_url("function","edit"),
			"CMS");

		my $link_tools = highlight_link(
			top_url("function","folder_tools"),
			"Tools");

		my $link_source = highlight_link(
			"/source",
			"Source Code", 0, "Source code for the Loom server");

		top_link("");
		top_link($link_grid_api);
		top_link($link_archive_api);
		top_link($link_cms);
		top_link($link_tools);
		top_link($link_source);
		}

	if ($topic eq "contact_info")
		{
		my $dsp_email = get_email_support();

		emit(<<EOM
<h1>Contact Information</h1>
<p>
If you have any questions please send an email to $dsp_email.
EOM
);
		my $pgp_key = archive_get(loom_config("support_pgp_key"));
		if ($pgp_key ne "")
		{
		my $url = top_url("help",1, "topic","pgp");
		emit(<<EOM
We encourage you to send us an <a href="$url">encrypted email</a>
using PGP.
EOM
);
		}

		return;
		}

	if ($topic eq "pgp")
		{
		my $pgp_key = archive_get(loom_config("support_pgp_key"));
		return if $pgp_key eq "";

		my $dsp_email = get_email_support();

		emit(<<EOM
<h1>How to send us an encrypted email</h1>
<p>
Please end an email to $dsp_email encrypted to this PGP key:
<pre class=tiny_mono>
$pgp_key
</pre>
EOM
);
		return;
		}

	if ($topic eq "get_usage_tokens")
		{
		my $loc = loom_config("exchanger_page");
		my $page = archive_get($loc);
		emit($page);
		return;
		}

	my $link_grid_api = highlight_link(
		top_url("function","grid_tutorial", "help",1),
		"Grid");

	my $link_archive_api = highlight_link(
		top_url("function","archive_tutorial", "help",1),
		"Archive");

	my $link_cms = highlight_link(
		top_url("function","edit"),
		"Content Management System");

	my $link_tools = highlight_link(
		top_url("function","folder_tools"),
		"Tools");

	emit(<<EOM
<h1> Application Programming Interface (API) </h1>
<p>
The entire Loom system is built upon a very solid Application Programmer
Interface (API).  There are two primary APIs:
<ul>
<li> $link_grid_api
<li> $link_archive_api
</ul>

Those links also include a "Tutorial" which gives you
the chance to try out the API interactively.

<h1> Content Management System (CMS) </h1>
<p>
The $link_cms is a very basic system for managing documents in the
Loom Archive.  You can create, delete, edit, and upload data here, paying in
usage tokens.

<h1> Tools </h1>
We also have some $link_tools which do some computations with IDs and
passphrases.

EOM
);

	return;
	}


# Note that this routine deliberately does not quote the keys and values.

sub help_context_table
	{
	my $table = "";

	$table .= <<EOM;
<div style='margin-left:20px'>
<table border=1 style='border-collapse:collapse'>
<colgroup>
<col width=120>
<col width=100>
<col width=430>
</colgroup>
<tr>
<th align=left>Key</th>
<th align=left>Value</th>
<th align=left>Description</th>
</tr>
EOM

	for my $entry (@_)
		{
		my ($key,$val,$desc) = @$entry;

		$table .= <<EOM;
<tr>
<td>$key</td>
<td>$val</td>
<td>$desc</td>
</tr>
EOM
		}

	$table .= <<EOM;
</table>
</div>
EOM

	emit(<<EOM

$table
EOM
);
	return;
	}

sub help_topic
	{
	my $topic = shift;

	set_title("Advanced");

	if ($topic eq "index")
		{
		help_index();
		return;
		}

	if ($topic eq "grid" || $topic eq "grid_tutorial")
		{
		help_grid();
		return;
		}

	if ($topic eq "archive" || $topic eq "archive_tutorial")
		{
		help_archive();
		return;
		}

	emit(<<EOM
<p>
No help is available on this topic.
EOM
);

	return;
	}

return 1;
