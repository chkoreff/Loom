use strict;
use api_grid;
use context;
use crypt_span;
use id;
use loom_db;
use sha256;

sub api_archive_inner_write
	{
	my $op = shift;
	my $hash = shift;
	my $old_bytes = shift;
	my $new_bytes = shift;

	# Assess usage token cost/refund.

	my $len_old = length($old_bytes);
	my $len_new = length($new_bytes);

	my $cost = int( ($len_new - $len_old) / 16);

	op_put($op,"cost",$cost);

	my $usage = op_get($op,"usage");
	if (!valid_id($usage))
		{
		op_put($op,"status","fail");
		op_put($op,"error_usage","not_valid_id");
		return;
		}

	return if op_get($op,"status") ne "";

	my $api_charge = op_new();
	$usage = pack("H*",$usage);
	api_grid_charge_usage($api_charge,$usage,$cost);

	op_put($op,"usage_balance",op_get($api_charge,"usage_balance"));
	if (op_get($api_charge,"status") ne "")
		{
		op_put($op,"status","fail");
		op_put($op,"error_usage",op_get($api_charge,"error_usage"));
		}

	return if op_get($op,"status") ne "";

	my $hash2 = sha256($hash);
	loom_db_put("ar_C$hash2", $new_bytes);

	op_put($op,"status","success");
	return;
	}

sub api_archive_check_loc
	{
	my $op = shift;

	my $loc = op_get($op,"loc");

	if (!valid_id($loc))
		{
		op_put($op,"status","fail");
		op_put($op,"error_loc","not_valid_id");
		}

	return if op_get($op,"status") ne "";

	$loc = pack("H*",$loc);
	die if length($loc) != 16;

	my $hash = sha256($loc);

	op_put($op,"hash", unpack("H*",$hash));
	return;
	}

sub api_archive_buy
	{
	my $op = shift;

	api_archive_check_loc($op);
	return if op_get($op,"status") ne "";

	my $hash = pack("H*",op_get($op,"hash"));
	my $hash2 = sha256($hash);

	my $old_bytes = loom_db_get("ar_C$hash2");
	my $content = "";

	if ($old_bytes ne "")
		{
		my $key = fold_hash($hash);
		$content = span_decrypt($key,$old_bytes);

		op_put($op,"status","fail");
		op_put($op,"error_loc","occupied");
		}

	op_put($op,"content",$content);

	return if op_get($op,"status") ne "";

	die if $old_bytes ne "";
	die if $content ne "";

	my $key = fold_hash($hash);
	my $new_bytes = span_encrypt($key,$content);

	api_archive_inner_write($op,$hash,$old_bytes,$new_bytes);
	return;
	}

sub api_archive_sell
	{
	my $op = shift;

	api_archive_check_loc($op);
	return if op_get($op,"status") ne "";

	my $hash = pack("H*",op_get($op,"hash"));
	my $hash2 = sha256($hash);

	my $old_bytes = loom_db_get("ar_C$hash2");
	my $content = "";

	if ($old_bytes eq "")
		{
		# loc is already vacant (sold)
		op_put($op,"status","fail");
		op_put($op,"error_loc","vacant");
		}
	else
		{
		my $key = fold_hash($hash);
		$content = span_decrypt($key,$old_bytes);

		if ($content ne "")
			{
			# loc is not empty
			op_put($op,"status","fail");
			op_put($op,"error_loc","not_empty");
			}
		}

	op_put($op,"content",$content);

	return if op_get($op,"status") ne "";

	die if $old_bytes eq "";
	die if $content ne "";

	my $new_bytes = "";

	api_archive_inner_write($op,$hash,$old_bytes,$new_bytes);
	return;
	}

sub api_archive_inner_look
	{
	my $op = shift;

	my $hash = pack("H*",op_get($op,"hash"));
	my $hash2 = sha256($hash);

	my $crypt_content = loom_db_get("ar_C$hash2");

	if ($crypt_content eq "")
		{
		op_put($op,"status","fail");
		op_put($op,"error_loc","vacant");
		}

	return if op_get($op,"status") ne "";

	my $key = fold_hash($hash);
	my $content = span_decrypt($key,$crypt_content);
	my $content_hash = unpack("H*",sha256($content));

	op_put($op,"status","success");
	op_put($op,"content",$content);
	op_put($op,"content_hash",$content_hash);

	return;
	}

sub api_archive_look
	{
	my $op = shift;

	my $hash = op_get($op,"hash");

	if (!valid_hash($hash))
		{
		op_put($op,"status","fail");
		op_put($op,"error_hash","not_valid_hash");
		}

	return if op_get($op,"status") ne "";

	api_archive_inner_look($op);
	return;
	}

sub api_archive_touch
	{
	my $op = shift;

	api_archive_check_loc($op);
	return if op_get($op,"status") ne "";

	api_archive_inner_look($op);
	return;
	}

sub api_archive_write
	{
	my $op = shift;

	api_archive_check_loc($op);
	return if op_get($op,"status") ne "";

	my $hash = pack("H*",op_get($op,"hash"));
	my $hash2 = sha256($hash);

	my $old_bytes = loom_db_get("ar_C$hash2");

	if ($old_bytes eq "")
		{
		op_put($op,"status","fail");
		op_put($op,"error_loc","vacant");
		return;
		}

	return if op_get($op,"status") ne "";

	my $content = op_get($op,"content");

	op_put($op,"content","");
		# clear out content field so we don't echo back

	my $content_hash = unpack("H*",sha256($content));
	op_put($op,"content_hash",$content_hash);

	my $guard = op_get($op,"guard");
	if ($guard ne "")
		{
		if (!valid_hash($guard))
			{
			op_put($op,"status","fail");
			op_put($op,"error_guard","not_valid_hash");
			return;
			}

		my $key = fold_hash($hash);
		my $old_content = span_decrypt($key,$old_bytes);
		my $correct_guard = unpack("H*",sha256($old_content));

		if ($guard ne $correct_guard)
			{
			op_put($op,"status","fail");
			op_put($op,"error_guard","changed");
			return;
			}
		}

	my $key = fold_hash($hash);
	my $new_bytes = span_encrypt($key,$content);

	api_archive_inner_write($op,$hash,$old_bytes,$new_bytes);
	return;
	}

# API entry point
sub api_archive_respond
	{
	my $op = shift;

	my $action = op_get($op,"action");

	if ($action eq "look")
		{
		api_archive_look($op);
		}
	elsif ($action eq "touch")
		{
		api_archive_touch($op);
		}
	elsif ($action eq "write")
		{
		api_archive_write($op);
		}
	elsif ($action eq "buy")
		{
		api_archive_buy($op);
		}
	elsif ($action eq "sell")
		{
		api_archive_sell($op);
		}
	else
		{
		op_put($op,"status","fail");
		op_put($op,"error_action","unknown");
		}

	return;
	}

return 1;
