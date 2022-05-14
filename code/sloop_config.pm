package sloop_config;
use strict;
use context;
use file;
use sloop_top;

# Read the configuration file data/conf/sloop if not already read.  This file
# is optional, so you only have to create it if you want to override the
# default values.  For example, if you wanted to run on port 7890 you would
# say:
#
# :host_port
# =7890

my $g_config;

sub init
	{
	my $top = sloop_top::dir();
	my $text = file::get_by_name($top,"data/conf/sloop");

	$g_config = context::read_kv(context::new(),$text);

	# Default host_ip is localhost.  The value "*" means listen on any IP
	# (INADDR_ANY)
	context::default($g_config,"host_ip","127.0.0.1");

	# Default port is 8286.
	context::default($g_config,"host_port","8286");

	# Maximum 128 child processes unless otherwise specified.
	context::default($g_config,"max_children","128");

	# Normally all STDERR messages go into the "data/run/error_log" file, but
	# if you set this flag to 0 they'll go straight to the console.  This is
	# useful for testing.
	context::default($g_config,"use_error_log","1");

	return;
	}

sub get
	{
	my $key = shift;

	init() if !defined $g_config;
	return context::get($g_config,$key);
	}

sub logical_path
	{
	my $prefix = get("path_prefix");
	my $path = http::path();
	$path = substr($path,length($prefix));
	return $path;
	}

sub host_domain
	{
	return "fexl.com";
	}

return 1;
