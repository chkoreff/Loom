use strict;

my $g_loom_config;

# Read the basic system configuration from the data/conf/loom file.   That will
# point to a place in the archive, and we read that in KV format.

sub loom_init_config
	{
	my $text = file_get_by_name(sloop_top(),"data/conf/loom");

	my $top_config = op_read_kv(op_new(),$text);
	my $config_id = op_get($top_config,"config_id");

	$g_loom_config = op_read_kv(op_new(),archive_get($config_id));

	op_default($g_loom_config,"odd_row_color","#ffffff");
	op_default($g_loom_config,"even_row_color","#e8f8fe");

	return;
	}

sub loom_config
	{
	my $key = shift;

	loom_init_config() if !defined $g_loom_config;
	return op_get($g_loom_config,$key);
	}

return 1;
