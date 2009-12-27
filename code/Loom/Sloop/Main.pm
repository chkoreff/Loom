package Loom::Sloop::Main;
use strict;
use Getopt::Long;
use Loom::File;
use Loom::Strq;
use POSIX "sys_wait_h";  # for the WNOHANG constant
use Socket;

# Sloop:  forking server loop
#
# References:
# http://www.unix.org.ua/orelly/perl/prog/ch06_02.htm#PERL2-CH-6-SECT-2.4.1
# http://www.unix.com.ua/orelly/perl/cookbook/ch16_20.htm
# http://www.unix.org.ua/orelly/perl/cookbook/ch17_03.htm

my $g_child = 0;
my $g_interrupt = 0;
my $g_alarm = 0;

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
		$g_alarm = 1;
		}
	elsif ($signal eq "INT" || $signal eq "TERM")
		{
		$g_interrupt = 1;
		}
	}

# Create a new Sloop server object.
#
# The $TOP is the top-level directory of the server executable.  The server
# locates all its code libraries and persistent data relative to $TOP.
#
# The new Sloop server reads its configuration data from the data/conf/sloop
# file:
#
#   module $module
#   port $port
#   ip $ip
#   no_error_log
#
# The $port is the port where the server listens for inbound connections.
#
# The $ip is optional and specifies the IP address where the server listens.
# The default is "127.0.0.1" (localhost), which is usually what you want.
# You may pass in a specific IP address, or "*" to mean INADDR_ANY (listen on
# any address).
#
# The $module is the name of the Perl module which handles all the application
# logic.  When the Sloop server receives a new client connection, it creates
# an instance of the module as follows:
#
#   my $handler = $module->new($s->{TOP});
#
# It then interacts with the $handler using the handler's "put" and "get"
# routines.  When the server needs a response from the handler, it calls:
#
#   my $response = $handler->get;
#
# If $response is undef, it means the handler wants to disconnect, so the
# client connection is terminated.
#
# If $response is "" (the null string), it means that the handler needs more
# data from the client before it can return a response.
#
# If $response is not the null string, it means that the handler wants to send
# that data directly back to the client.
#
# When the server receives data from the client and wants to push it into the
# handler, it calls:
#
#   $handler->put($data);
#
# If $data is undef, it means that the client disconnected from the server.
#
# If $data is "" (the null string), it means that the client needs more data
# from the server before it can produce any more data itself.  However, this
# should never happen in this version of the server code.  If we did implement
# it, it would represent some kind of timeout condition.  But right now we're
# handling all timeout conditions here as the equivalent of a disconnect.
#
# If $data is not the null string, then it represents a chunk of data received
# from the client.  The handler should absorb this data and condition any
# future responses to "get" accordingly.

sub new
	{
	my $class = shift;
	my $TOP = shift;

	my $s = bless({},$class);

	$s->{TOP} = $TOP;
	$s->{error_log} = "$s->{TOP}/data/run/error_log";
	$s->{host_ip} = "127.0.0.1";  # default to localhost
	$s->{max_children} = 128;     # default

	# Read sloop config file.

	my $file = Loom::File->new("$s->{TOP}/data/conf/sloop");
	$file->read;

	while (1)
		{
		my $line = $file->line;
		last if !defined $line;

		next if $line =~ /^\s*$/ || $line =~ /^#/;
			# ignore blank lines and comments

		my $cmd = Loom::Strq->new->parse($line);
		my $verb = $cmd->[0];

		if ($verb eq "module")
			{
			$s->{module} = $cmd->[1];
			}
		elsif ($verb eq "ip")
			{
			# default is 127.0.0.1 (localhost)
			# "ip *" means listen on any IP (INADDR_ANY)

			$s->{host_ip} = $cmd->[1];
			}
		elsif ($verb eq "port")
			{
			$s->{host_port} = $cmd->[1];
			}
		elsif ($verb eq "no_error_log")
			{
			$s->{error_log} = "";
			}
		elsif ($verb eq "max_children")
			{
			$s->{max_children} = $cmd->[1];
			}
		}

	$file->release;

	die "missing module in data/conf/sloop\n" if !defined $s->{module};
	die "missing port in data/conf/sloop\n" if !defined $s->{host_port};

	# Load the handler module into memory.

	my $filename = $s->{module};
	$filename =~ s/::/\//g;
	$filename .= ".pm";
	require $filename;

	$g_child = 0;
	$g_interrupt = 0;

	return $s;
	}

sub run
	{
	my $s = shift;

	select(STDERR); $| = 1;
	select(STDOUT); $| = 1;

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

	# Stop server if already running.

	return if !$s->stop_server;

	# Start server if desired.

	return if !$do_start;

	$s->start_server;
	}

# Set up the error log and call the main server loop.  Also keep track of the
# process id in a file so it can be terminated easily.

sub start_server
	{
	my $s = shift;

	my $error_log = $s->{error_log};
	$error_log = "" if !defined $error_log;

	if ($error_log ne "" && $error_log ne "-")
		{
		open(STDERR, ">>$error_log") or die $!;
		chmod(0600,$error_log);
		}

	my $pid_file = Loom::File->new("$s->{TOP}/data/run/pid");
	$pid_file->create_file;

	$pid_file->put("$$ 0 $s->{max_children}\n");
	$pid_file->release;

	$s->server_loop;

	$pid_file->put("");
	}

# Stop the currently running server process, making sure it is actually gone
# from the "ps" listing before returning.  That's the only way to guarantee
# that the listening socket is fully released, allowing us to restart the
# server immediately without getting a "bind: Address already in use" error.
# Return false if the process fails to exit after waiting 2 minutes.

sub stop_server
	{
	my $s = shift;

	my ($curr_pid) = $s->get_server_info;
	return 1 if $curr_pid eq "";

	system("kill $curr_pid");

	my $beg_time = time();
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

		my $time = time();
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

# Main server loop.  Listen for incoming connections and handle them.  Continue
# doing this until the process receives an interrupt in the form of a TERM or
# INT signal.

sub server_loop
	{
	my $s = shift;

	my $host_port = $s->{host_port};
	my $host_ip = $s->{host_ip};

	for my $signal (qw(CHLD HUP PIPE TERM INT ALRM))
		{
		$SIG{$signal} = \&catch_signal;
		}

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

	# Set up a hash of all child process ids.

	$s->{children} = {};

	# Accept and process connections.

	while (1)
		{
		my $client_socket;
		my $remote_addr = accept($client_socket, $server_socket);

		if ($g_interrupt)
			{
			# INT or TERM signal:  Exit immediately.
			last;
			}
		elsif ($g_child)
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

					delete $s->{children}->{$child};
					$s->update_num_children;
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

			$g_child = 0;
			}
		elsif (!$remote_addr)
			{
			print STDERR "error in accept : $!\n";
			}
		else
			{
			# Received new inbound connection.  Fork a handler process if we
			# have the capacity.

			my $num_children = scalar keys %{$s->{children}};

			if ($num_children >= $s->{max_children})
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

				$s->{children}->{$child} = 1;
				$s->update_num_children;

				close($client_socket);
				}
			else
				{
				# This is the child process.

				close($server_socket);
				$s->run_client($client_socket);

				exit;
				}
			}
		}

	close($server_socket);

	# Now send a TERM signal to all the children to terminate them.

	kill 'TERM', keys %{$s->{children}};

	return;
	}

sub get_server_info
	{
	my $s = shift;

	my $text = Loom::File->new("$s->{TOP}/data/run/pid")->get;
	$text = "" if !defined $text;

	chomp $text;

	my ($pid,$num_children,$max_children) = split(" ",$text);
	$pid = "" if !defined $pid;
	$num_children = 0 if !defined $num_children;
	$max_children = 1 if !defined $max_children;
	return ($pid,$num_children,$max_children);
	}

sub update_num_children
	{
	my $s = shift;

	my $num_children = scalar keys %{$s->{children}};

	Loom::File->new("$s->{TOP}/data/run/pid")->put(
		"$$ $num_children $s->{max_children}\n");

	return;
	}

# Interact with the client until done.
#
# This routine runs in its own process, implementing sensible timeouts and
# properly trapping signals including interrupt.  The routine creates an
# instance of the handler module and interacts with it using "put" and "get".

sub run_client
	{
	my $s = shift;
	my $client_socket = shift;

	$s->{client_socket} = $client_socket;

	$s->{max_life} = 600;
	$s->{min_life} = 10;

	$s->{beg_time} = time();
	$s->{exiting} = 0;

	my $handler = $s->{module}->new($s->{TOP});

	while (1)
		{
		my $output = $handler->get;

		if (!defined $output)
			{
			# Server disconnects.
			last;
			}
		elsif ($output eq "")
			{
			# Server needs more data.
			my $input = $s->receive_message;
			$handler->put($input);
			}
		else
			{
			$s->send_message($output);
			}

		last if $s->{exiting};
		}

	close($s->{client_socket});
	delete $s->{client_socket};

	return;
	}

# Receive a message from the client.  Return the message if any, or undef if
# the server is exiting for any reason.  The {exiting} flag will become true
# if either the remote end disconnects or the server is shut down with an
# interrupt.

sub receive_message
	{
	my $s = shift;

	my $data;

	while (1)
		{
		$data = "";

		$s->{exiting} = 1 if $g_interrupt;
		last if $s->{exiting};

		$s->check_lifespan;
		last if $s->{exiting};

		$g_child = 0;
		$g_alarm = 0;

		# Read at most one megabyte of data at a time.

		alarm(10);
		my $num_read = sysread $s->{client_socket}, $data, 1048576, 0;
		alarm(0);

		if (!defined $num_read)
			{
			# No data available.

			if ($g_alarm)
				{
				# Alarm signal (timeout on read).

				next;
				}
			elsif ($g_child)
				{
				# A child process exited.  Ignore.

				next;
				}
			else
				{
				# Some kind of rare error, for example:
				#    Connection reset by peer
				#    Interrupted system call

				$s->{exiting} = 1;
				}
			}
		elsif ($num_read == 0)
			{
			# The remote client process disconnected.
			$s->{exiting} = 1;
			}
		elsif ($num_read < 0)
			{
			# This probably cannot happen.
			$s->{exiting} = 1;
			}
		else
			{
			# We read some data from the client ($num_read bytes).
			}

		# At this point we either read data or we're exiting.  End the loop.

		last;
		}

	return if $s->{exiting};
	return $data;
	}

# Send a message back to client.  We wrap a timer around this call too, just in
# case the remote client process causes us to block indefinitely, perhaps by
# stubbornly neglecting to receive data.

sub send_message
	{
	my $s = shift;
	my $data = shift;

	my $timeout = 30;
		# I think this is more than enough time even for massive
		# responses.

	alarm($timeout);
	send $s->{client_socket}, $data, 0;
	alarm(0);

	if ($g_alarm)
		{
		# Timeout on send, let's exit.
		$s->{exiting} = 1;
		}
	
	return;
	}

# Calculate the limit on our life span based on the current number of child
# processes running.  The more free slots there are, the longer we are allowed
# to live.

sub check_lifespan
	{
	my $s = shift;

	my ($ppid,$num_children,$max_children) = $s->get_server_info;

	my $elapse = time() - $s->{beg_time};

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
