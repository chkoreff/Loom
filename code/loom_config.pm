package loom_config;
use strict;
use archive;
use context;
use file;
use sloop_top;

my $g_config;

# Read the basic system configuration from the data/conf/loom file.   That will
# point to a place in the archive, and we read that in KV format.

sub init
	{
	my $text = file::get_by_name(sloop_top::dir(),"data/conf/loom");

	my $top_config = context::read_kv(context::new(),$text);
	my $config_id = context::get($top_config,"config_id");

	$g_config = context::read_kv(context::new(),archive::get($config_id));

	context::default($g_config,"odd_row_color","#ffffff");
	context::default($g_config,"even_row_color","#e8f8fe");

	return;
	}

sub get
	{
	my $key = shift;

	init() if !defined $g_config;
	return context::get($g_config,$key);
	}

return 1;
