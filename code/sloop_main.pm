use strict;
use Getopt::Long;
use sloop_server;

sub sloop_usage
	{
	my $prog_name = $0;
	$prog_name =~ s#.*/##;

	print STDERR <<EOM;
This program will start or stop the $prog_name server.

To start the server, or restart if already running, you may use either:

  $prog_name -start
  $prog_name -y

To stop the server, you may use either:

  $prog_name -stop
  $prog_name -n

EOM

	exit(2);
	}

sub sloop_main
	{
	# We call umask here so that when the server creates a new file the
	# permissions are restricted to read and write by the owner only.
	# The octal 077 value disables the "group" and "other" permission bits.

	umask(077);

	select(STDERR); $| = 1;
	select(STDOUT); $| = 1;

	# Read the command line options.
	my $opt = {};

	# LATER allow "loom start" and "loom stop"

	my $ok = GetOptions($opt,
		"start", "y",
		"stop", "n",
		"help", "h",
		);

	sloop_usage() if !$ok;

	my $do_start = $opt->{y} || $opt->{start};
	my $do_stop = $opt->{n} || $opt->{stop};

	$ok = 0 if $do_start && $do_stop;
	$ok = 0 if !$do_start && !$do_stop;
	$ok = 0 if $opt->{h} || $opt->{help};

	sloop_usage() if !$ok;
	sloop_respond($do_start);

	return;
	}

return 1;
