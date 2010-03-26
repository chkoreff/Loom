package Loom::Sloop::Listen;
use strict;
use POSIX "sys_wait_h";  # for the WNOHANG constant
use Socket;
use Loom::Load;
use Loom::Sloop::Client;
use Loom::Sloop::Signal;
use Loom::Sloop::Status;

=pod

=head1 NAME

Loom::Sloop::Listen - Listen for inbound connections and fork handler process

=head1 REFERENCES

=item http://www.unix.org.ua/orelly/perl/prog/ch06_02.htm#PERL2-CH-6-SECT-2.4.1

=item http://www.unix.com.ua/orelly/perl/cookbook/ch16_20.htm

=item http://www.unix.org.ua/orelly/perl/cookbook/ch17_03.htm

=cut

# Create a Sloop server listener loop.
#
# The $top is the top-level directory of the entire system.
#
# The $config object (typically a Loom::Sloop::Config) specifies:
#
#   module
#   host_port
#   use_error_log
#   host_ip
#   max_children
#
# The module is the logical name of the module which handles the application
# logic.  This option is required.  When the Sloop server receives a new client
# connection, it dynamically loads this module, creates a new handler object,
# and calls its "respond" routine to handle the entire life of the connection.
# See run_client for how this interaction works.
#
# The host_port is the port where the server listens for inbound connections.
# This option is required.
#
# The use_error_log option determines whether STDERR messages should be
# captured in "data/run/error_log" or go straight to the console (e.g. for
# testing).  The default value is 1, meaning capture them in the log file.
#
# The host_ip specifies the IP address where the server listens.  The default
# is "127.0.0.1" (localhost), which is usually what you want.  You may specify
# a specific IP address, or "*" to mean INADDR_ANY (listen on any address).
#
# max_children is the maximum number of incoming connections (clients) to
# service at any one time.  The default is 128.
#
# NOTE: the listener stores its process id in the "data/run/pid" file.

sub new
	{
	my $class = shift;
	my $arena = shift;

	my $s = bless({},$class);
	$s->{arena} = $arena;
	$s->{top} = $arena->{top};
	$s->{config} = $arena->{config};

	my $rundir = $s->{top}->child("data/run");
	$rundir->restrict;

	$s->{status} = Loom::Sloop::Status->new($rundir,$arena->{config});
	$s->{signal} = Loom::Sloop::Signal->new;
	return $s;
	}

# Run the listener loop.  The listener accepts inbound connections and forks a
# child process to handle them.

sub respond
	{
	my $s = shift;

	$s->{signal}->put_child(0);
	$s->{signal}->put_interrupt(0);

	return if !$s->stop_server;  # Stop the server if already running.

	$s->init_server if $s->{arena}->{start} || $s->{arena}->{test};
		# Initialize server if starting or testing.

	$s->start_server if $s->{arena}->{start}; # Start the server if desired.

	return;
	}

# When the user starts the server with -y, or runs the self-test with -t, we
# create an instance of the handler module without a client.  That gives it a
# chance to initialize, run tests, etc.  We don't do anything with the handler,
# we just create it and let it go.

sub init_server
	{
	my $s = shift;

	my $opt = $s->{config}->options;
	my $module = Loom::Load->new->require($opt->{module});
	my $handler = $module->new($s->{arena});

	return;
	}

# Start the server running in the background and loop until terminated.

sub start_server
	{
	my $s = shift;

	my $child = fork;

	if (!defined $child)
		{
		# The fork failed, probably because too many processes are running.
		print STDERR "The server failed to start because of this error: $!\n";
		exit(1);
		}
	elsif ($child != 0)
		{
		# The parent process does nothing.
		exit(0);
		}

	# This is the child process, which runs in the background and implements
	# the server.

	$s->{status}->start;
	$s->server_loop;
	$s->{status}->stop;

	return;
	}

# Stop the currently running server process, making sure it is actually gone
# from the "ps" listing before returning.  That's the only way to guarantee
# that the listening socket is fully released, allowing us to restart the
# server immediately without getting a "bind: Address already in use" error.
# Return false if the process fails to exit after waiting 2 minutes.

sub stop_server
	{
	my $s = shift;

	my ($curr_pid) = $s->{status}->info;
	return 1 if $curr_pid eq "";

	system("kill $curr_pid");

	my $beg_time = time;
	my $warn_time = $beg_time;

	while (1)
		{
		my $found_process = 0;

		my $fh;
		open($fh, "ps -p $curr_pid|") or die "error: $!";
		while (<$fh>)
			{
			chomp;
			my $line = $_;
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;

			my ($pid,$dev,$time,$name) = split(/\s+/, $line);
			next if $pid ne $curr_pid;

			$found_process = 1;
			last;
			}
		close($fh);

		last if !$found_process;  # process is gone

		my $time = time;
		my $elapse = $time - $beg_time;

		if ($elapse >= 120)
			{
			print STDERR "Gave up after $elapse seconds, sorry.\n";
			return 0;
			}

		if ($time - $warn_time >= 10)
			{
			$warn_time = $time;
			print STDERR "Still waiting for old process $curr_pid "
				."to exit after $elapse seconds ...\n";
			}

		sleep(1);
		}

	return 1;
	}

# Main server loop.  Listen for incoming connections and handle them.  Continue
# doing this until the process sees a TERM or INT interrupt signal.

sub server_loop
	{
	my $s = shift;

	my $opt = $s->{config}->options;
	my $host_port = $opt->{host_port};
	my $host_ip = $opt->{host_ip};

	# Create the server listener socket.

	my $server_socket;

	my $proto = getprotobyname('tcp');
	socket($server_socket, PF_INET, SOCK_STREAM, $proto)
		or die "Could not create the listener socket: $!";

	# Set flags so we can restart our server quickly (reuse the bind addr).

	setsockopt($server_socket, SOL_SOCKET, SO_REUSEADDR, 1);

	# Build socket address and bind server to it.

	my $host_addr  = $host_ip eq "*" ? INADDR_ANY : inet_aton($host_ip);
	my $server_addr = sockaddr_in($host_port,$host_addr);

	bind($server_socket, $server_addr)
		or die "Could not bind to port $host_port : $!\n";

	# Establish a queue for incoming connections.

	listen($server_socket, SOMAXCONN)
		or die "Could not listen on port $host_port : $!\n";

	# Accept and process connections.

	while (1)
		{
		if ($s->{signal}->get_child)
			{
			# CHLD signal:  At least one child process exited.  Wait for all
			# children to exit to avoid zombies.

			while (1)
				{
				my $child = waitpid(-1, &WNOHANG);

				last if $child <= 0;

				if (WIFEXITED($?))
					{
					# The $child process actually exited.
					# my $exit_code = ($? >> 8);  # if you're interested

					$s->{status}->child_exits($child);
					}
				else
					{
					# The $child process temporarily stopped due to some other
					# condition (suspension, SIGSTOP).  I've tested SIGSTOP
					# and SIGCONT and haven't made this condition happen, but
					# the Perl Cookbook says we should check WIFEXITED so
					# that's what I did.
					}
				}

			$s->{signal}->put_child(0);
			}

		my $client_socket;
		my $remote_addr = accept($client_socket, $server_socket);

		last if $s->{signal}->get_interrupt;
			# INT or TERM signal:  Exit immediately.

		if (!$remote_addr)
			{
			print STDERR "error in accept : $!\n" if !$s->{signal}->get_child;
			next;
			}

		# Received new inbound connection.  Fork a handler process if we
		# have the capacity.

		if ($s->{status}->num_children >= $opt->{max_children})
			{
			close($client_socket);
			next;
			}

		my $child = fork;

		if (!defined $child)
			{
			# Too many processes.
			print STDERR "fork error: $!\n";
			close($client_socket);
			}
		elsif ($child != 0)
			{
			# This is the parent process.
			$s->{status}->child_enters($child);
			close($client_socket);
			}
		else
			{
			# This is the child process.
			close($server_socket);
			$s->run_client($client_socket);
			close($client_socket);

			exit;
			}
		}

	close($server_socket);

	# Now send a TERM signal to all the children to terminate them.

	kill 'TERM', $s->{status}->children;

	return;
	}

# Interact with the client until done.
#
# This routine runs in its own process, implementing sensible timeouts and
# properly trapping signals including interrupt.

sub run_client
	{
	my $s = shift;
	my $client_socket = shift;

	my $client = Loom::Sloop::Client->new($client_socket,
		$s->{status},$s->{signal});

	my $opt = $s->{config}->options;
	my $module = Loom::Load->new->require($opt->{module});
	my $arena = { top => $s->{top}, client => $client };

	$module->new($arena)->respond;

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
