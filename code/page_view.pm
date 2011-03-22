use strict;

sub page_view_respond
	{
	my $loc = http_get("hash");
	my $text = archive_get($loc);

	if ($text eq "")
		{
		page_not_found();
		return;
		}

	page_ok($text);

	return;
	}

return 1;
