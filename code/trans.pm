package trans;
use strict;
use file;

# Transaction buffer

my $g_dir;
my $g_new_val;
my $g_old_val;
my $g_size;

sub start
	{
	my $dir = shift;

	if (defined $g_dir && $g_size != 0)
		{
		print STDERR "ERROR: Tried to change transaction directory while\n";
		print STDERR "a transaction was in progress.\n";
		print STDERR "   old dir ".file::full_path($g_dir)."\n";
		print STDERR "   new dir ".file::full_path($dir)."\n";
		die;
		}

	$g_dir = $dir;
	cancel();
	return;
	}

sub get
	{
	my $key = shift;

	die if !defined $key;

	my $val = $g_new_val->{$key};
	return $val if defined $val;

	$val = $g_old_val->{$key};
	return $val if defined $val;

	$val = file::get_by_name($g_dir,$key);

	$g_old_val->{$key} = $val;
	$g_size += length($val) if defined $val;
	return $val;
	}

sub put
	{
	my $key = shift;
	my $val = shift;

	die if !defined $key || ref($key) ne "";
	die if !defined $val || ref($val) ne "";

	my $old_len = 0;
	$old_len = length($g_new_val->{$key}) if defined $g_new_val->{$key};

	$val = "".$val; # prepend null to force numbers to be stored as strings
	$g_new_val->{$key} = $val;

	$g_size += length($val) - $old_len;
	return;
	}

# Return the current size (memory footprint) of the transaction.  This is used
# to enforce an upper bound on memory usage, avoiding one possible Denial of
# Service attack.

# LATER also restrict the number of updated keys to about 512 to avoid trying
# to lock too many files

sub size
	{
	return $g_size;
	}

sub cancel
	{
	$g_old_val = {};
	$g_new_val = {};
	$g_size = 0;
	return;
	}

sub commit
	{
	my $ok = file::update($g_dir,$g_new_val,$g_old_val);
	cancel();
	return $ok;
	}

return 1;
