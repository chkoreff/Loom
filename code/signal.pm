package signal;
use strict;

# Catch operating system signals reliably.

my $g_alarm = 0;
my $g_child = 0;
my $g_interrupt = 0;

sub signal_catch
	{
	my $signal = shift;

	# Reinstall the handler first thing in case of unreliable signals.

	$SIG{$signal} = \&signal_catch;

	if ($signal eq "CHLD")
		{
		$g_child = 1;
		}
	elsif ($signal eq "ALRM")
		{
		$g_alarm = 1
		}
	elsif ($signal eq "INT" || $signal eq "TERM")
		{
		$g_interrupt = 1;
		}
	}

sub init
	{
	$g_alarm = 0;
	$g_child = 0;
	$g_interrupt = 0;

	for my $signal (qw(CHLD HUP PIPE TERM INT ALRM))
		{
		$SIG{$signal} = \&signal_catch;
		}

	return;
	}

# Get the status of some important signals.
sub get_alarm { return $g_alarm }
sub get_child { return $g_child }
sub get_interrupt { return $g_interrupt }

# Put the status of some important signals.  Use 0 to clear a signal.
sub put_alarm { $g_alarm = shift; }
sub put_child { $g_child = shift; }
sub put_interrupt { $g_interrupt = shift; }

return 1;
