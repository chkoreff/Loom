use strict;
use file;
use FindBin;

my $g_top;

# Return a handle to the top-level directory for this server,  which has this
# directory structure:
#
#   code/                 # code
#   data/                 # data
#   data/app/             # application data
#   data/conf/            # configuration
#   data/run/             # run-time files
#   data/run/pid          # server process information
#   data/run/error_log    # error log

sub sloop_top
	{
	if (!defined $g_top)
		{
		# the TOP directory is one level above code.
		my $TOP = $FindBin::RealBin."/..";

		$g_top = file_new($TOP);
		file_restrict($g_top);
		}

	return $g_top;
	}

sub sloop_top_path
	{
	return file_full_path(sloop_top());
	}

return 1;
