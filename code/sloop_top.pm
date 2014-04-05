package sloop_top;
use strict;
use file;
use FindBin;

my $g_top;

# Return a handle to the top-level directory for this server, which has this
# directory structure:
#
#   code/                 # code
#   data/                 # data
#   data/app/             # application data
#   data/conf/            # configuration
#   data/run/             # run-time files
#   data/run/pid          # server process information
#   data/run/error_log    # error log

sub dir
	{
	if (!defined $g_top)
		{
		# the TOP directory is one level above code.
		my $TOP = $FindBin::RealBin."/..";

		$g_top = file::new($TOP);
		file::restrict($g_top);
		}

	return $g_top;
	}

sub path
	{
	return file::full_path(dir());
	}

return 1;
