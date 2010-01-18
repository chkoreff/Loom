package Loom::Sloop::Client;
use strict;

=pod

=head1 NAME

This module represents the "client" who is connected to the web server.
The server calls send, receive, disconnect, etc.

=cut

sub new
	{
	my $class = shift;
	my $client_socket = shift;
	my $status = shift;
	my $signal = shift;

	my $s = bless({},$class);

	$s->{client_socket} = $client_socket;
	$s->{status} = $status;
	$s->{signal} = $signal;

	$s->{beg_time} = time;
	$s->{max_life} = 600;
	$s->{min_life} = 10;

	$s->{exiting} = 0;

	return $s;
	}

# Receive data from the client, storing the data in the buffer.  Return the
# number of bytes read.
#
# The exiting flag will become true if the server is shutting down for any
# reason, e.g. the remote end disconnects, the server is shut down with an
# interrupt, the client has exceeded its lifespan, or a system error occurs.

sub receive
	{
	my $s = shift;
	my $buffer = \shift;   # reference to buffer string
	my $max_read = shift;

	die if !defined $max_read;

	while (1)
		{
		# LATER 1231 I can't make this exit condition happen.  Perhaps a new
		# signal handler for the child process?  Because the child is forked,
		# it's probably just inheriting the parent's memory image.  Perhaps
		# the child should reset the signal handler.

		$s->{exiting} = 1 if $s->{signal}->get_interrupt;
		return 0 if $s->{exiting};

		$s->check_lifespan;
		return 0 if $s->{exiting};

		$s->{signal}->put_child(0);
		$s->{signal}->put_alarm(0);

		alarm(10);

		# Read bytes from the socket onto the end of the buffer.
		my $num_read = sysread $s->{client_socket}, $$buffer, $max_read,
			length($$buffer);

		alarm(0);

		if (!defined $num_read)
			{
			# No data available.

			if ($s->{signal}->get_alarm)
				{
				# Ignore alarm signal (timeout on read).
				}
			elsif ($s->{signal}->get_child)
				{
				# Ignore child exit signal.
				}
			else
				{
				# Some kind of rare error, for example:
				#    Connection reset by peer
				#    Interrupted system call

				$s->{exiting} = 1;
				return 0;
				}
			}
		elsif ($num_read == 0)
			{
			# The remote client process disconnected.
			$s->{exiting} = 1;
			return 0;
			}
		elsif ($num_read < 0)
			{
			# This probably cannot happen.
			$s->{exiting} = 1;
			return 0;
			}
		else
			{
			# We read some data from the client ($num_read bytes).
			return $num_read;
			}
		}
	}

# Send a message back to client.  We wrap a timer around this call too, just in
# case the remote client process causes us to block indefinitely, perhaps by
# stubbornly neglecting to receive data.

sub send
	{
	my $s = shift;
	my $data = shift;

	return if !defined $data;

	my $timeout = 30;
		# I think this is more than enough time even for massive
		# responses.

	alarm($timeout);
	send $s->{client_socket}, $data, 0;
	alarm(0);

	if ($s->{signal}->get_alarm)
		{
		# Timeout on send, let's exit.
		$s->{exiting} = 1;
		}

	return;
	}

# Set a flag to disconnect from the client.
sub disconnect
	{
	my $s = shift;

	$s->{exiting} = 1;
	return;
	}

sub exiting
	{
	my $s = shift;
	return $s->{exiting};
	}

# Calculate the limit on our life span based on the current number of child
# processes running.  The more free slots there are, the longer we are allowed
# to live.

sub check_lifespan
	{
	my $s = shift;

	my ($ppid,$num_children,$max_children) = $s->{status}->info;

	my $elapse = time - $s->{beg_time};

	my $free_slots = $max_children - $num_children;
	my $cur_life = int($s->{max_life} * ($free_slots / $max_children));

	$cur_life = $s->{min_life} if $cur_life < $s->{min_life};

	my $remain_life = $cur_life - $elapse;

	if ($remain_life <= 0)
		{
		# This process has exceeded its maximum life span.
		$s->{exiting} = 1;
		}

	return;
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
