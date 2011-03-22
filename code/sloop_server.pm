use strict;
use file;
use signal;
use sloop_client;
use sloop_config;
use sloop_io;
use sloop_status;
use sloop_top;
use POSIX "sys_wait_h";  # for the WNOHANG constant
use Socket;

# LATER 0331 do we get a catchable signal when shutting down this machine?
# I noticed that the pid file wasn't getting cleared.

=pod

=head1 NAME

sloop_listen - Listen for inbound connections and fork handler process

The main server loop.  Listen for incoming connections and handle them.
Continue doing this until the process sees a TERM or INT interrupt signal.

=head1 REFERENCES

=item http://www.unix.org.ua/orelly/perl/prog/ch06_02.htm#PERL2-CH-6-SECT-2.4.1

=item http://www.unix.com.ua/orelly/perl/cookbook/ch16_20.htm

=item http://www.unix.org.ua/orelly/perl/cookbook/ch17_03.htm

=cut

sub sloop_listen
	{
	my $host_port = sloop_config("host_port");
	my $host_ip = sloop_config("host_ip");
	my $max_children = sloop_config("max_children");

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
		if (signal_get_child())
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

					sloop_child_exits($child);
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

			signal_put_child(0);
			}

		my $client_socket;
		my $remote_addr = accept($client_socket, $server_socket);

		last if signal_get_interrupt();
			# INT or TERM signal:  Exit immediately.

		if (!$remote_addr)
			{
			print STDERR "error in accept : $!\n" if !signal_get_child();
			next;
			}

		# Received new inbound connection.  Fork a handler process if we
		# have the capacity.

		if (sloop_num_children() >= $max_children)
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
			sloop_child_enters($child);
			close($client_socket);
			}
		else
			{
			# This is the child process.
			close($server_socket);
			sloop_io_init($client_socket);
			sloop_client_respond();
			close($client_socket);

			exit;
			}
		}

	close($server_socket);

	# Now send a TERM signal to all the children to terminate them.

	kill 'TERM', sloop_children();

	return;
	}

# Stop the currently running server process, making sure it is actually gone
# from the "ps" listing before returning.  That's the only way to guarantee
# that the listening socket is fully released, allowing us to restart the
# server immediately without getting a "bind: Address already in use" error.
# Return false if the process fails to exit after waiting 2 minutes.

sub sloop_stop
	{
	my ($curr_pid) = sloop_info();
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

# Start the server running in the background and loop until terminated.

sub sloop_start
	{
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

	sloop_status_start();
	sloop_listen();
	sloop_status_stop();

	return;
	}

# Run the listener loop.  The listener accepts inbound connections and forks a
# child process to handle them.

sub sloop_respond
	{
	my $do_start = shift;

	signal_init();
	sloop_status_init();

	return if !sloop_stop();  # Stop the server if already running.
	sloop_start() if $do_start;

	return;
	}

return 1;
