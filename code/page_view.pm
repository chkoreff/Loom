package page_view;
use strict;
use archive;
use http;
use page;

sub respond
	{
	my $loc = http::get("hash");
	my $text = archive::get($loc);

	if ($text eq "")
		{
		page::not_found();
		return;
		}

	page::ok($text);
	return;
	}

return 1;
