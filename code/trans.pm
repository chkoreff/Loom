use strict;
use file;

=pod

=head1 NAME

Transaction buffer

=cut

my $g_dir;
my $g_new_val;
my $g_old_val;
my $g_size;

sub trans_init
	{
	my $dir = shift;

	if (defined $g_dir && $g_size != 0)
		{
		print STDERR "ERROR: Tried to change transaction directory while\n";
		print STDERR "a transaction was in progress.\n";
		print STDERR "   old dir ".file_full_path($g_dir)."\n";
		print STDERR "   new dir ".file_full_path($dir)."\n";
		die;
		}

	$g_dir = $dir;
	trans_cancel();
	return;
	}

sub trans_get
	{
	my $key = shift;

	die if !defined $key;

	my $val = $g_new_val->{$key};
	return $val if defined $val;

	$val = $g_old_val->{$key};
	return $val if defined $val;

	$val = file_get_by_name($g_dir,$key);

	$g_old_val->{$key} = $val;
	$g_size += length($val) if defined $val;
	return $val;
	}

sub trans_put
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

sub trans_size
	{
	return $g_size;
	}

sub trans_cancel
	{
	$g_old_val = {};
	$g_new_val = {};
	$g_size = 0;
	return;
	}

sub trans_commit
	{
	my $ok = file_update($g_dir,$g_new_val,$g_old_val);
	trans_cancel();
	return $ok;
	}

return 1;
