package page_help;
use strict;
use archive;
use help_archive;
use help_grid;
use html;
use http;
use loom_config;
use page;

sub get_email_support
	{
	my $email_support = loom_config::get("email_support");

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
	page::set_title("Advanced");

	page::top_link(page::highlight_link(html::top_url(),"Home"));

	my $topic = http::get("topic");

	if ($topic eq "contact_info" || $topic eq "pgp")
		{
		page::top_link(page::highlight_link(
			html::top_url("help",1, "topic","contact_info"),
			"Contact", $topic eq "contact_info"));

		page::top_link("") if $topic eq "contact_info";

		page::top_link(page::highlight_link(
			html::top_url("help",1, "topic","pgp"),
			"PGP", $topic eq "pgp"));
		}
	else
		{
		page::top_link(page::highlight_link(html::top_url("help",1),"Advanced", 1));

		my $link_grid_api = page::highlight_link(
			html::top_url("function","grid_tutorial", "help",1),
			"Grid");

		my $link_archive_api = page::highlight_link(
			html::top_url("function","archive_tutorial", "help",1),
			"Archive");

		my $link_tools = page::highlight_link(
			html::top_url("function","folder_tools"),
			"Tools");

		page::top_link("");
		page::top_link($link_grid_api);
		page::top_link($link_archive_api);
		page::top_link($link_tools);
		}

	if ($topic eq "contact_info")
		{
		my $dsp_email = get_email_support();

		page::emit(<<EOM
<h1>Contact Information</h1>
<p>
If you have any questions please send an email to $dsp_email.
EOM
);
		my $pgp_key = loom_config::get("support_pgp_key");
		if ($pgp_key ne "")
		{
		my $url = html::top_url("help",1, "topic","pgp");
		page::emit(<<EOM
<p>
To send an encrypted email, use our <a href="$url">PGP key</a>.
EOM
);
		}

		return;
		}

	if ($topic eq "pgp")
		{
		my $pgp_key = loom_config::get("support_pgp_key");
		return if $pgp_key eq "";

		my $dsp_email = get_email_support();

		page::emit(<<EOM
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

	my $link_grid_api = page::highlight_link(
		html::top_url("function","grid_tutorial", "help",1),
		"Grid");

	my $link_archive_api = page::highlight_link(
		html::top_url("function","archive_tutorial", "help",1),
		"Archive");

	my $link_tools = page::highlight_link(
		html::top_url("function","folder_tools"),
		"Tools");

	page::emit(<<EOM
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
<p>
We also have some $link_tools which do some computations with IDs and
passphrases.
EOM
);

	return;
	}

# Note that this routine deliberately does not quote the keys and values.

sub context_table
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

	page::emit(<<EOM

$table
EOM
);
	return;
	}

sub topic
	{
	my $topic = shift;

	page::set_title("Advanced");

	if ($topic eq "index")
		{
		help_index();
		return;
		}

	if ($topic eq "grid" || $topic eq "grid_tutorial")
		{
		help_grid::respond();
		return;
		}

	if ($topic eq "archive" || $topic eq "archive_tutorial")
		{
		help_archive::respond();
		return;
		}

	page::emit(<<EOM
<p>
No help is available on this topic.
EOM
);

	return;
	}

return 1;
