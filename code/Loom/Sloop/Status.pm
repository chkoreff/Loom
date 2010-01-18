package Loom::Sloop::Status;
use strict;
use Loom::DB::File;

=pod

=head1 NAME

This module helps the sloop listener track the global status of the server.

=cut

sub new
	{
	my $class = shift;
	my $dir = shift;  # run-time directory
	my $config = shift;

	my $s = bless({},$class);
	$s->{config} = $config;

	$s->{dir} = $dir;
	$s->{db} = Loom::DB::File->new($s->{dir});

	$s->{children} = {};  # hash of all child process ids
	return $s;
	}

sub start
	{
	my $s = shift;

	my $opt = $s->{config}->options;

	my $max_children = $opt->{max_children};
	$s->{db}->put("pid","$$ 0 $max_children\n");

	if ($opt->{use_error_log})
		{
		my $error_log = $s->{dir}->child("error_log")->full_path;
		open(STDERR, ">>$error_log") or die $!;
		chmod(0600,$error_log);
		}

	return;
	}

sub stop
	{
	my $s = shift;

	$s->{db}->put("pid","");
	return;
	}

sub child_enters
	{
	my $s = shift;
	my $child = shift;

	$s->{children}->{$child} = 1;
	$s->update_num_children;
	return;
	}

sub child_exits
	{
	my $s = shift;
	my $child = shift;  # the process id

	delete $s->{children}->{$child};
	$s->update_num_children;
	return;
	}

# Return the list of child process ids.
sub children
	{
	my $s = shift;
	return keys %{$s->{children}};
	}

sub num_children
	{
	my $s = shift;
	return scalar $s->children;
	}

sub update_num_children
	{
	my $s = shift;

	my $opt = $s->{config}->options;
	my $max_children = $opt->{max_children};
	my $num_children = $s->num_children;

	$s->{db}->put("pid","$$ $num_children $max_children\n");
	return;
	}

sub info
	{
	my $s = shift;

	my $text = $s->{db}->get("pid");
	chomp $text;

	my ($pid,$num_children,$max_children) = split(" ",$text);
	$pid = "" if !defined $pid;
	$num_children = 0 if !defined $num_children;
	$max_children = 1 if !defined $max_children;

	return ($pid,$num_children,$max_children);
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
