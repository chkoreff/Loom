package Loom::Sloop::Main;
use strict;
use Getopt::Long;
use Loom::File;
use Loom::Sloop::Config;
use Loom::Sloop::Listen;

=pod

=head1 NAME

The top-level module called by the "sloop" executable.

=cut

sub new
	{
	my $class = shift;
	my $arena = shift;

	my $s = bless({},$class);
	$s->{arena} = $arena;
	return $s;
	}

sub run
	{
	my $s = shift;

	# We call umask here so that when the server creates a new file the
	# permissions are restricted to read and write by the owner only.
	# The octal 077 value disables the "group" and "other" permission bits.

	umask(077);

	select(STDERR); $| = 1;
	select(STDOUT); $| = 1;

	# Read the command line options.
	my $opt = {};

	my $ok = GetOptions($opt,
		"start", "y",
		"stop", "n",
		"help", "h",
		"t",
		);

	$s->usage if !$ok;

	my $do_start = $opt->{y} || $opt->{start};
	my $do_stop = $opt->{n} || $opt->{stop};
	my $do_test = $opt->{t};

	$ok = 0 if $do_start && $do_stop;
	$ok = 0 if !$do_start && !$do_stop && !$do_test;
	$ok = 0 if $do_stop && $do_test;
	$ok = 0 if $opt->{h} || $opt->{help};

	$s->usage if !$ok;

	# Run the server listener loop.

	my $top = Loom::File->new($s->{arena}->{TOP});
	my $config = Loom::Sloop::Config->new($top,"data/conf/sloop");

	my $arena = { top => $top, config => $config, start => $do_start,
		test => $do_test };

	my $listener = Loom::Sloop::Listen->new($arena);
	$listener->respond;

	return;
	}

sub usage
	{
	my $s = shift;

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

You can use the -t option to force a self-test when starting the server:

  $prog_name -y -t

Or you can run the self-test by itself:

  $prog_name -t

EOM

	exit(2);
	}

return 1;

__END__

# Copyright 2009 Patrick Chkoreff
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions
# and limitations under the License.
