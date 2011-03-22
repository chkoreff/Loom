use strict;
use array;
use file;
use process;
use random;
use sloop_top;
use trans;

my $g_count;
my $g_delay;
my $g_trace_test_file;
my $g_show_final;

# I find that using 3 locations is pretty good.  Using 2 locations is boring,
# and using more than 3 locations results in less contention.

sub test_file_locations
	{
	return [qw(A B C)];

	#return [qw(A B C D E F)];
	#return [qw(A B)];
	#return [qw(A/a/../1 B/b/../2/../../../Q)];  # too far up

	#return [qw(A/a/../1 7/b/../2/../../Q)];
		# This is weird but OK.  It just normalizes to A/1 and Q.

	#return [qw(A /tmp/B)];
		# This doesn't fool the file module.  It just normalizes to A and
		# tmp/B.
	}

sub test_file_run_child
	{
	my $child_no = shift;
	my $seed = shift;

	die if !defined $seed;
	srand($seed);

	my $locs = test_file_locations();
	shuffle($locs);

	my $key_orig = $locs->[0];
	my $key_dest = $locs->[1];

	print "$$ child $child_no begin $key_orig $key_dest\n"
		if $g_trace_test_file;

	sleep(1);
		# If you have a lot of processes, the sleep will allow them all to be
		# created before they start doing their thing.  That creates more
		# opportunities for contention.

	my $amount = 1;

	while (1)
		{
		my $val_orig = trans_get($key_orig);
		$val_orig = 0 if $val_orig eq "";

		my $val_dest = trans_get($key_dest);
		$val_dest = 0 if $val_dest eq "";

		$val_orig -= $amount;
		$val_dest += $amount;

		$val_orig = "" if $val_orig == 0;
		$val_dest = "" if $val_dest == 0;

		trans_put($key_orig,$val_orig);
		trans_put($key_dest,$val_dest);

		print "$$ child $child_no attempt "
			."$key_orig:$val_orig "
			."$key_dest:$val_dest\n" if $g_trace_test_file;

		my $ok = trans_commit();

		last if $ok;

		print "$$ child $child_no try again\n" if $g_trace_test_file;
		}

	print "$$ child $child_no done\n" if $g_trace_test_file;

	return;
	}

sub test_file_spawn_children
	{
	for my $child_no (1 .. $g_count)
		{
		my $seed = int rand(1000000);

		my $child = fork();

		if (defined $child && $child == 0)
			{
			test_file_run_child($child_no,$seed);
			exit;
			}

		if (!defined $child)
			{
			print STDERR "Too many children! (Only spawned ".($child_no-1).")\n";
			return 0;
			}
		}

	return 1;
	}

sub test_file_run
	{
	$g_count = shift;
	$g_delay = shift;  # if negative, use the default delay
	$g_trace_test_file = shift;
	$g_show_final = shift;

	$g_delay = 100000 if $g_delay < 0;

	# Seed the random number generator.  If you don't seed it, you can get
	# repeatable sequences, which might be useful in some cases.
	#
	# When we spawn each child process, we call "rand" to generate a seed
	# for that process.  Then the child calls "srand" with the given seed.  
	#
	# Strangely, if we *don't* do that, and we happen to call "rand" here in
	# the parent process (which we normally don't), it seems to destroy any
	# entropy when calling rand in the child processes.  The stress test is
	# not shaken up enough, and you see all the child processes banging away
	# on just two specific locations.  Very bizarre and intricate behavior
	# there, but easily avoided by just calling srand in each child.

	srand( random_ulong() );

	my $TOP = file_full_path(sloop_top());

	my $dir_test = file_new("$TOP/test");

	my $dir_data = file_child($dir_test,"test_file");

	file_create_path($dir_data);
	file_remove_tree($dir_data);

	file_create_dir($dir_data);
	file_restrict($dir_data);

	if (file_type($dir_data) ne "d")
		{
		print STDERR <<EOM;
Could not create the data directory.
EOM
		exit(1);
		}

	# Start a transaction with the data directory.
	trans_init($dir_data);

	# Insert a deliberate delay into the file module if requested.
	file_update_set_test_delay($g_delay) if $g_delay > 0;

	# Now let's spawn all the children and wait for them to finish.

	test_file_spawn_children();
	wait_children();

	# Display the final values, check for integrity, and clean up.

	print "\nFinal values:\n" if $g_show_final;
	my $sum = 0;
	my $locs = test_file_locations();
	for my $name (@$locs)
		{
		my $file = file_child($dir_data,$name);

		my $val = file_get_content($file);

		if ($g_show_final)
			{
			my $q_val = defined $val ? $val : "undef";
			my $q_name = file_local_path($file);
			print "$q_name : $q_val\n";
			}

		$sum += $val if defined $val && $val ne "";
		}

	print "sum = $sum\n" if $g_show_final;

	if ($sum == 0)
		{
		# Success!
		file_remove_tree($dir_data);
		file_remove_dir($dir_test);  # remove empty test dir if possible
		return 0;
		}
	else
		{
		# Uh oh ... failure!
		print STDERR <<EOM;

!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!! CHECKSUM ERROR !!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!

EOM
		exit(3);
		}
	}

return 1;
