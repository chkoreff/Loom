use strict;
use file;
use sloop_config;
use sloop_top;

my $g_children;  # hash of all child process ids
my $g_rundir;

sub sloop_status_init
	{
	die if defined $g_children;

	my $top = sloop_top();
	$g_rundir = file_child($top,"data/run");
	file_restrict($g_rundir);

	$g_children = {};

	return;
	}

sub sloop_status_start
	{
	sloop_update_num_children();

	if (sloop_config("use_error_log"))
		{
		my $error_log = file_full_path(file_child($g_rundir,"error_log"));
		open(STDERR, ">>$error_log") or die $!;
		chmod(0600,$error_log);
		}

	return;
	}

sub sloop_status_stop
	{
	file_put_by_name($g_rundir,"pid","");
	return;
	}

# Return information about the running sloop server:
#   ($pid,$num_children,$max_children)

sub sloop_info
	{
	my $text = file_get_by_name($g_rundir,"pid");
	chomp $text;

	my ($pid,$num_children,$max_children) = split(" ",$text);
	$pid = "" if !defined $pid;
	$num_children = 0 if !defined $num_children;
	$max_children = 1 if !defined $max_children;

	return ($pid,$num_children,$max_children);
	}

# Return the list of child process ids.
sub sloop_children
	{
	return keys %$g_children;
	}

# Return the number of child client processes.
sub sloop_num_children
	{
	return scalar sloop_children();
	}

sub sloop_update_num_children
	{
	my $num_children = sloop_num_children();
	my $max_children = sloop_config("max_children");

	file_put_by_name($g_rundir,"pid","$$ $num_children $max_children\n");
	return;
	}

sub sloop_child_enters
	{
	my $child = shift;  # process id

	$g_children->{$child} = 1;
	sloop_update_num_children();
	return;
	}

sub sloop_child_exits
	{
	my $child = shift;  # process id

	delete $g_children->{$child};
	sloop_update_num_children();
	return;
	}

return 1;
