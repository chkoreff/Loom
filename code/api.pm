use strict;
use api_archive;
use api_grid;

# This routine takes a context argument and runs the API function from that.

sub api_respond
	{
	my $op = shift;

	my $function = op_get($op,"function");

	if ($function eq "grid")
		{
		api_grid_respond($op);
		}
	elsif ($function eq "archive")
		{
		api_archive_respond($op);
		}
	else
		{
		op_put($op,"error_function","unknown");
		}

	return $op;
	}

return 1;
