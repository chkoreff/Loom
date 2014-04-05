package test_api;
use strict;
use context;
use file;
use sloop_top;

my $g_config;

sub config
	{
	my $key = shift;

	if (!defined $g_config)
		{
		my $top = sloop_top::dir();
		my $text = file::get_content(file::child($top,"data/conf/test_api"));
		die if !defined $text;
		$g_config = context::read_kv(context::new(),$text);
		}

	my $val = context::get($g_config,$key);
	return $val if $val ne "";

	die qq{missing config param "$key"\n};
	}

return 1;
