use strict;
use context;
use id;
use int128;
use loom_db;
use sha256;

my $g_zero = "\000" x 16;

# Note that when we charge or refund usage tokens, we don't bother moving them
# to or from the usage token issuer location.  This would become a point of
# contention in a busy system, with many processes trying to update the single
# issuer location, causing many retries due to commit failures, and becoming a
# performance bottleneck.
#
# As a result of this policy, we must relax the normal constraint which demands
# that at all times, the sum of the balances at all locations must equal -1.
# This is no longer true of asset type zero.

sub api_grid_charge_usage
	{
	my $op = shift;
	my $loc = shift;
	my $amount = shift;

	die if length($loc) != 16;

	my $bv_amount = int128_from_dec($amount);
	die if !defined $bv_amount;

	my $ok = 0;

	my $usage_hash = sha256($g_zero.$loc);
	my $val_orig = loom_db_get("grid_V$g_zero$usage_hash");

	if ($val_orig eq "")
		{
		# Vacant usage location.  This is valid only if the usage location is
		# zero and the the issuer location is null, which is effectively zero.

		$ok = ($loc eq $g_zero && loom_db_get("grid_I$g_zero") eq "");
		}
	else
		{
		my $bv_orig = int128_from_dec($val_orig);
		my $old_sign_orig = int128_sign($bv_orig);

		if ($old_sign_orig == 0)
			{
			# Non-negative usage balance.  Make sure the balance is sufficient
			# by subtracting the charge amount from it and seeing if the sign
			# changes.

			int128_sub($bv_orig,$bv_amount);
			my $new_sign_orig = int128_sign($bv_orig);
			$ok = ($new_sign_orig == $old_sign_orig);

			if ($ok)
				{
				# Sign was unchanged, so update the usage balance.
				$val_orig = int128_to_dec($bv_orig);
				loom_db_put("grid_V$g_zero$usage_hash", $val_orig);
				}
			}
		else
			{
			# Negative usage balance.  This is the issuer location so it's OK.
			$ok = 1;
			}
		}

	op_put($op,"usage_balance",$val_orig);

	if (!$ok)
		{
		op_put($op,"status","fail");
		op_put($op,"error_usage","insufficient");
		}

	return;
	}

sub api_grid_check_buy
	{
	my $op = shift;

	if (!valid_id(op_get($op,"type")))
		{
		op_put($op,"status","fail");
		op_put($op,"error_type","not_valid_id");
		}

	if (!valid_id(op_get($op,"loc")))
		{
		op_put($op,"status","fail");
		op_put($op,"error_loc","not_valid_id");
		}

	if (!valid_id(op_get($op,"usage")))
		{
		op_put($op,"status","fail");
		op_put($op,"error_usage","not_valid_id");
		}

	return;
	}

sub api_grid_buy
	{
	my $op = shift;

	api_grid_check_buy($op);
	return if op_get($op,"status") ne "";

	# Convert the hex strings to packed hex values for internal use.

	my $type = pack("H*",op_get($op,"type"));
	my $loc = pack("H*",op_get($op,"loc"));
	my $usage = pack("H*",op_get($op,"usage"));

	my $hash = sha256($type.$loc);

	op_put($op,"hash",unpack("H*",$hash));

	my $val = loom_db_get("grid_V$type$hash");

	op_put($op,"value",$val);

	if ($val ne "")
		{
		# Location is occupied:  NOT OK.
		op_put($op,"status","fail");
		op_put($op,"error_loc","occupied");
		}

	return if op_get($op,"status") ne "";

	# Now see if we can charge usage.

	api_grid_charge_usage($op,$usage,1);
	return if op_get($op,"status") ne "";

	if ($hash eq sha256($type.$g_zero)
		&& loom_db_get("grid_I$type") eq "")
		{
		# Buying issuer location for new type:  OK.
		$val = -1;
		loom_db_put("grid_I$type", $hash);
		}
	else
		{
		# Buying location for existing type:  OK.
		$val = 0;
		}

	loom_db_put("grid_V$type$hash", $val);
	op_put($op,"status","success");
	op_put($op,"value",$val);

	return;
	}

sub api_grid_sell
	{
	my $op = shift;

	api_grid_check_buy($op);
	return if op_get($op,"status") ne "";

	# Convert the hex strings to packed hex values for internal use.

	my $type = pack("H*",op_get($op,"type"));
	my $loc = pack("H*",op_get($op,"loc"));
	my $usage = pack("H*",op_get($op,"usage"));

	my $hash = sha256($type.$loc);

	op_put($op,"hash",unpack("H*",$hash));

	my $val = loom_db_get("grid_V$type$hash");

	op_put($op,"value",$val);

	if ($val eq "")
		{
		# Location is already vacant:  NOT OK.
		op_put($op,"status","fail");
		op_put($op,"error_loc","vacant");
		}
	elsif ($val eq "0")
		{
		# Value is zero:  OK.

		if ($type eq $g_zero && $loc eq $usage)
			{
			# Cannot sell a usage token location if we're trying to receive the
			# refund in that same location.

			op_put($op,"status","fail");
			op_put($op,"error_loc","cannot_refund");
			}
		}
	elsif ($val eq "-1" && $hash eq sha256($type.$g_zero))
		{
		# Value is -1 and location is zero:  OK.
		# Delete the issue location tracking entry.

		loom_db_put("grid_I$type", "");
		}
	else
		{
		# Location has non-empty value:  NOT OK.
		op_put($op,"status","fail");
		op_put($op,"error_loc","non_empty");
		}

	return if op_get($op,"status") ne "";

	# Refund the usage token and delete the location.

	api_grid_charge_usage($op,$usage,-1);
	return if op_get($op,"status") ne "";

	loom_db_put("grid_V$type$hash", "");
	op_put($op,"status","success");

	return;
	}

sub api_grid_look
	{
	my $op = shift;

	if (!valid_id(op_get($op,"type")))
		{
		op_put($op,"status","fail");
		op_put($op,"error_type","not_valid_id");
		}

	if (!valid_hash(op_get($op,"hash")))
		{
		op_put($op,"status","fail");
		op_put($op,"error_hash","not_valid_hash");
		}

	return if op_get($op,"status") ne "";

	my $type = pack("H*",op_get($op,"type"));
	my $hash = pack("H*",op_get($op,"hash"));

	my $val = loom_db_get("grid_V$type$hash");

	if ($val eq "")
		{
		op_put($op,"status","fail");
		op_put($op,"error_loc","vacant");
		}

	return if op_get($op,"status") ne "";

	op_put($op,"status","success");
	op_put($op,"value",$val);

	return;
	}

sub api_grid_touch
	{
	my $op = shift;

	if (!valid_id(op_get($op,"type")))
		{
		op_put($op,"status","fail");
		op_put($op,"error_type","not_valid_id");
		}

	if (!valid_id(op_get($op,"loc")))
		{
		op_put($op,"status","fail");
		op_put($op,"error_loc","not_valid_id");
		}

	return if op_get($op,"status") ne "";

	my $type = pack("H*",op_get($op,"type"));
	my $loc = pack("H*",op_get($op,"loc"));

	op_put($op,"hash", unpack("H*",sha256($type.$loc)));

	api_grid_look($op);

	return;
	}

# This is the low-level routine which changes issuer based on hashed locations.
sub api_grid_inner_issuer
	{
	my $op = shift;
	my $type = shift;
	my $hash_orig = shift;
	my $hash_dest = shift;

	die if length($type) != 16;
	die if length($hash_orig) != 32;
	die if length($hash_dest) != 32;

	my $val_orig = loom_db_get("grid_V$type$hash_orig");
	my $val_dest = loom_db_get("grid_V$type$hash_dest");

	op_put($op,"value_orig",$val_orig);
	op_put($op,"value_dest",$val_dest);

	return 0 if $hash_orig eq $hash_dest; # Locations cannot be identical.

	return 0 if $val_orig eq "";
	return 0 if $val_dest eq "";

	my $bv_orig = int128_from_dec($val_orig);
	my $bv_dest = int128_from_dec($val_dest);

	die if !defined $bv_orig;
	die if !defined $bv_dest;

	# Origin must have negative value and destination must be zero.

	return if int128_sign($bv_orig) == 0;  # orig not negative!
	return if !int128_is_zero($bv_dest);  # dest not zero!

	die unless int128_sign($bv_orig) && int128_is_zero($bv_dest);  # paranoid

	# Update the issuer location for this type.

	loom_db_put("grid_I$type",$hash_dest);

	# Swap the two values and return success.

	$val_orig = int128_to_dec($bv_dest);
	$val_dest = int128_to_dec($bv_orig);

	op_put($op,"value_orig",$val_orig);
	op_put($op,"value_dest",$val_dest);

	loom_db_put("grid_V$type$hash_orig", $val_orig);
	loom_db_put("grid_V$type$hash_dest", $val_dest);

	return 1;
	}

sub api_grid_issuer
	{
	my $op = shift;

	if (!valid_id(op_get($op,"type")))
		{
		op_put($op,"status","fail");
		op_put($op,"error_type","not_valid_id");
		}

	if (!valid_id(op_get($op,"orig")))
		{
		op_put($op,"status","fail");
		op_put($op,"error_orig","not_valid_id");
		}

	if (!valid_id(op_get($op,"dest")))
		{
		op_put($op,"status","fail");
		op_put($op,"error_dest","not_valid_id");
		}

	return if op_get($op,"status") ne "";
	die if op_get($op,"status") ne "";

	my $type = pack("H*",op_get($op,"type"));
	my $orig = pack("H*",op_get($op,"orig"));
	my $dest = pack("H*",op_get($op,"dest"));

	my $hash_orig = sha256($type.$orig);
	my $hash_dest = sha256($type.$dest);

	op_put($op,"hash_orig",unpack("H*",$hash_orig));
	op_put($op,"hash_dest",unpack("H*",$hash_dest));

	my $ok = api_grid_inner_issuer($op,$type,$hash_orig,$hash_dest);

	if ($ok)
		{
		op_put($op,"status","success");
		}
	else
		{
		op_put($op,"status","fail");
		op_put($op,"error_qty","insufficient");
		}

	return;
	}

# This is the low-level routine which moves based on hashed locations.
sub api_grid_inner_move
	{
	my $op = shift;
	my $type = shift;
	my $bv_amount = shift;
	my $hash_orig = shift;
	my $hash_dest = shift;

	die if length($type) != 16;
	die if !defined $bv_amount;
	die if length($hash_orig) != 32;
	die if length($hash_dest) != 32;

	my $val_orig = loom_db_get("grid_V$type$hash_orig");
	my $val_dest = loom_db_get("grid_V$type$hash_dest");

	op_put($op,"value_orig",$val_orig);
	op_put($op,"value_dest",$val_dest);

	return 0 if $hash_orig eq $hash_dest; # Locations cannot be identical.

	return 0 if $val_orig eq "";
	return 0 if $val_dest eq "";

	my $bv_orig = int128_from_dec($val_orig);
	my $bv_dest = int128_from_dec($val_dest);

	die if !defined $bv_orig;
	die if !defined $bv_dest;

	my $old_sign_orig = int128_sign($bv_orig);
	my $old_sign_dest = int128_sign($bv_dest);

	int128_sub($bv_orig,$bv_amount);
	int128_add($bv_dest,$bv_amount);

	my $new_sign_orig = int128_sign($bv_orig);
	my $new_sign_dest = int128_sign($bv_dest);

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

	$val_orig = int128_to_dec($bv_orig);
	$val_dest = int128_to_dec($bv_dest);

	loom_db_put("grid_V$type$hash_orig", $val_orig);
	loom_db_put("grid_V$type$hash_dest", $val_dest);

	op_put($op,"value_orig",$val_orig);
	op_put($op,"value_dest",$val_dest);

	return 1;
	}

sub api_grid_move
	{
	my $op = shift;

	if (!valid_id(op_get($op,"type")))
		{
		op_put($op,"status","fail");
		op_put($op,"error_type","not_valid_id");
		}

	if (!valid_id(op_get($op,"orig")))
		{
		op_put($op,"status","fail");
		op_put($op,"error_orig","not_valid_id");
		}

	if (!valid_id(op_get($op,"dest")))
		{
		op_put($op,"status","fail");
		op_put($op,"error_dest","not_valid_id");
		}

	my $bv_amount = int128_from_dec(op_get($op,"qty"));

	if (!defined $bv_amount)
		{
		op_put($op,"status","fail");
		op_put($op,"error_qty","not_valid_int");
		}

	return if op_get($op,"status") ne "";
	die if op_get($op,"status") ne "";

	my $type = pack("H*",op_get($op,"type"));
	my $orig = pack("H*",op_get($op,"orig"));
	my $dest = pack("H*",op_get($op,"dest"));

	my $hash_orig = sha256($type.$orig);
	my $hash_dest = sha256($type.$dest);

	op_put($op,"hash_orig",unpack("H*",$hash_orig));
	op_put($op,"hash_dest",unpack("H*",$hash_dest));

	my $ok = api_grid_inner_move($op,$type,$bv_amount,$hash_orig,$hash_dest);

	if ($ok)
		{
		op_put($op,"status","success");
		}
	else
		{
		op_put($op,"status","fail");
		op_put($op,"error_qty","insufficient");
		}

	return;
	}

# We limit the size of the cross-product (locs x types) to a maximum of 2048.
# That takes under 1 second.

# LATER test scan with hashes
# LATER put some scan regression tests in qualify

sub api_grid_scan
	{
	my $op = shift;

	my $max_scan_count = 2048;

	my $zeroes = op_get($op,"zeroes");
	my @locs = split(" ",op_get($op,"locs"));
	my @types = split(" ",op_get($op,"types"));

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
				my $touch = op_new
					(
					"function","grid",
					"action","touch",
					"type",$type,
					"loc",$loc,
					);

				api_grid_touch($touch);
				$value = op_get($touch,"value");
				}
			elsif (length($loc) == 64)
				{
				my $look = op_new
					(
					"function","grid",
					"action","look",
					"type",$type,
					"hash",$loc,
					);

				api_grid_touch($look);
				$value = op_get($look,"value");
				}

			next if $value eq "";
			next if $value eq "0" && !$zeroes;

			push @pairs, "$value:$type";
			}

		op_put($op,"loc/$loc",join(" ",@pairs));

		last if $excessive;
		}

	if ($excessive)
		{
		op_put($op,"status","fail");
		op_put($op,"error","excessive");
		op_put($op,"error_max",$max_scan_count);
		}

	return;
	}

# API entry point
sub api_grid_respond
	{
	my $op = shift;

	my $action = op_get($op,"action");

	if ($action eq "buy")
		{
		api_grid_buy($op);
		}
	elsif ($action eq "sell")
		{
		api_grid_sell($op);
		}
	elsif ($action eq "issuer")
		{
		api_grid_issuer($op);
		}
	elsif ($action eq "touch")
		{
		api_grid_touch($op);
		}
	elsif ($action eq "look")
		{
		api_grid_look($op);
		}
	elsif ($action eq "move")
		{
		api_grid_move($op);
		}
	elsif ($action eq "scan")
		{
		api_grid_scan($op);
		}
	else
		{
		op_put($op,"status","fail");
		op_put($op,"error_action","unknown");
		}

	return;
	}

return 1;
