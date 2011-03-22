use strict;
use c_quote;
use trans;

# This module maps keys used in the old GNU database into corresponding path
# names now used directly on the file system.  This enables all the DB code
# to work the same as always without change.  It is also used to port the old
# data over to the file system (see port_data).
#
# Note how we handle issuer keys (grid_I) specially.  In the GNU DB we stored
# the issuer hash as a packed 32 byte binary value.  On the file system I
# decided to store it in readable hexadecimal instead of binary.  So for those
# keys we map the value in and out.

sub loom_db_hex_path
	{
	my $hex_loc = shift;

	die if length($hex_loc) < 4;

	my $level1 = substr($hex_loc,0,2);
	my $level2 = substr($hex_loc,2,2);

	my $path = "$level1/$level2/$hex_loc";
	return $path;
	}

sub loom_db_map_key
	{
	my $key = shift;

	if ($key =~ /^grid_V/)
		{
		# Grid value.
		die if length($key) != 54;

		my $type = unpack("H*",substr($key,6,16));
		die if length($type) != 32;

		my $hash = unpack("H*",substr($key,22,32));
		die if length($hash) != 64;

		my $path_type = loom_db_hex_path($type);
		my $path_hash = loom_db_hex_path($hash);

		return "grid/$path_type/V/$path_hash";
		}
	elsif ($key =~ /^grid_I/)
		{
		# Grid issuer location.
		die if length($key) != 22;

		my $type = unpack("H*",substr($key,6,16));
		die if length($type) != 32;

		my $path_type = loom_db_hex_path($type);
		return "grid/$path_type/I";
		}
	elsif ($key =~ /^ar_C/)
		{
		# Archive value.
		die if length($key) != 36;

		my $hash2 = unpack("H*",substr($key,4,32));
		die if length($hash2) != 64;

		my $path_hash2 = loom_db_hex_path($hash2);
		return "archive/$path_hash2";
		}
	else
		{
		# Unrecognized key.
		my $q_key = c_quote($key);
		print STDERR "ERROR: $q_key\n";
		die;
		}
	}

sub loom_db_get
	{
	my $key = shift;

	my $val = trans_get(loom_db_map_key($key));

	if ($key =~ /^grid_I/)
		{
		$val = pack("H*",$val) if length($val) == 64;
		}

	return $val;
	}

sub loom_db_put
	{
	my $key = shift;
	my $val = shift;

	if ($key =~ /^grid_I/)
		{
		$val = unpack("H*",$val) if length($val) == 32;
		}

	trans_put(loom_db_map_key($key),$val);
	return;
	}

return 1;
