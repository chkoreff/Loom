package Loom::Sloop::Config;
use strict;
use Loom::DB::File;
use Loom::KV;

=pod

=head1 NAME

Automatically read the sloop configuration file only when needed.  If we're
only stopping the server we don't need it, and we wouldn't want a missing or
bad file to prevent us from stopping the server.

=cut

sub new
	{
	my $class = shift;
	my $top = shift;   # top directory
	my $name = shift;  # name of config file

	my $s = bless({},$class);
	$s->{db} = Loom::DB::File->new($top);
	$s->{name} = $name;
	$s->{options} = undef;
	return $s;
	}

# Return hash table of configuration options.

sub options
	{
	my $s = shift;
	my $key = shift;

	return $s->{options} if defined $s->{options};

	my $name = $s->{name};
	my $text = $s->{db}->get($name);
	die "missing configuration file $name\n" if $text eq "";

	my $opt = Loom::KV->new->hash($text);

	# Check the options and apply defaults.

	# Use an error log by default.  Otherwise use STDERR.
	$opt->{use_error_log} = 1 if !defined $opt->{use_error_log};

	# Default host_ip is localhost.  The value "*" means listen on any IP
	# (INADDR_ANY)
	$opt->{host_ip} = "127.0.0.1" if !defined $opt->{host_ip};

	# Maximum 128 child processes unless otherwise specified.
	$opt->{max_children} = 128 if !defined $opt->{max_children};

	die qq{The "module" option is missing.\n}
		if !defined $opt->{module};
	die qq{The "host_port" option is missing.\n}
		if !defined $opt->{host_port};

	$s->{options} = $opt;
	return $opt;
	}

return 1;

__END__

# Copyright 2008 Patrick Chkoreff
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
