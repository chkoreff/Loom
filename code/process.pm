use strict;

# Wait for all children to finish.

sub wait_children
	{
	while (1)
		{
		my $child = waitpid(-1, 0);
		last if $child <= 0;

		# Child process $child just finished.
		}
	}

return 1;
