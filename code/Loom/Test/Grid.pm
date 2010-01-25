package Loom::Test::Grid;
use strict;

use Getopt::Long;
use Loom::Context;
use Loom::Digest::SHA256;
use Loom::ID;
use Loom::Object::Loom::API;
use Loom::Test::Random;

# LATER  For now we test with a memory-based db.  Soon we'll point the loom
# server to a temporary test directory and run the qualification there.  We'll
# also do a nondeterministic test suite with multiple processes.

sub new
	{
	my $class = shift;
	my $arena = shift;

	my $s = bless({},$class);
	$s->{arena} = $arena;
	$s->{id} = Loom::ID->new;
	$s->{hasher} = Loom::Digest::SHA256->new;
	return $s;
	}

sub run
	{
	my $s = shift;

	$s->get_options;
	$s->configure;
	$s->qualify_grid;
	$s->qualify_random;
	$s->other_tests;

	print "All tests succeeded.\n" if !$s->{arena}->{embedded};
	}

sub get_options
	{
	my $s = shift;

	$s->{trace} = 0;

	if ($s->{arena}->{embedded})
		{
		$s->{trace} = $s->{arena}->{trace};
		return;
		}

	my $opt = {};

	my $ok = GetOptions($opt, "t");

	if (!$ok)
		{
		my $prog_name = $0;
		$prog_name =~ s#.*/##;

		print STDERR <<EOM;
Usage: $prog_name [-t]

  -t  : show detailed trace output
EOM
		exit(2);
		}

	$s->{trace} = $opt->{t};
	}

sub configure
	{
	my $s = shift;

	# LATER make it run on real file system
	# LATER make a true "stress test" with hundreds of processes

	$s->{loom} = Loom::Object::Loom::API->new(Loom::Context->new);
	}

sub qualify_random
	{
	my $s = shift;
	Loom::Test::Random->new->run;
	return;
	}

sub qualify_grid
	{
	my $s = shift;

	$s->{sym} = {};

	$s->put_sym("zero",         "00000000000000000000000000000000");
	$s->put_sym("type_usage",   "00000000000000000000000000000000");
	$s->put_sym("type_spangle", "0aa98de118780b1fbefe3d11894e0acf");
	$s->put_sym("issue_usage",  "affd5e70e0b07c8511dfd39a5ba6f8f7");

	$s->put_sym("A", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");
	$s->put_sym("B", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb");
	$s->put_sym("C", "cccccccccccccccccccccccccccccccc");
	$s->put_sym("D", "dddddddddddddddddddddddddddddddd");
	$s->put_sym("E", "4f439ed9347eb07c2e4788e3023fab0c");

	# Starting with a brand new empty grid here.

	# Buy the zero location of asset type zero (usage tokens), paying for
	# the operation at location zero.  This is the first operation in any
	# new grid.

	$s->check(
		$s->buy("type_usage","zero","zero"),
		status => "success",
		value => "-1",
		usage_balance => "",
		);

	# Now take a look and see that there's a -1 there.  At this point, the
	# zero location is the issuer location for usage tokens.  This is an
	# insecure state to be in, and we'll change it shortly.

	$s->check(
		$s->touch("type_usage","zero"),
		status => "success",
		value => "-1",
		);

	# First let's buy the truly secret location issue_usage.  That's
	# what we really want to use as the issuer location for asset type zero.

	$s->check(
		$s->buy("type_usage","issue_usage","zero"),
		status => "success",
		value => "0",
		usage_balance => "-1",
		);

	# Change the issuer location from zero to issue_usage.  At this
	# point we've commandeered the grid, establishing ourself as the only
	# entity who can issue usage tokens.

	$s->check(
		$s->issuer("type_usage","zero","issue_usage"),
		status => "success",
		value_orig => "0",
		value_dest => "-1",
		);

	# Now play around a bit.

	# Issue 3 usage tokens to location zero.

	$s->check(
		$s->move("type_usage",3,"issue_usage","zero"),
		status => "success",
		value_orig => "-4",
		value_dest => "3",
		);

	# Now redeem them back.

	$s->check(
		$s->move("type_usage",-3,"issue_usage","zero"),
		status => "success",
		value_orig => "-1",
		value_dest => "0",
		);

	# Issue them again.

	$s->check(
		$s->move("type_usage",3,"issue_usage","zero"),
		status => "success",
		value_orig => "-4",
		value_dest => "3",
		);

	# Try to redeem too many back.

	$s->check(
		$s->move("type_usage",-4,"issue_usage","zero"),
		status => "fail",
		value_orig => "-4",
		value_dest => "3",
		error_qty => "insufficient",
		);

	# Redeem them back properly.

	$s->check(
		$s->move("type_usage",-3,"issue_usage","zero"),
		status => "success",
		value_orig => "-1",
		value_dest => "0",
		);

	# Buy usage location E.  Because we pay for this one directly from the
	# issuer location, so no tokens actually move.

	$s->check(
		$s->buy("type_usage","E","issue_usage"),
		status => "success",
		value => "0",
		usage_balance => "-1",
		);

	# Move 500000 tokens to E.

	$s->check(
		$s->move("type_usage",500000,"issue_usage","E"),
		status => "success",
		value_orig => "-500001",
		value_dest => "500000",
		);

	# Touch E just to see.

	$s->check(
		$s->touch("type_usage","E"),
		status => "success",
		value => "500000",
		);

	# Now do a Look by hash.

	$s->check(
		$s->look("type_usage",$s->type_loc_hash("type_usage","E")),
		status => "success",
		value => "500000",
		);

	# E becomes issuer of type_spangle.

	$s->check(
		$s->buy("type_spangle","zero","E"),
		status => "success",
		value => "-1",
		usage_balance => "499999",
		);

	# Buy location A.

	$s->check(
		$s->buy("type_spangle","A","E"),
		status => "success",
		value => "0",
		usage_balance => "499998",
		);

	# Change issuer from zero to A.

	$s->check(
		$s->issuer("type_spangle","zero","A"),
		status => "success",
		value_orig => "0",
		value_dest => "-1",
		);

	# Try moving 0 units from A to A.  This fails because the locations are
	# identical.

	$s->check(
		$s->move("type_spangle",0,"A","A"),
		status => "fail",
		value_orig => "-1",
		value_dest => "-1",
		error_qty => "insufficient",  # LATER : more specific msg here
		);

	# Try buying location A again.  This fails because the location is
	# occupied (already bought).

	$s->check(
		$s->buy("type_spangle","A","E"),
		status => "fail",
		value => "-1",
		error_loc => "occupied",
		);

	# Now buy locations B and C.

	$s->check(
		$s->buy("type_spangle","B","E"),
		status => "success",
		value => "0",
		usage_balance => "499997",
		);

	$s->check(
		$s->buy("type_spangle","C","E"),
		status => "success",
		value => "0",
		usage_balance => "499996",
		);

	# Move 1 spangle from A to B.  This issues a brand new unit.

	$s->check(
		$s->move("type_spangle",1,"A","B"),
		status => "success",
		value_orig => "-2",
		value_dest => "1",
		);

	# Try moving 3 spangles from B to C, which fails.

	$s->check(
		$s->move("type_spangle",3,"B","C"),
		status => "fail",
		value_orig => "1",
		value_dest => "0",
		error_qty => "insufficient",
		);

	# Move 1 spangle from B to C.

	$s->check(
		$s->move("type_spangle",1,"B","C"),
		status => "success",
		value_orig => "0",
		value_dest => "1",
		);

	# Move the spangle back.

	$s->check(
		$s->move("type_spangle",-1,"B","C"),
		status => "success",
		value_orig => "1",
		value_dest => "0",
		);

	# Move 700 spangles from A to B.  This issues 700 new units.

	$s->check(
		$s->move("type_spangle",700,"A","C"),
		status => "success",
		value_orig => "-702",
		value_dest => "700",
		);

	# Locations identical here.
	$s->check(
		$s->move("type_spangle",600,"C","C"),
		status => "fail",
		value_orig => "700",
		value_dest => "700",
		error_qty => "insufficient",
		);
	$s->check(
		$s->move("type_spangle",920,"C","C"),
		status => "fail",
		value_orig => "700",
		value_dest => "700",
		error_qty => "insufficient",
		);

	# Try moving too much.
	$s->check(
		$s->move("type_spangle",701,"C","B"),
		status => "fail",
		value_orig => "700",
		value_dest => "1",
		error_qty => "insufficient",
		);

	# Now move it all.
	$s->check(
		$s->move("type_spangle",700,"C","B"),
		status => "success",
		value_orig => "0",
		value_dest => "701",
		);

	# Try moving 1 unit back from C into issuer location A.  This fails
	# because there is not anything at C.
	$s->check(
		$s->move("type_spangle",-1,"A","C"),
		status => "fail",
		value_orig => "-702",
		value_dest => "0",
		error_qty => "insufficient",
		);

	# Try issuing so many more units of A that we exceed the maximum liability
	# possible:  -2^128 = -170141183460469231731687303715884105728 .

	$s->check(
		$s->move("type_spangle",
			"170141183460469231731687303715884105727",
			"A","C"),
		status => "fail",
		value_orig => "-702",
		value_dest => "0",
		error_qty => "insufficient",
		);

	# Temporarily change issuer to C.

	$s->check(
		$s->issuer("type_spangle","A","C"),
		status => "success",
		value_orig => "0",
		value_dest => "-702",
		);

	# Note here that you *cannot* change the issuer location by moving the
	# negative quantity around:  a Move operation *always* preserves the
	# signs of the original location values.

	$s->check(
		$s->move("type_spangle","-702","C","B"),
		status => "fail",
		value_orig => "-702",
		value_dest => "701",
		error_qty => "insufficient",
		);

	# Temporarily change issuer to B.  First we have to clear out B though.

	$s->check(
		$s->move("type_spangle","701","B","C"),
		status => "success",
		value_orig => "0",
		value_dest => "-1",
		);

	$s->check(
		$s->issuer("type_spangle","C","B"),
		status => "success",
		value_orig => "0",
		value_dest => "-1",
		);

	# Now let's move some big numbers around.

	$s->check(
		$s->move("type_spangle",
			"170141183460469231731687303715884105727",
			"B","C"),
		status => "success",
		value_orig => "-170141183460469231731687303715884105728",
		value_dest => "170141183460469231731687303715884105727",
		);

	# This fails because it would underflow.
	$s->check(
		$s->move("type_spangle",
			"1",
			"B","C"),
		status => "fail",
		value_orig => "-170141183460469231731687303715884105728",
		value_dest => "170141183460469231731687303715884105727",
		error_qty => "insufficient",
		);

	# Now move the big amount back.
	$s->check(
		$s->move("type_spangle",
			"-170141183460469231731687303715884105727",
			"B","C"),
		status => "success",
		value_orig => "-1",
		value_dest => "0",
		);

	# Move it out again.
	$s->check(
		$s->move("type_spangle",
			"170141183460469231731687303715884105727",
			"B","C"),
		status => "success",
		value_orig => "-170141183460469231731687303715884105728",
		value_dest => "170141183460469231731687303715884105727",
		);

	# Try moving the lowest negative amount.
	$s->check(
		$s->move("type_spangle",
			"-170141183460469231731687303715884105728",
			"B","C"),
		status => "fail",
		value_orig => "-170141183460469231731687303715884105728",
		value_dest => "170141183460469231731687303715884105727",
		error_qty => "insufficient",
		);

	# Move a fairly big number around successfully.

	$s->check(
		$s->move("type_spangle",
			"170141183460469231731687303715884105720",
			"C","A"),
		status => "success",
		value_orig => "7",
		value_dest => "170141183460469231731687303715884105720",
		);

	# Now redeem a sizeable chunk back to issuer location.

	$s->check(
		$s->move("type_spangle",
			"70141183460469231731687303715884105720",
			"A","B"),
		status => "success",
		value_orig => "100000000000000000000000000000000000000",
		value_dest => "-100000000000000000000000000000000000008",
		);

	# Try moving too much.
	$s->check(
		$s->move("type_spangle",
			"100000000000000000000000000000000000001",
			"A","B"),
		status => "fail",
		value_orig => "100000000000000000000000000000000000000",
		value_dest => "-100000000000000000000000000000000000008",
		error_qty => "insufficient",
		);

	# Move 1.
	$s->check(
		$s->move("type_spangle",
			"1",
			"A","B"),
		status => "success",
		value_orig => "99999999999999999999999999999999999999",
		value_dest => "-100000000000000000000000000000000000007",
		);

	# More moves.
	$s->check(
		$s->move("type_spangle",
			"3",
			"C","B"),
		status => "success",
		value_orig => "4",
		value_dest => "-100000000000000000000000000000000000004",
		);

	$s->check(
		$s->move("type_spangle",
			"2",
			"C","A"),
		status => "success",
		value_orig => "2",
		value_dest => "100000000000000000000000000000000000001",
		);

	$s->check(
		$s->move("type_spangle",
			"100000000000000000000000000000000000001",
			"A","B"),
		status => "success",
		value_orig => "0",
		value_dest => "-3",
		);

	$s->check(
		$s->move("type_spangle",
			"3",
			"C","A"),
		status => "fail",
		value_orig => "2",
		value_dest => "0",
		error_qty => "insufficient",
		);

	$s->check(
		$s->move("type_spangle",
			"2",
			"C","A"),
		status => "success",
		value_orig => "0",
		value_dest => "2",
		);

	$s->check(
		$s->move("type_spangle",
			"2",
			"A","B"),
		status => "success",
		value_orig => "0",
		value_dest => "-1",
		);

	# Change issuer from B to A.

	$s->check(
		$s->issuer("type_spangle","B","A"),
		status => "success",
		value_orig => "0",
		value_dest => "-1",
		);

	# Incorrectly try to change issuer from C to B.

	$s->check(
		$s->issuer("type_spangle","C","B"),
		status => "fail",
		value_orig => "0",
		value_dest => "0",
		error_qty => "insufficient",
		);

	# Change issuer from A to B.

	$s->check(
		$s->issuer("type_spangle","A","B"),
		status => "success",
		value_orig => "0",
		value_dest => "-1",
		);

	# Incorrectly try to change issuer from B to B itself!

	$s->check(
		$s->issuer("type_spangle","B","B"),
		status => "fail",
		value_orig => "-1",
		value_dest => "-1",
		error_qty => "insufficient",
		);

	# Change issuer from B to C.

	$s->check(
		$s->issuer("type_spangle","B","C"),
		status => "success",
		value_orig => "0",
		value_dest => "-1",
		);

	# Move some spangles out for testing.
	$s->check(
		$s->move("type_spangle",
			"2900",
			"C","A"),
		status => "success",
		value_orig => "-2901",
		value_dest => "2900",
		);

	$s->check(
		$s->move("type_spangle",
			"2100",
			"C","B"),
		status => "success",
		value_orig => "-5001",
		value_dest => "2100",
		);

	# Test some strange quantities on Move operation.

	# Here's a valid one, testing with leading zeroes.

	$s->check(
		$s->move("type_spangle",
			"000000000000000000000000000000000000000",
			"A","B"),
		status => "success",
		value_orig => "2900",
		value_dest => "2100",
		);

	# Too many leading zeroes.  A Loom int value can only contain 39 digits.

	$s->check(
		$s->move("type_spangle",
			"0000000000000000000000000000000000000000",
			"A","B"),
		status => "fail",
		value_orig => "",  # you don't even get these values
		value_dest => "",  # if qty invalid
		error_qty => "not_valid_int",
		);

	# A negative zero, not allowed.

	$s->check(
		$s->move("type_spangle",
			"-0",
			"A","B"),
		status => "fail",
		error_qty => "not_valid_int",
		);

	# Strange negative zero, not allowed.

	$s->check(
		$s->move("type_spangle",
			"-000000000000000000000000000000000000000",
			"A","B"),
		status => "fail",
		error_qty => "not_valid_int",
		);

	# These numbers (max and min) are syntatically valid, even though the
	# move is not allowd in these particular cases.

	$s->check(
		$s->move("type_spangle",
			"170141183460469231731687303715884105727",
			"A","B"),
		status => "fail",
		value_orig => "2900",
		value_dest => "2100",
		error_qty => "insufficient",
		);

	$s->check(
		$s->move("type_spangle",
			"-170141183460469231731687303715884105728",
			"A","B"),
		status => "fail",
		value_orig => "2900",
		value_dest => "2100",
		error_qty => "insufficient",
		);

	# Now try some numbers that are out of range.

	$s->check(
		$s->move("type_spangle",
			"-170141183460469231731687303715884105729",
			"A","B"),
		status => "fail",
		error_qty => "not_valid_int",
		);

	$s->check(
		$s->move("type_spangle",
			"-170141183460469231731687303715884105730",
			"A","B"),
		status => "fail",
		error_qty => "not_valid_int",
		);

	$s->check(
		$s->move("type_spangle",
			"170141183460469231799999999999999999999",
			"A","B"),
		status => "fail",
		error_qty => "not_valid_int",
		);

	$s->check(
		$s->move("type_spangle",
			"999999999999999999999999999999999999999",
			"A","B"),
		status => "fail",
		error_qty => "not_valid_int",
		);

	$s->check(
		$s->move("type_spangle",
			"-999999999999999999999999999999999999999",
			"A","B"),
		status => "fail",
		error_qty => "not_valid_int",
		);

	$s->check(
		$s->move("type_spangle",
			"-99999999999999999999999999999999999999999999",
			"A","B"),
		status => "fail",
		error_qty => "not_valid_int",
		);

	$s->check(
		$s->move("type_spangle",
			"170141183460469231731687303715884105999",
			"A","B"),
		status => "fail",
		error_qty => "not_valid_int",
		);

	$s->check(
		$s->move("type_spangle",
			"170141183460469231731687303715884105729",
			"A","B"),
		status => "fail",
		error_qty => "not_valid_int",
		);

	$s->check(
		$s->move("type_spangle",
			"170141183460469231731687303715884105728",
			"A","B"),
		status => "fail",
		error_qty => "not_valid_int",
		);

	$s->check(
		$s->move("type_spangle",
			"99999999999999999999999999999999999999999999",
			"A","B"),
		status => "fail",
		error_qty => "not_valid_int",
		);

	# Try to sell a non-empty location.
	$s->check(
		$s->sell("type_spangle","A","E"),
		status => "fail",
		error_loc => "non_empty",
		value => "2900",
		);

	# Move all the stuff from A back to issuer location C.
	$s->check(
		$s->move("type_spangle",
			"2900",
			"A","C"),
		status => "success",
		value_orig => "0",
		value_dest => "-2101",
		);

	# Now sell the empty location A.
	$s->check(
		$s->sell("type_spangle","A","E"),
		status => "success",
		value => "0",
		usage_balance => "499997",
		);

	# Try to move something from an empty location.
	$s->check(
		$s->move("type_spangle",
			"2900",
			"A","C"),
		status => "fail",
		value_orig => "",
		value_dest => "-2101",
		);

	# Try to move something to an empty location.
	$s->check(
		$s->move("type_spangle",
			"30",
			"C","A"),
		status => "fail",
		value_orig => "-2101",
		value_dest => "",
		);

	# Move all the stuff from B back to issuer location C.
	$s->check(
		$s->move("type_spangle",
			"2100",
			"B","C"),
		status => "success",
		value_orig => "0",
		value_dest => "-1",
		);

	# Sell the empty location B.
	$s->check(
		$s->sell("type_spangle","B","E"),
		status => "success",
		value => "0",
		usage_balance => "499998",
		);

	# We try to sell the issuer location C which has a -1, but we get an
	# error because we can only sell a -1 when it's at location 0.

	$s->check(
		$s->sell("type_spangle","C","E"),
		status => "fail",
		error_loc => "non_empty",
		);

	# Erroneously try to change the issuer location from an empty location.

	$s->check(
		$s->issuer("type_spangle","D","C"),
		status => "fail",
		value_orig => "",
		value_dest => "-1",
		);

	# Erroneously try to change the issuer location to an empty location.

	$s->check(
		$s->issuer("type_spangle","C","D"),
		status => "fail",
		value_orig => "-1",
		value_dest => "",
		);

	# First change the issuer location back to location 0.

	$s->check(
		$s->issuer("type_spangle","C","zero"),
		status => "success",
		value_orig => "0",
		value_dest => "-1",
		);

	# Now sell location 0.

	$s->check(
		$s->sell("type_spangle","zero","E"),
		status => "success",
		value => "-1",
		usage_balance => "499999",
		);

	# Now let's test the case where we try to sell a usage location and
	# receive the refund back in the same location itself!  Clearly that
	# is not allowed, since if we did sell the location, there would be
	# no place to put the refund.

	# Buy another location D so we can evacuate E.
	$s->check(
		$s->buy("type_usage","D","E"),
		status => "success",
		value => "0",
		usage_balance => "499998",
		);

	# Move all the tokens from E to D.
	$s->check(
		$s->move("type_usage","499998","E","D"),
		status => "success",
		value_orig => "0",
		value_dest => "499998",
		);

	# Now E is empty.  Let's try to sell that location, receiving the refund
	# right at the same place.  It will not be allowed.
	$s->check(
		$s->sell("type_usage","E","E"),
		status => "fail",
		error_loc => "cannot_refund",
		);
	}

sub other_tests
	{
	my $s = shift;

	$s->test_id("f" x 32, 1);
	$s->test_id("f" x 32 . "\n", 0);
	$s->test_id("f" x 31 . "\n", 0);
	$s->test_id("f" x 31, 0);

	$s->test_hash("f" x 64, 1);
	$s->test_hash("f" x 64 . "\n", 0);
	}

sub test_id
	{
	my $s = shift;
	my $id = shift;
	my $expect = shift;

	my $result = $s->{id}->valid_id($id) ? 1 : 0;

	if ($expect != $result)
		{
		print STDERR "ERROR:  '$id' result=$result expect=$expect\n";
		die;
		}
	return;
	}

sub test_hash
	{
	my $s = shift;
	my $id = shift;
	my $expect = shift;

	my $result = $s->{id}->valid_hash($id) ? 1 : 0;

	if ($expect != $result)
		{
		print STDERR "ERROR:  '$id' result=$result expect=$expect\n";
		die;
		}
	return;
	}

sub buy
	{
	my $s = shift;
	my $type = shift;
	my $loc = shift;
	my $usage = shift;

	return $s->do_api(
		function => "grid",
		action => "buy",
		type => $s->get_sym($type),
		loc => $s->get_sym($loc),
		usage => $s->get_sym($usage),
		);
	}

sub sell
	{
	my $s = shift;
	my $type = shift;
	my $loc = shift;
	my $usage = shift;

	return $s->do_api(
		function => "grid",
		action => "sell",
		type => $s->get_sym($type),
		loc => $s->get_sym($loc),
		usage => $s->get_sym($usage),
		);
	}

sub issuer
	{
	my $s = shift;
	my $type = shift;
	my $orig = shift;
	my $dest = shift;

	return $s->do_api(
		function => "grid",
		action => "issuer",
		type => $s->get_sym($type),
		orig => $s->get_sym($orig),
		dest => $s->get_sym($dest),
		);
	}

sub touch
	{
	my $s = shift;
	my $type = shift;
	my $loc = shift;

	return $s->do_api(
		function => "grid",
		action => "touch",
		type => $s->get_sym($type),
		loc => $s->get_sym($loc),
		);
	}

sub look
	{
	my $s = shift;
	my $type = shift;
	my $hash = shift;

	return $s->do_api(
		function => "grid",
		action => "look",
		type => $s->get_sym($type),
		hash => $s->get_sym($hash),
		);
	}

sub move
	{
	my $s = shift;
	my $type = shift;
	my $qty = shift;
	my $orig = shift;
	my $dest = shift;

	return $s->do_api(
		function => "grid",
		action => "move",
		type => $s->get_sym($type),
		qty => $qty,
		orig => $s->get_sym($orig),
		dest => $s->get_sym($dest),
		);
	}

sub do_api
	{
	my $s = shift;

	my $op = Loom::Context->new(@_);

	$s->{loom}->run_op($op);

	if ($s->{trace})
		{
		print $op->write_kv;
		print "\n";
		}

	return $op;
	}

sub check
	{
	my $s = shift;
	my $op = shift;

	while (@_)
		{
		my $key = shift;
		my $val_expect = shift;

		my $val_real = $op->get($key);

		if ($val_real ne $val_expect)
			{
			my $op_str = $op->write_kv;

			print STDERR <<EOM;
ERROR in operation:
$op_str
ERROR in key:
  key     : $key
  expect  : $val_expect
  got     : $val_real

EOM
			my @caller = caller(0);
			my $filename = $caller[1];
			my $lineno = $caller[2];

			die "unexpected result at $filename line $lineno\n";
			}
		}
	}

sub type_loc_hash
	{
	my $s = shift;
	my $type = shift;
	my $loc = shift;

	return unpack("H*",$s->{hasher}->sha256(
		pack("H*",$s->get_sym($type)).
		pack("H*",$s->get_sym($loc))));
	}

sub get_sym
	{
	my $s = shift;
	my $sym = shift;

	my $val = $s->{sym}->{$sym};
	$val = $sym if !defined $val;
	return $val;
	}

sub put_sym
	{
	my $s = shift;
	my $sym = shift;
	my $val = shift;

	die if $s->{id}->valid_id($sym);
	die if $s->{id}->valid_hash($sym);

	$s->{sym}->{$sym} = $val;
	}

return 1;

__END__

# Copyright 2007 Patrick Chkoreff
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions
# and limitations under the License.
