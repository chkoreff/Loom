use strict;
use api;
use context;
use file;
use id;
use sha256;
use sloop_top;
use trans;

my $g_sym;
my $g_trace_test_grid;

sub test_grid_get_sym
	{
	my $sym = shift;

	my $val = $g_sym->{$sym};
	$val = $sym if !defined $val;
	return $val;
	}

sub test_grid_put_sym
	{
	my $sym = shift;
	my $val = shift;

	die if valid_id($sym);
	die if valid_hash($sym);

	$g_sym->{$sym} = $val;
	return;
	}

sub test_grid_type_loc_hash
	{
	my $type = shift;
	my $loc = shift;

	return unpack("H*",sha256(
		pack("H*",test_grid_get_sym($type)).
		pack("H*",test_grid_get_sym($loc))));
	}

sub test_grid_do_api
	{
	my $op = op_new(@_);

	api_respond($op);

	trans_commit();

	if ($g_trace_test_grid)
		{
		print op_write_kv($op);
		print "\n";
		}

	return $op;
	}

sub test_grid_buy
	{
	my $type = shift;
	my $loc = shift;
	my $usage = shift;

	return test_grid_do_api(
		"function","grid",
		"action","buy",
		"type",test_grid_get_sym($type),
		"loc",test_grid_get_sym($loc),
		"usage",test_grid_get_sym($usage),
		);
	}

sub test_grid_sell
	{
	my $type = shift;
	my $loc = shift;
	my $usage = shift;

	return test_grid_do_api(
		"function","grid",
		"action","sell",
		"type",test_grid_get_sym($type),
		"loc",test_grid_get_sym($loc),
		"usage",test_grid_get_sym($usage),
		);
	}

sub test_grid_issuer
	{
	my $type = shift;
	my $orig = shift;
	my $dest = shift;

	return test_grid_do_api(
		"function","grid",
		"action","issuer",
		"type",test_grid_get_sym($type),
		"orig",test_grid_get_sym($orig),
		"dest",test_grid_get_sym($dest),
		);
	}

sub test_grid_touch
	{
	my $type = shift;
	my $loc = shift;

	return test_grid_do_api(
		"function","grid",
		"action","touch",
		"type",test_grid_get_sym($type),
		"loc",test_grid_get_sym($loc),
		);
	}

sub test_grid_look
	{
	my $type = shift;
	my $hash = shift;

	return test_grid_do_api(
		"function","grid",
		"action","look",
		"type",test_grid_get_sym($type),
		"hash",test_grid_get_sym($hash),
		);
	}

sub test_grid_move
	{
	my $type = shift;
	my $qty = shift;
	my $orig = shift;
	my $dest = shift;

	return test_grid_do_api(
		"function","grid",
		"action","move",
		"type",test_grid_get_sym($type),
		"qty",$qty,
		"orig",test_grid_get_sym($orig),
		"dest",test_grid_get_sym($dest),
		);
	}

sub test_grid_check_op
	{
	my $op = shift;

	while (@_)
		{
		my $key = shift;
		my $val_expect = shift;

		my $val_real = op_get($op,$key);

		if ($val_real ne $val_expect)
			{
			my $op_str = op_write_kv($op);

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

	return;
	}

sub test_grid_sequence
	{
	$g_sym = {};

	test_grid_put_sym("zero",         "00000000000000000000000000000000");
	test_grid_put_sym("type_usage",   "00000000000000000000000000000000");
	test_grid_put_sym("type_spangle", "0aa98de118780b1fbefe3d11894e0acf");
	test_grid_put_sym("issue_usage",  "affd5e70e0b07c8511dfd39a5ba6f8f7");

	test_grid_put_sym("A", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");
	test_grid_put_sym("B", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb");
	test_grid_put_sym("C", "cccccccccccccccccccccccccccccccc");
	test_grid_put_sym("D", "dddddddddddddddddddddddddddddddd");
	test_grid_put_sym("E", "4f439ed9347eb07c2e4788e3023fab0c");

	# Starting with a brand new empty grid here.

	# Try buying a location in the initial state with a usage location other
	# than zero.

	test_grid_check_op(
		test_grid_buy("type_usage","zero","A"),
		"status","fail",
		"usage_balance","",
		);

	# Buy the zero location of asset type zero (usage tokens), paying for
	# the operation at location zero.  This is the first operation in any
	# new grid.

	test_grid_check_op(
		test_grid_buy("type_usage","zero","zero"),
		"status","success",
		"value","-1",
		"usage_balance","",
		);

	# Now take a look and see that there's a -1 there.  At this point, the
	# zero location is the issuer location for usage tokens.  This is an
	# insecure state to be in, and we'll change it shortly.

	test_grid_check_op(
		test_grid_touch("type_usage","zero"),
		"status","success",
		"value","-1",
		);

	# First let's buy the truly secret location issue_usage.  That's
	# what we really want to use as the issuer location for asset type zero.

	test_grid_check_op(
		test_grid_buy("type_usage","issue_usage","zero"),
		"status","success",
		"value","0",
		"usage_balance","-1",
		);

	# Change the issuer location from zero to issue_usage.  At this
	# point we've commandeered the grid, establishing ourself as the only
	# entity who can issue usage tokens.

	test_grid_check_op(
		test_grid_issuer("type_usage","zero","issue_usage"),
		"status","success",
		"value_orig","0",
		"value_dest","-1",
		);

	# Now play around a bit.

	# Issue 3 usage tokens to location zero.

	test_grid_check_op(
		test_grid_move("type_usage",3,"issue_usage","zero"),
		"status","success",
		"value_orig","-4",
		"value_dest","3",
		);

	# Now redeem them back.

	test_grid_check_op(
		test_grid_move("type_usage",-3,"issue_usage","zero"),
		"status","success",
		"value_orig","-1",
		"value_dest","0",
		);

	# Issue them again.

	test_grid_check_op(
		test_grid_move("type_usage",3,"issue_usage","zero"),
		"status","success",
		"value_orig","-4",
		"value_dest","3",
		);

	# Try to redeem too many back.

	test_grid_check_op(
		test_grid_move("type_usage",-4,"issue_usage","zero"),
		"status","fail",
		"value_orig","-4",
		"value_dest","3",
		"error_qty","insufficient",
		);

	# Redeem them back properly.

	test_grid_check_op(
		test_grid_move("type_usage",-3,"issue_usage","zero"),
		"status","success",
		"value_orig","-1",
		"value_dest","0",
		);

	# Try buying location E with a vacant usage location A.

	test_grid_check_op(
		test_grid_buy("type_usage","E","A"),
		"status","fail",
		);

	# Buy usage location E.  Because we pay for this one directly from the
	# issuer location, no tokens actually move.

	test_grid_check_op(
		test_grid_buy("type_usage","E","issue_usage"),
		"status","success",
		"value","0",
		"usage_balance","-1",
		);

	# Move 500000 tokens to E.

	test_grid_check_op(
		test_grid_move("type_usage",500000,"issue_usage","E"),
		"status","success",
		"value_orig","-500001",
		"value_dest","500000",
		);

	# Touch E just to see.

	test_grid_check_op(
		test_grid_touch("type_usage","E"),
		"status","success",
		"value","500000",
		);

	# Now do a Look by hash.

	test_grid_check_op(
		test_grid_look("type_usage",test_grid_type_loc_hash("type_usage","E")),
		"status","success",
		"value","500000",
		);

	# E becomes issuer of type_spangle.

	test_grid_check_op(
		test_grid_buy("type_spangle","zero","E"),
		"status","success",
		"value","-1",
		"usage_balance","499999",
		);

	# Buy location A.

	test_grid_check_op(
		test_grid_buy("type_spangle","A","E"),
		"status","success",
		"value","0",
		"usage_balance","499998",
		);

	# Change issuer from zero to A.

	test_grid_check_op(
		test_grid_issuer("type_spangle","zero","A"),
		"status","success",
		"value_orig","0",
		"value_dest","-1",
		);

	# Try moving 0 units from A to A.  This fails because the locations are
	# identical.

	test_grid_check_op(
		test_grid_move("type_spangle",0,"A","A"),
		"status","fail",
		"value_orig","-1",
		"value_dest","-1",
		"error_qty","insufficient",  # LATER : more specific msg here
		);

	# Try buying location A again.  This fails because the location is
	# occupied (already bought).

	test_grid_check_op(
		test_grid_buy("type_spangle","A","E"),
		"status","fail",
		"value","-1",
		"error_loc","occupied",
		);

	# Now buy locations B and C.

	test_grid_check_op(
		test_grid_buy("type_spangle","B","E"),
		"status","success",
		"value","0",
		"usage_balance","499997",
		);

	test_grid_check_op(
		test_grid_buy("type_spangle","C","E"),
		"status","success",
		"value","0",
		"usage_balance","499996",
		);

	# Move 1 spangle from A to B.  This issues a brand new unit.

	test_grid_check_op(
		test_grid_move("type_spangle",1,"A","B"),
		"status","success",
		"value_orig","-2",
		"value_dest","1",
		);

	# Try moving 3 spangles from B to C, which fails.

	test_grid_check_op(
		test_grid_move("type_spangle",3,"B","C"),
		"status","fail",
		"value_orig","1",
		"value_dest","0",
		"error_qty","insufficient",
		);

	# Move 1 spangle from B to C.

	test_grid_check_op(
		test_grid_move("type_spangle",1,"B","C"),
		"status","success",
		"value_orig","0",
		"value_dest","1",
		);

	# Move the spangle back.

	test_grid_check_op(
		test_grid_move("type_spangle",-1,"B","C"),
		"status","success",
		"value_orig","1",
		"value_dest","0",
		);

	# Move 700 spangles from A to B.  This issues 700 new units.

	test_grid_check_op(
		test_grid_move("type_spangle",700,"A","C"),
		"status","success",
		"value_orig","-702",
		"value_dest","700",
		);

	# Locations identical here.
	test_grid_check_op(
		test_grid_move("type_spangle",600,"C","C"),
		"status","fail",
		"value_orig","700",
		"value_dest","700",
		"error_qty","insufficient",
		);
	test_grid_check_op(
		test_grid_move("type_spangle",920,"C","C"),
		"status","fail",
		"value_orig","700",
		"value_dest","700",
		"error_qty","insufficient",
		);

	# Try moving too much.
	test_grid_check_op(
		test_grid_move("type_spangle",701,"C","B"),
		"status","fail",
		"value_orig","700",
		"value_dest","1",
		"error_qty","insufficient",
		);

	# Now move it all.
	test_grid_check_op(
		test_grid_move("type_spangle",700,"C","B"),
		"status","success",
		"value_orig","0",
		"value_dest","701",
		);

	# Try moving 1 unit back from C into issuer location A.  This fails
	# because there is not anything at C.
	test_grid_check_op(
		test_grid_move("type_spangle",-1,"A","C"),
		"status","fail",
		"value_orig","-702",
		"value_dest","0",
		"error_qty","insufficient",
		);

	# Try issuing so many more units of A that we exceed the maximum liability
	# possible:  -2^128 = -170141183460469231731687303715884105728 .

	test_grid_check_op(
		test_grid_move("type_spangle",
			"170141183460469231731687303715884105727",
			"A","C"),
		"status","fail",
		"value_orig","-702",
		"value_dest","0",
		"error_qty","insufficient",
		);

	# Temporarily change issuer to C.

	test_grid_check_op(
		test_grid_issuer("type_spangle","A","C"),
		"status","success",
		"value_orig","0",
		"value_dest","-702",
		);

	# Note here that you *cannot* change the issuer location by moving the
	# negative quantity around:  a Move operation *always* preserves the
	# signs of the original location values.

	test_grid_check_op(
		test_grid_move("type_spangle","-702","C","B"),
		"status","fail",
		"value_orig","-702",
		"value_dest","701",
		"error_qty","insufficient",
		);

	# Temporarily change issuer to B.  First we have to clear out B though.

	test_grid_check_op(
		test_grid_move("type_spangle","701","B","C"),
		"status","success",
		"value_orig","0",
		"value_dest","-1",
		);

	test_grid_check_op(
		test_grid_issuer("type_spangle","C","B"),
		"status","success",
		"value_orig","0",
		"value_dest","-1",
		);

	# Now let's move some big numbers around.

	test_grid_check_op(
		test_grid_move("type_spangle",
			"170141183460469231731687303715884105727",
			"B","C"),
		"status","success",
		"value_orig","-170141183460469231731687303715884105728",
		"value_dest","170141183460469231731687303715884105727",
		);

	# This fails because it would underflow.
	test_grid_check_op(
		test_grid_move("type_spangle",
			"1",
			"B","C"),
		"status","fail",
		"value_orig","-170141183460469231731687303715884105728",
		"value_dest","170141183460469231731687303715884105727",
		"error_qty","insufficient",
		);

	# Now move the big amount back.
	test_grid_check_op(
		test_grid_move("type_spangle",
			"-170141183460469231731687303715884105727",
			"B","C"),
		"status","success",
		"value_orig","-1",
		"value_dest","0",
		);

	# Move it out again.
	test_grid_check_op(
		test_grid_move("type_spangle",
			"170141183460469231731687303715884105727",
			"B","C"),
		"status","success",
		"value_orig","-170141183460469231731687303715884105728",
		"value_dest","170141183460469231731687303715884105727",
		);

	# Try moving the lowest negative amount.
	test_grid_check_op(
		test_grid_move("type_spangle",
			"-170141183460469231731687303715884105728",
			"B","C"),
		"status","fail",
		"value_orig","-170141183460469231731687303715884105728",
		"value_dest","170141183460469231731687303715884105727",
		"error_qty","insufficient",
		);

	# Move a fairly big number around successfully.

	test_grid_check_op(
		test_grid_move("type_spangle",
			"170141183460469231731687303715884105720",
			"C","A"),
		"status","success",
		"value_orig","7",
		"value_dest","170141183460469231731687303715884105720",
		);

	# Now redeem a sizeable chunk back to issuer location.

	test_grid_check_op(
		test_grid_move("type_spangle",
			"70141183460469231731687303715884105720",
			"A","B"),
		"status","success",
		"value_orig","100000000000000000000000000000000000000",
		"value_dest","-100000000000000000000000000000000000008",
		);

	# Try moving too much.
	test_grid_check_op(
		test_grid_move("type_spangle",
			"100000000000000000000000000000000000001",
			"A","B"),
		"status","fail",
		"value_orig","100000000000000000000000000000000000000",
		"value_dest","-100000000000000000000000000000000000008",
		"error_qty","insufficient",
		);

	# Move 1.
	test_grid_check_op(
		test_grid_move("type_spangle",
			"1",
			"A","B"),
		"status","success",
		"value_orig","99999999999999999999999999999999999999",
		"value_dest","-100000000000000000000000000000000000007",
		);

	# More moves.
	test_grid_check_op(
		test_grid_move("type_spangle",
			"3",
			"C","B"),
		"status","success",
		"value_orig","4",
		"value_dest","-100000000000000000000000000000000000004",
		);

	test_grid_check_op(
		test_grid_move("type_spangle",
			"2",
			"C","A"),
		"status","success",
		"value_orig","2",
		"value_dest","100000000000000000000000000000000000001",
		);

	test_grid_check_op(
		test_grid_move("type_spangle",
			"100000000000000000000000000000000000001",
			"A","B"),
		"status","success",
		"value_orig","0",
		"value_dest","-3",
		);

	test_grid_check_op(
		test_grid_move("type_spangle",
			"3",
			"C","A"),
		"status","fail",
		"value_orig","2",
		"value_dest","0",
		"error_qty","insufficient",
		);

	test_grid_check_op(
		test_grid_move("type_spangle",
			"2",
			"C","A"),
		"status","success",
		"value_orig","0",
		"value_dest","2",
		);

	test_grid_check_op(
		test_grid_move("type_spangle",
			"2",
			"A","B"),
		"status","success",
		"value_orig","0",
		"value_dest","-1",
		);

	# Change issuer from B to A.

	test_grid_check_op(
		test_grid_issuer("type_spangle","B","A"),
		"status","success",
		"value_orig","0",
		"value_dest","-1",
		);

	# Incorrectly try to change issuer from C to B.

	test_grid_check_op(
		test_grid_issuer("type_spangle","C","B"),
		"status","fail",
		"value_orig","0",
		"value_dest","0",
		"error_qty","insufficient",
		);

	# Change issuer from A to B.

	test_grid_check_op(
		test_grid_issuer("type_spangle","A","B"),
		"status","success",
		"value_orig","0",
		"value_dest","-1",
		);

	# Incorrectly try to change issuer from B to B itself!

	test_grid_check_op(
		test_grid_issuer("type_spangle","B","B"),
		"status","fail",
		"value_orig","-1",
		"value_dest","-1",
		"error_qty","insufficient",
		);

	# Change issuer from B to C.

	test_grid_check_op(
		test_grid_issuer("type_spangle","B","C"),
		"status","success",
		"value_orig","0",
		"value_dest","-1",
		);

	# Move some spangles out for testing.
	test_grid_check_op(
		test_grid_move("type_spangle",
			"2900",
			"C","A"),
		"status","success",
		"value_orig","-2901",
		"value_dest","2900",
		);

	test_grid_check_op(
		test_grid_move("type_spangle",
			"2100",
			"C","B"),
		"status","success",
		"value_orig","-5001",
		"value_dest","2100",
		);

	# Test some strange quantities on Move operation.

	# Here's a valid one, testing with leading zeroes.

	test_grid_check_op(
		test_grid_move("type_spangle",
			"000000000000000000000000000000000000000",
			"A","B"),
		"status","success",
		"value_orig","2900",
		"value_dest","2100",
		);

	# Too many leading zeroes.  A Loom int value can only contain 39 digits.

	test_grid_check_op(
		test_grid_move("type_spangle",
			"0000000000000000000000000000000000000000",
			"A","B"),
		"status","fail",
		"value_orig","",  # you don't even get these values
		"value_dest","",  # if qty invalid
		"error_qty","not_valid_int",
		);

	# A negative zero, not allowed.

	test_grid_check_op(
		test_grid_move("type_spangle",
			"-0",
			"A","B"),
		"status","fail",
		"error_qty","not_valid_int",
		);

	# Strange negative zero, not allowed.

	test_grid_check_op(
		test_grid_move("type_spangle",
			"-000000000000000000000000000000000000000",
			"A","B"),
		"status","fail",
		"error_qty","not_valid_int",
		);

	# These numbers (max and min) are syntatically valid, even though the
	# move is not allowd in these particular cases.

	test_grid_check_op(
		test_grid_move("type_spangle",
			"170141183460469231731687303715884105727",
			"A","B"),
		"status","fail",
		"value_orig","2900",
		"value_dest","2100",
		"error_qty","insufficient",
		);

	test_grid_check_op(
		test_grid_move("type_spangle",
			"-170141183460469231731687303715884105728",
			"A","B"),
		"status","fail",
		"value_orig","2900",
		"value_dest","2100",
		"error_qty","insufficient",
		);

	# Now try some numbers that are out of range.

	test_grid_check_op(
		test_grid_move("type_spangle",
			"-170141183460469231731687303715884105729",
			"A","B"),
		"status","fail",
		"error_qty","not_valid_int",
		);

	test_grid_check_op(
		test_grid_move("type_spangle",
			"-170141183460469231731687303715884105730",
			"A","B"),
		"status","fail",
		"error_qty","not_valid_int",
		);

	test_grid_check_op(
		test_grid_move("type_spangle",
			"170141183460469231799999999999999999999",
			"A","B"),
		"status","fail",
		"error_qty","not_valid_int",
		);

	test_grid_check_op(
		test_grid_move("type_spangle",
			"999999999999999999999999999999999999999",
			"A","B"),
		"status","fail",
		"error_qty","not_valid_int",
		);

	test_grid_check_op(
		test_grid_move("type_spangle",
			"-999999999999999999999999999999999999999",
			"A","B"),
		"status","fail",
		"error_qty","not_valid_int",
		);

	test_grid_check_op(
		test_grid_move("type_spangle",
			"-99999999999999999999999999999999999999999999",
			"A","B"),
		"status","fail",
		"error_qty","not_valid_int",
		);

	test_grid_check_op(
		test_grid_move("type_spangle",
			"170141183460469231731687303715884105999",
			"A","B"),
		"status","fail",
		"error_qty","not_valid_int",
		);

	test_grid_check_op(
		test_grid_move("type_spangle",
			"170141183460469231731687303715884105729",
			"A","B"),
		"status","fail",
		"error_qty","not_valid_int",
		);

	test_grid_check_op(
		test_grid_move("type_spangle",
			"170141183460469231731687303715884105728",
			"A","B"),
		"status","fail",
		"error_qty","not_valid_int",
		);

	test_grid_check_op(
		test_grid_move("type_spangle",
			"99999999999999999999999999999999999999999999",
			"A","B"),
		"status","fail",
		"error_qty","not_valid_int",
		);

	# Try to sell a non-empty location.
	test_grid_check_op(
		test_grid_sell("type_spangle","A","E"),
		"status","fail",
		"error_loc","non_empty",
		"value","2900",
		);

	# Move all the stuff from A back to issuer location C.
	test_grid_check_op(
		test_grid_move("type_spangle",
			"2900",
			"A","C"),
		"status","success",
		"value_orig","0",
		"value_dest","-2101",
		);

	# Now sell the empty location A.
	test_grid_check_op(
		test_grid_sell("type_spangle","A","E"),
		"status","success",
		"value","0",
		"usage_balance","499997",
		);

	# Try to move something from an empty location.
	test_grid_check_op(
		test_grid_move("type_spangle",
			"2900",
			"A","C"),
		"status","fail",
		"value_orig","",
		"value_dest","-2101",
		);

	# Try to move something to an empty location.
	test_grid_check_op(
		test_grid_move("type_spangle",
			"30",
			"C","A"),
		"status","fail",
		"value_orig","-2101",
		"value_dest","",
		);

	# Move all the stuff from B back to issuer location C.
	test_grid_check_op(
		test_grid_move("type_spangle",
			"2100",
			"B","C"),
		"status","success",
		"value_orig","0",
		"value_dest","-1",
		);

	# Sell the empty location B.
	test_grid_check_op(
		test_grid_sell("type_spangle","B","E"),
		"status","success",
		"value","0",
		"usage_balance","499998",
		);

	# We try to sell the issuer location C which has a -1, but we get an
	# error because we can only sell a -1 when it's at location 0.

	test_grid_check_op(
		test_grid_sell("type_spangle","C","E"),
		"status","fail",
		"error_loc","non_empty",
		);

	# Erroneously try to change the issuer location from an empty location.

	test_grid_check_op(
		test_grid_issuer("type_spangle","D","C"),
		"status","fail",
		"value_orig","",
		"value_dest","-1",
		);

	# Erroneously try to change the issuer location to an empty location.

	test_grid_check_op(
		test_grid_issuer("type_spangle","C","D"),
		"status","fail",
		"value_orig","-1",
		"value_dest","",
		);

	# First change the issuer location back to location 0.

	test_grid_check_op(
		test_grid_issuer("type_spangle","C","zero"),
		"status","success",
		"value_orig","0",
		"value_dest","-1",
		);

	# Now sell location 0.

	test_grid_check_op(
		test_grid_sell("type_spangle","zero","E"),
		"status","success",
		"value","-1",
		"usage_balance","499999",
		);

	# Now let's test the case where we try to sell a usage location and
	# receive the refund back in the same location itself!  Clearly that
	# is not allowed, since if we did sell the location, there would be
	# no place to put the refund.

	# Buy another location D so we can evacuate E.
	test_grid_check_op(
		test_grid_buy("type_usage","D","E"),
		"status","success",
		"value","0",
		"usage_balance","499998",
		);

	# Move all the tokens from E to D.
	test_grid_check_op(
		test_grid_move("type_usage","499998","E","D"),
		"status","success",
		"value_orig","0",
		"value_dest","499998",
		);

	# Now E is empty.  Let's try to sell that location, receiving the refund
	# right at the same place.  It will not be allowed.
	test_grid_check_op(
		test_grid_sell("type_usage","E","E"),
		"status","fail",
		"error_loc","cannot_refund",
		);

	return;
	}

# LATER detect if test program already running?  Do this for test_file too
sub test_grid_run
	{
	$g_trace_test_grid = 0;

	my $top = sloop_top();
	my $dir_test = file_child($top,"test");
	my $dir_data = file_child($dir_test,"test_grid");

	my $check_path = file_local_path($dir_data);
	die "bad test path $check_path" if $check_path ne "test/test_grid";

	file_remove_tree($dir_data);
	file_remove_dir($dir_test);  # remove empty test dir if possible

	file_create_path($dir_data);
	file_create_dir($dir_data);
	file_restrict($dir_data);

	trans_init($dir_data);

	test_grid_sequence();

	file_remove_tree($dir_data);
	file_remove_dir($dir_test);  # remove empty test dir if possible

	print "The grid test succeeded.\n" if $g_trace_test_grid;

	$g_sym = undef;

	return;
	}

return 1;
