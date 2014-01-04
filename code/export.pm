package export;
use strict;

# SYNOPSIS:
#
# # Define a module:
# package handy;
# use export "x","y","z";  # Export these symbols.
#
# # Use the module:
# use handy;  # Imports all symbols.

sub import
	{
	shift;  # Ignore the word "export".
	my @names = @_;  # Grab all the names to export.

	# We use a closure with @names baked in.
	my $import = sub
		{
		my $from = shift;
		my $to = (caller(0))[0];
		for my $name (@names)
			{
			next if !defined $name || $name eq "";
			# Export the routine if not already defined.
			no strict;
			*{$to."::".$name} = \&{$from."::".$name}
				if !defined *{$to."::".$name};
			use strict;
			}
		};

	# Define the "import" routine in the caller.
	my $to = (caller(0))[0];
	no strict;
	*{$to."::import"} = $import;
	use strict;
	}

return 1;
