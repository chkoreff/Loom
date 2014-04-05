package sloop_status;
use strict;
use file;
use sloop_config;
use sloop_top;

my $g_children;  # hash of all child process ids
my $g_rundir;

sub init
	{
	die if defined $g_children;

	my $top = sloop_top::dir();
	$g_rundir = file::child($top,"data/run");
	file::restrict($g_rundir);

	$g_children = {};

	return;
	}

sub start
	{
	update_num_children();

	if (sloop_config::get("use_error_log"))
		{
		my $error_log = file::full_path(file::child($g_rundir,"error_log"));
		open(STDERR, ">>$error_log") or die $!;
		chmod(0600,$error_log);
		}

	return;
	}

sub stop
	{
	file::put_by_name($g_rundir,"pid","");
	return;
	}

# Return information about the running sloop server:
#   ($pid,$num_children,$max_children)

sub info
	{
	my $text = file::get_by_name($g_rundir,"pid");
	chomp $text;

	my ($pid,$num_children,$max_children) = split(" ",$text);
	$pid = "" if !defined $pid;
	$num_children = 0 if !defined $num_children;
	$max_children = 1 if !defined $max_children;

	return ($pid,$num_children,$max_children);
	}

# Return the list of child process ids.
sub children
	{
	return keys %$g_children;
	}

# Return the number of child client processes.
sub num_children
	{
	return scalar children();
	}

sub update_num_children
	{
	my $num_children = num_children();
	my $max_children = sloop_config::get("max_children");

	file::put_by_name($g_rundir,"pid","$$ $num_children $max_children\n");
	return;
	}

sub child_enters
	{
	my $child = shift;  # process id

	$g_children->{$child} = 1;
	update_num_children();
	return;
	}

sub child_exits
	{
	my $child = shift;  # process id

	delete $g_children->{$child};
	update_num_children();
	return;
	}

return 1;
