package Loom::Sloop::Signal;
use strict;

=pod

=head1 NAME

Catch operating system signals reliably.

=cut

my $g_alarm = 0;
my $g_child = 0;
my $g_interrupt = 0;

sub catch_signal
	{
	my $signal = shift;

	# Reinstall the handler first thing in case of unreliable signals.

	$SIG{$signal} = \&catch_signal;

	if ($signal eq "CHLD")
		{
		$g_child = 1;
		}
	elsif ($signal eq "ALRM")
		{
		$g_alarm = 1
		}
	elsif ($signal eq "INT" || $signal eq "TERM")
		{
		$g_interrupt = 1;
		}
	}

sub clear
	{
	$g_alarm = 0;
	$g_child = 0;
	$g_interrupt = 0;

	for my $signal (qw(CHLD HUP PIPE TERM INT ALRM))
		{
		$SIG{$signal} = \&catch_signal;
		}
	return;
	}

BEGIN { clear() }

# The "new" routine is artificial since signals are global.
sub new
	{
	my $class = shift;

	my $s = $class;  # no state: just use the class name as the object
	$s->clear;
	return $s;
	}

sub put_alarm { shift; $g_alarm = shift; }
sub put_child { shift; $g_child = shift; }
sub put_interrupt { shift; $g_interrupt = shift; }

sub get_alarm { return $g_alarm }
sub get_child { return $g_child }
sub get_interrupt { return $g_interrupt }

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
