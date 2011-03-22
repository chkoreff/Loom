use strict;

# Don't allow modules to redefine functions.
BEGIN
	{
	$SIG{__WARN__} =
		sub
		{
		my $msg = shift;
		die $msg if $msg =~ /redefine/;
		print $msg;
		};
	}

return 1;
