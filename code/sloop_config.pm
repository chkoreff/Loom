use strict;

# Read the configuration file data/conf/sloop if not already read.  This file
# is optional, so you only have to create it if you want to override the
# default values.  For example, if you wanted to run on port 7890 you would
# say:
#
# :host_port
# =7890

my $g_sloop_config;

sub sloop_init_config
	{
	my $top = sloop_top();
	my $text = file_get_by_name($top,"data/conf/sloop");

	$g_sloop_config = op_read_kv(op_new(),$text);

	# Default host_ip is localhost.  The value "*" means listen on any IP
	# (INADDR_ANY)
	op_default($g_sloop_config,"host_ip","127.0.0.1");

	# Default port is 8286.
	op_default($g_sloop_config,"host_port","8286");

	# Maximum 128 child processes unless otherwise specified.
	op_default($g_sloop_config,"max_children","128");

	# Normally all STDERR messages go into the "data/run/error_log" file, but
	# if you set this flag to 0 they'll go straight to the console.  This is
	# useful for testing.
	op_default($g_sloop_config,"use_error_log","1");

	return;
	}

sub sloop_config
	{
	my $key = shift;

	sloop_init_config() if !defined $g_sloop_config;
	return op_get($g_sloop_config,$key);
	}

return 1;
