use strict;
use LWP::UserAgent;

# NOTE: You must install Crypt::SSLeay in order for https to work.

# We maintain a table of user agents, one per process, in case your code does
# a fork.  That's because the LWP and SSL code gets a little confused if every
# process shares the same user agent object.  I discovered this when writing
# an API stress test that spawns several processes.

my $g_user_agent_table = {};

sub user_agent
	{
	my $pid = $$;
	my $ua = $g_user_agent_table->{$pid};

	if (!defined $ua)
		{
		# Set the number of connections to cache for "Keep Alive".
		$ua = LWP::UserAgent->new("keep_alive",20);

		# Set the number of seconds to wait before aborting connection.
		$ua->timeout(30);
		}

	return $ua;
	}

# Get the the $url and return the response from the server as text.  Die if
# there's any problem with the connection.
sub get_url
	{
	my $url = shift;

	my $response = user_agent()->get($url);

	return $response->decoded_content if $response->is_success;

	die $response->status_line;
	}

return 1;
