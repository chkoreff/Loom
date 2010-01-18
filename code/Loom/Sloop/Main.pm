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

sub run
	{
	my $class = shift;
	my $TOP = shift;

	my $s = bless({},$class);

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
		);

	$s->usage if !$ok;

	my $do_start = $opt->{y} || $opt->{start};
	my $do_stop = $opt->{n} || $opt->{stop};

	$ok = 0 if $do_start && $do_stop;
	$ok = 0 if !$do_start && !$do_stop;

	$s->usage if !$ok;

	# Run the server listener loop.

	my $top = Loom::File->new($TOP);
	my $config = Loom::Sloop::Config->new($top,"data/conf/sloop");

	my $listener = Loom::Sloop::Listen->new($top,$config);
	$listener->respond($do_start);

	return;
	}

sub usage
	{
	my $s = shift;

	my $prog_name = $0;
	$prog_name =~ s#.*/##;

	print STDERR <<EOM;
Usage:
  $prog_name [ -start | -stop ]
  $prog_name [ -y | -n ]

Start or stop the $prog_name server.

To start the server, or restart if already running:

  $prog_name -start &

To stop the server:

  $prog_name -stop

As a shorthand, you may use -y for -start or -n for -stop.

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
