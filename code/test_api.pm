use strict;
use context;
use file;
use sloop_top;

my $g_test_api_config;

sub test_api_config
	{
	my $key = shift;

	if (!defined $g_test_api_config)
		{
		my $top = sloop_top();
		my $text = file_get_content(file_child($top,"data/conf/test_api"));
		die if !defined $text;
		$g_test_api_config = op_read_kv(op_new(),$text);
		}

	my $val = op_get($g_test_api_config,$key);
	return $val if $val ne "";

	die qq{missing config param "$key"\n};
	}

return 1;
