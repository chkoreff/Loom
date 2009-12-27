package Loom::Site::Loom::API_Grid;
use strict;
use Loom::Context;
use Loom::Digest::SHA256;
use Loom::ID;
use Loom::Int128;

my $zero = "\000" x 16;

sub new
	{
	my $class = shift;
	my $db = shift;

	my $s = bless({},$class);
	$s->{db} = $db;
	$s->{id} = Loom::ID->new;
	$s->{hasher} = Loom::Digest::SHA256->new;
	return $s;
	}

# API entry point
sub respond
	{
	my $s = shift;
	my $op = shift;

	my $action = $op->get("action");

	if ($action eq "buy")
		{
		$s->do_buy($op);
		}
	elsif ($action eq "sell")
		{
		$s->do_sell($op);
		}
	elsif ($action eq "issuer")
		{
		$s->do_issuer($op);
		}
	elsif ($action eq "touch")
		{
		$s->do_touch($op);
		}
	elsif ($action eq "look")
		{
		$s->do_look($op);
		}
	elsif ($action eq "move")
		{
		$s->do_move($op);
		}
	elsif ($action eq "scan")
		{
		$s->do_scan($op);
		}
	else
		{
		$op->put("status","fail");
		$op->put("error_action","unknown");
		}

	return;
	}

sub do_buy
	{
	my $s = shift;
	my $op = shift;

	$s->check_buy($op);
	return if $op->get("status") ne "";

	# Convert the hex strings to packed hex values for internal use.

	my $type = pack("H*",$op->get("type"));
	my $loc = pack("H*",$op->get("loc"));
	my $usage = pack("H*",$op->get("usage"));

	my $hash = $s->{hasher}->sha256($type.$loc);

	$op->put("hash",unpack("H*",$hash));

	my $val = $s->{db}->get("V$type$hash");

	$op->put("value",$val);

	if ($val ne "")
		{
		# Location is occupied:  NOT OK.
		$op->put("status","fail");
		$op->put("error_loc","occupied");
		}

	return if $op->get("status") ne "";

	# Now see if we can charge usage.

	$s->charge_usage($op,$usage,1);
	return if $op->get("status") ne "";

	if ($hash eq $s->{hasher}->sha256($type.$zero)
		&& $s->{db}->get("I$type") eq "")
		{
		# Buying issuer location for new type:  OK.
		$val = -1;
		$s->{db}->put("I$type", $hash);
		}
	else
		{
		# Buying location for existing type:  OK.
		$val = 0;
		}

	$s->{db}->put("V$type$hash", $val);
	$op->put("status","success");
	$op->put("value",$val);

	return;
	}

sub do_sell
	{
	my $s = shift;
	my $op = shift;

	$s->check_buy($op);
	return if $op->get("status") ne "";

	# Convert the hex strings to packed hex values for internal use.

	my $type = pack("H*",$op->get("type"));
	my $loc = pack("H*",$op->get("loc"));
	my $usage = pack("H*",$op->get("usage"));

	my $hash = $s->{hasher}->sha256($type.$loc);

	$op->put("hash",unpack("H*",$hash));

	my $val = $s->{db}->get("V$type$hash");

	$op->put("value",$val);

	if ($val eq "")
		{
		# Location is already vacant:  NOT OK.
		$op->put("status","fail");
		$op->put("error_loc","vacant");
		}
	elsif ($val eq "0")
		{
		# Value is zero:  OK.

		if ($type eq $zero && $loc eq $usage)
			{
			# Cannot sell a usage token location if we're trying to receive the
			# refund in that same location.

			$op->put("status","fail");
			$op->put("error_loc","cannot_refund");
			}
		}
	elsif ($val eq "-1" && $hash eq $s->{hasher}->sha256($type.$zero))
		{
		# Value is -1 and location is zero:  OK.
		# Delete the issue location tracking entry.

		$s->{db}->put("I$type", "");
		}
	else
		{
		# Location has non-empty value:  NOT OK.
		$op->put("status","fail");
		$op->put("error_loc","non_empty");
		}

	return if $op->get("status") ne "";

	# Refund the usage token and delete the location.

	$s->charge_usage($op,$usage,-1);
	return if $op->get("status") ne "";

	$s->{db}->put("V$type$hash", "");
	$op->put("status","success");

	return;
	}

sub check_buy
	{
	my $s = shift;
	my $op = shift;

	if (!$s->{id}->valid_id($op->get("type")))
		{
		$op->put("status","fail");
		$op->put("error_type","not_valid_id");
		}

	if (!$s->{id}->valid_id($op->get("loc")))
		{
		$op->put("status","fail");
		$op->put("error_loc","not_valid_id");
		}

	if (!$s->{id}->valid_id($op->get("usage")))
		{
		$op->put("status","fail");
		$op->put("error_usage","not_valid_id");
		}

	return;
	}

sub charge_usage
	{
	my $s = shift;
	my $op = shift;
	my $loc = shift;
	my $amount = shift;

	die if length($loc) != 16;

	my $bv_amount = Loom::Int128->from_dec($amount);
	die if !defined $bv_amount;

	my $usage_hash = $s->{hasher}->sha256($zero.$loc);

	my $issuer_hash = $s->{db}->get("I$zero");
	$issuer_hash = $s->{hasher}->sha256($zero.$zero) if $issuer_hash eq "";

	my $ok;

	# Save the updated usage balance.

	if ($usage_hash eq $issuer_hash)
		{
		$ok = 1;
		my $val_orig = $s->{db}->get("V$zero$usage_hash");
		$op->put("usage_balance",$val_orig);
		}
	else
		{
		$ok = $s->hash_move($op,$zero,$bv_amount,$usage_hash,$issuer_hash);
		$op->put("usage_balance",$op->get("value_orig"));
		}

	# Now clear out the value_orig and value_dest set in the hash_move
	# operation so we don't reveal the usage issuer balance.

	$op->put("value_orig","");
	$op->put("value_dest","");

	if ($ok)
		{
		}
	else
		{
		$op->put("status","fail");
		$op->put("error_usage","insufficient");
		}

	return;
	}

sub do_touch
	{
	my $s = shift;
	my $op = shift;

	if (!$s->{id}->valid_id($op->get("type")))
		{
		$op->put("status","fail");
		$op->put("error_type","not_valid_id");
		}

	if (!$s->{id}->valid_id($op->get("loc")))
		{
		$op->put("status","fail");
		$op->put("error_loc","not_valid_id");
		}

	return if $op->get("status") ne "";

	my $type = pack("H*",$op->get("type"));
	my $loc = pack("H*",$op->get("loc"));

	$op->put("hash", unpack("H*",$s->{hasher}->sha256($type.$loc)));

	$s->do_look($op);

	return;
	}

sub do_look
	{
	my $s = shift;
	my $op = shift;

	if (!$s->{id}->valid_id($op->get("type")))
		{
		$op->put("status","fail");
		$op->put("error_type","not_valid_id");
		}

	if (!$s->{id}->valid_hash($op->get("hash")))
		{
		$op->put("status","fail");
		$op->put("error_hash","not_valid_hash");
		}

	return if $op->get("status") ne "";

	my $type = pack("H*",$op->get("type"));
	my $hash = pack("H*",$op->get("hash"));

	my $val = $s->{db}->get("V$type$hash");

	if ($val eq "")
		{
		$op->put("status","fail");
		$op->put("error_loc","vacant");
		}

	return if $op->get("status") ne "";

	$op->put("status","success");
	$op->put("value",$val);

	return;
	}

sub do_issuer
	{
	my $s = shift;
	my $op = shift;

	if (!$s->{id}->valid_id($op->get("type")))
		{
		$op->put("status","fail");
		$op->put("error_type","not_valid_id");
		}

	if (!$s->{id}->valid_id($op->get("orig")))
		{
		$op->put("status","fail");
		$op->put("error_orig","not_valid_id");
		}

	if (!$s->{id}->valid_id($op->get("dest")))
		{
		$op->put("status","fail");
		$op->put("error_dest","not_valid_id");
		}

	return if $op->get("status") ne "";
	die if $op->get("status") ne "";

	my $type = pack("H*",$op->get("type"));
	my $orig = pack("H*",$op->get("orig"));
	my $dest = pack("H*",$op->get("dest"));

	my $hash_orig = $s->{hasher}->sha256($type.$orig);
	my $hash_dest = $s->{hasher}->sha256($type.$dest);

	$op->put("hash_orig",unpack("H*",$hash_orig));
	$op->put("hash_dest",unpack("H*",$hash_dest));

	my $ok = $s->hash_change_issuer($op,$type,$hash_orig,$hash_dest);

	if ($ok)
		{
		$op->put("status","success");
		}
	else
		{
		$op->put("status","fail");
		$op->put("error_qty","insufficient");
		}

	return;
	}

sub do_move
	{
	my $s = shift;
	my $op = shift;

	if (!$s->{id}->valid_id($op->get("type")))
		{
		$op->put("status","fail");
		$op->put("error_type","not_valid_id");
		}

	if (!$s->{id}->valid_id($op->get("orig")))
		{
		$op->put("status","fail");
		$op->put("error_orig","not_valid_id");
		}

	if (!$s->{id}->valid_id($op->get("dest")))
		{
		$op->put("status","fail");
		$op->put("error_dest","not_valid_id");
		}

	my $bv_amount = Loom::Int128->from_dec($op->get("qty"));

	if (!defined $bv_amount)
		{
		$op->put("status","fail");
		$op->put("error_qty","not_valid_int");
		}

	return if $op->get("status") ne "";
	die if $op->get("status") ne "";

	my $type = pack("H*",$op->get("type"));
	my $orig = pack("H*",$op->get("orig"));
	my $dest = pack("H*",$op->get("dest"));

	my $hash_orig = $s->{hasher}->sha256($type.$orig);
	my $hash_dest = $s->{hasher}->sha256($type.$dest);

	$op->put("hash_orig",unpack("H*",$hash_orig));
	$op->put("hash_dest",unpack("H*",$hash_dest));

	my $ok = $s->hash_move($op,$type,$bv_amount,$hash_orig,$hash_dest);

	if ($ok)
		{
		$op->put("status","success");
		}
	else
		{
		$op->put("status","fail");
		$op->put("error_qty","insufficient");
		}

	return;
	}

# We limit the size of the cross-product (locs x types) to a maximum of 2048.
# That takes under 1 second, which is important because the database is locked
# so we guarantee a consistent read image.  Later we will do more work on
# minimizing locking, but for now we need to get in and get out very quickly.

# LATER test scan with hashes
# LATER put some scan regression tests in qualify

sub do_scan
	{
	my $s = shift;
	my $op = shift;

	my $max_scan_count = 2048;

	my $zeroes = $op->get("zeroes");
	my @locs = split(" ",$op->get("locs"));
	my @types = split(" ",$op->get("types"));

	my $scan_count = 0;
	my $excessive = 0;

	for my $loc (@locs)
		{
		my @pairs;

		for my $type (@types)
			{
			$scan_count++;
			$excessive = ($scan_count > $max_scan_count);
			last if $excessive;

			my $value = "";

			if (length($loc) == 32)
				{
				my $touch = Loom::Context->new
					(
					function => "grid",
					action => "touch",
					type => $type,
					loc => $loc,
					);

				$s->do_touch($touch);
				$value = $touch->get("value");
				}
			elsif (length($loc) == 64)
				{
				my $look = Loom::Context->new
					(
					function => "grid",
					action => "look",
					type => $type,
					hash => $loc,
					);

				$s->do_touch($look);
				$value = $look->get("value");
				}

			next if $value eq "";
			next if $value eq "0" && !$zeroes;

			push @pairs, "$value:$type";
			}

		$op->put("loc/$loc",join(" ",@pairs));

		last if $excessive;
		}

	if ($excessive)
		{
		$op->put("status","fail");
		$op->put("error","excessive");
		$op->put("error_max",$max_scan_count);
		}

	return;
	}

# This is the low-level routine which moves based on hashed locations.
sub hash_move
	{
	my $s = shift;
	my $op = shift;
	my $type = shift;
	my $bv_amount = shift;
	my $hash_orig = shift;
	my $hash_dest = shift;

	die if length($type) != 16;
	die if !defined $bv_amount;
	die if length($hash_orig) != 32;
	die if length($hash_dest) != 32;

	my $val_orig = $s->{db}->get("V$type$hash_orig");
	my $val_dest = $s->{db}->get("V$type$hash_dest");

	$op->put("value_orig",$val_orig);
	$op->put("value_dest",$val_dest);

	return 0 if $hash_orig eq $hash_dest; # Locations cannot be identical.

	return 0 if $val_orig eq "";
	return 0 if $val_dest eq "";

	my $bv_orig = Loom::Int128->from_dec($val_orig);
	my $bv_dest = Loom::Int128->from_dec($val_dest);

	die if !defined $bv_orig;
	die if !defined $bv_dest;

	my $old_sign_orig = $bv_orig->sign;
	my $old_sign_dest = $bv_dest->sign;

	$bv_orig->subtract($bv_amount);
	$bv_dest->add($bv_amount);

	my $new_sign_orig = $bv_orig->sign;
	my $new_sign_dest = $bv_dest->sign;

	if ($new_sign_orig == $old_sign_orig
		&& $new_sign_dest == $old_sign_dest)
		{
		# The signs remained the same:  OK.
		}
	else
		{
		# The signs changed:  NOT OK.

		return 0;
		}

	# Update the two values and return success.

	$val_orig = $bv_orig->to_dec;
	$val_dest = $bv_dest->to_dec;

	$s->{db}->put("V$type$hash_orig", $val_orig);
	$s->{db}->put("V$type$hash_dest", $val_dest);

	$op->put("value_orig",$val_orig);
	$op->put("value_dest",$val_dest);

	return 1;
	}

# This is the low-level routine which changes issuer based on hashed locations.
sub hash_change_issuer
	{
	my $s = shift;
	my $op = shift;
	my $type = shift;
	my $hash_orig = shift;
	my $hash_dest = shift;

	die if length($type) != 16;
	die if length($hash_orig) != 32;
	die if length($hash_dest) != 32;

	my $val_orig = $s->{db}->get("V$type$hash_orig");
	my $val_dest = $s->{db}->get("V$type$hash_dest");

	$op->put("value_orig",$val_orig);
	$op->put("value_dest",$val_dest);

	return 0 if $hash_orig eq $hash_dest; # Locations cannot be identical.

	return 0 if $val_orig eq "";
	return 0 if $val_dest eq "";

	my $bv_orig = Loom::Int128->from_dec($val_orig);
	my $bv_dest = Loom::Int128->from_dec($val_dest);

	die if !defined $bv_orig;
	die if !defined $bv_dest;

	# Origin must have negative value and destination must be zero.

	return if $bv_orig->sign == 0;  # orig not negative!
	return if !$bv_dest->is_zero;  # dest not zero!

	die unless $bv_orig->sign && $bv_dest->is_zero;  # paranoid

	# Update the issuer location for this type.

	$s->{db}->put("I$type",$hash_dest);

	# Swap the two values and return success.

	$val_orig = $bv_dest->to_dec;
	$val_dest = $bv_orig->to_dec;

	$op->put("value_orig",$val_orig);
	$op->put("value_dest",$val_dest);

	$s->{db}->put("V$type$hash_orig", $val_orig);
	$s->{db}->put("V$type$hash_dest", $val_dest);

	return 1;
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
