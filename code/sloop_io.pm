use strict;
use signal;
use sloop_status;

# The application uses these functions to communicate with the remote client
# process that connected to the server.

my $g_client_socket;
my $g_beg_time;
my $g_max_life;
my $g_min_life;
my $g_exiting;

sub sloop_io_init
	{
	die if defined $g_client_socket;

	$g_client_socket = shift;

	$g_beg_time = time;
	$g_max_life = 600;
	$g_min_life = 10;

	$g_exiting = 0;

	return;
	}

# Calculate the limit on our life span based on the current number of child
# processes running.  The more free slots there are, the longer we are allowed
# to live.

# LATER note that we check this every time the client calls "receive" -- even
# when it's reading headers 128 bytes at a time.  Maybe we should check it
# every 10 seconds at most.

# LATER you might consider allowing clients to stay connected indefinitely
# as long as that does not cause any problem.  Perhaps these 10 minute
# timeouts are the source of those mysterious disconnects we sometimes see.

sub sloop_check_lifespan
	{
	my ($ppid,$num_children,$max_children) = sloop_info();

	my $elapse = time - $g_beg_time;

	my $free_slots = $max_children - $num_children;
	my $cur_life = int($g_max_life * ($free_slots / $max_children));

	$cur_life = $g_min_life if $cur_life < $g_min_life;

	my $remain_life = $cur_life - $elapse;

	if ($remain_life <= 0)
		{
		# This process has exceeded its maximum life span.
		$g_exiting = 1;
		}

	return;
	}

# Receive data from the client, storing the data in the buffer.  Return the
# number of bytes read.
#
# The exiting flag will become true if the server is shutting down for any
# reason, e.g. the remote end disconnects, the server is shut down with an
# interrupt, the client has exceeded its lifespan, or a system error occurs.

sub sloop_receive
	{
	my $buffer = \shift;   # reference to buffer string
	my $max_read = shift;

	die if !defined $max_read;

	while (1)
		{
		# LATER 1231 I can't make this exit condition happen.  Perhaps a new
		# signal handler for the child process?  Because the child is forked,
		# it's probably just inheriting the parent's memory image.  Perhaps
		# the child should reset the signal handler.

		$g_exiting = 1 if signal_get_interrupt();
		return 0 if $g_exiting;

		sloop_check_lifespan();
		return 0 if $g_exiting;

		signal_put_child(0);
		signal_put_alarm(0);

		alarm(10);

		# Read bytes from the socket onto the end of the buffer.
		my $num_read = sysread $g_client_socket, $$buffer, $max_read,
			length($$buffer);

		alarm(0);

		if (!defined $num_read)
			{
			# No data available.

			if (signal_get_alarm())
				{
				# Ignore alarm signal (timeout on read).
				}
			elsif (signal_get_child())
				{
				# Ignore child exit signal.
				}
			else
				{
				# Some kind of rare error, for example:
				#    Connection reset by peer
				#    Interrupted system call

				$g_exiting = 1;
				return 0;
				}
			}
		elsif ($num_read == 0)
			{
			# The remote client process disconnected.
			$g_exiting = 1;
			return 0;
			}
		elsif ($num_read < 0)
			{
			# This probably cannot happen.
			$g_exiting = 1;
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

sub sloop_send
	{
	my $data = shift;

	return if !defined $data;

	my $timeout = 30;
		# I think this is more than enough time even for massive responses.

	alarm($timeout);
	send $g_client_socket, $data, 0;
	alarm(0);

	if (signal_get_alarm())
		{
		# Timeout on send, let's exit.
		$g_exiting = 1;
		}

	return;
	}

# Set a flag to disconnect from the client.
sub sloop_disconnect
	{
	$g_exiting = 1;
	return;
	}

sub sloop_exiting
	{
	return $g_exiting;
	}

return 1;
