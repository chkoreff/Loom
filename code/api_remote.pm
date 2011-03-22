use strict;
use context;
use web;

# Get the $url and return the response from the server as a context.  Die if
# there's any problem with the connection.

# LATER give it same signature as api_respond, i.e. the input should be a
# context as well and we should translate it into the url.

sub api_remote_respond
	{
	my $url = shift;

	return op_read_kv(op_new(),get_url($url));
	}

return 1;
