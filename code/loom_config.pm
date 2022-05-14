package loom_config;
use strict;
use file;

sub pgp_key
	{
	my $file = file::new("/home/web/data/site/static/fexl/keys/patrick.txt");
	my $text = file::get_content($file);
	return "" if !defined $text;
	return $text;
	}

sub get
	{
	my $key = shift;
	if ($key eq "odd_row_color") {return "#ffffff"};
	if ($key eq "even_row_color") {return "#e8f8fe"};
	if ($key eq "email_support") {return 'pc@fexl.com'};
	if ($key eq "support_pgp_key") {return pgp_key() };
	if ($key eq "this_url")
		{
		my $prefix = sloop_config::get("path_prefix");
		return "https://fexl.com".$prefix;
		}
	return "";
	}

return 1;
