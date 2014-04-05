package api_remote;
use strict;
use context;
use web;

# Get the $url and return the response from the server as a context.  Die if
# there's any problem with the connection.

# LATER give it same signature as api::respond, i.e. the input should be a
# context as well and we should translate it into the url.

sub respond
	{
	my $url = shift;

	return context::read_kv(context::new(),web::get_url($url));
	}

return 1;
