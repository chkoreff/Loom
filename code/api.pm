package api;
use strict;
use api_archive;
use api_grid;
use context;

# This routine takes a context argument and runs the API function from that.

sub respond
	{
	my $op = shift;

	my $function = context::get($op,"function");

	if ($function eq "grid")
		{
		api_grid::respond($op);
		}
	elsif ($function eq "archive")
		{
		api_archive::respond($op);
		}
	else
		{
		context::put($op,"error_function","unknown");
		}

	return $op;
	}

return 1;
