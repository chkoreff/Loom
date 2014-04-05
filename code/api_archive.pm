package api_archive;
use strict;
use api_grid;
use context;
use crypt_span;
use id;
use loom_db;
use sha256;

sub inner_write
	{
	my $op = shift;
	my $hash = shift;
	my $old_bytes = shift;
	my $new_bytes = shift;

	# Assess usage token cost/refund.

	my $len_old = length($old_bytes);
	my $len_new = length($new_bytes);

	my $cost = int( ($len_new - $len_old) / 16);

	context::put($op,"cost",$cost);

	my $usage = context::get($op,"usage");
	if (!id::valid_id($usage))
		{
		context::put($op,"status","fail");
		context::put($op,"error_usage","not_valid_id");
		return;
		}

	return if context::get($op,"status") ne "";

	my $api_charge = context::new();
	$usage = pack("H*",$usage);
	api_grid::charge_usage($api_charge,$usage,$cost);

	context::put($op,"usage_balance",context::get($api_charge,"usage_balance"));
	if (context::get($api_charge,"status") ne "")
		{
		context::put($op,"status","fail");
		context::put($op,"error_usage",context::get($api_charge,"error_usage"));
		}

	return if context::get($op,"status") ne "";

	my $hash2 = sha256::bin($hash);
	loom_db::put("ar_C$hash2", $new_bytes);

	context::put($op,"status","success");
	return;
	}

sub check_loc
	{
	my $op = shift;

	my $loc = context::get($op,"loc");

	if (!id::valid_id($loc))
		{
		context::put($op,"status","fail");
		context::put($op,"error_loc","not_valid_id");
		}

	return if context::get($op,"status") ne "";

	$loc = pack("H*",$loc);
	die if length($loc) != 16;

	my $hash = sha256::bin($loc);

	context::put($op,"hash", unpack("H*",$hash));
	return;
	}

sub buy
	{
	my $op = shift;

	check_loc($op);
	return if context::get($op,"status") ne "";

	my $hash = pack("H*",context::get($op,"hash"));
	my $hash2 = sha256::bin($hash);

	my $old_bytes = loom_db::get("ar_C$hash2");
	my $content = "";

	if ($old_bytes ne "")
		{
		my $key = id::fold_hash($hash);
		$content = crypt_span::decrypt($key,$old_bytes);

		context::put($op,"status","fail");
		context::put($op,"error_loc","occupied");
		}

	context::put($op,"content",$content);

	return if context::get($op,"status") ne "";

	die if $old_bytes ne "";
	die if $content ne "";

	my $key = id::fold_hash($hash);
	my $new_bytes = crypt_span::encrypt($key,$content);

	inner_write($op,$hash,$old_bytes,$new_bytes);
	return;
	}

sub sell
	{
	my $op = shift;

	check_loc($op);
	return if context::get($op,"status") ne "";

	my $hash = pack("H*",context::get($op,"hash"));
	my $hash2 = sha256::bin($hash);

	my $old_bytes = loom_db::get("ar_C$hash2");
	my $content = "";

	if ($old_bytes eq "")
		{
		# loc is already vacant (sold)
		context::put($op,"status","fail");
		context::put($op,"error_loc","vacant");
		}
	else
		{
		my $key = id::fold_hash($hash);
		$content = crypt_span::decrypt($key,$old_bytes);

		if ($content ne "")
			{
			# loc is not empty
			context::put($op,"status","fail");
			context::put($op,"error_loc","not_empty");
			}
		}

	context::put($op,"content",$content);

	return if context::get($op,"status") ne "";

	die if $old_bytes eq "";
	die if $content ne "";

	my $new_bytes = "";

	inner_write($op,$hash,$old_bytes,$new_bytes);
	return;
	}

sub inner_look
	{
	my $op = shift;

	my $hash = pack("H*",context::get($op,"hash"));
	my $hash2 = sha256::bin($hash);

	my $crypt_content = loom_db::get("ar_C$hash2");

	if ($crypt_content eq "")
		{
		context::put($op,"status","fail");
		context::put($op,"error_loc","vacant");
		}

	return if context::get($op,"status") ne "";

	my $key = id::fold_hash($hash);
	my $content = crypt_span::decrypt($key,$crypt_content);
	my $content_hash = unpack("H*",sha256::bin($content));

	context::put($op,"status","success");
	context::put($op,"content",$content);
	context::put($op,"content_hash",$content_hash);

	return;
	}

sub look
	{
	my $op = shift;

	my $hash = context::get($op,"hash");

	if (!id::valid_hash($hash))
		{
		context::put($op,"status","fail");
		context::put($op,"error_hash","not_valid_hash");
		}

	return if context::get($op,"status") ne "";

	inner_look($op);
	return;
	}

sub touch
	{
	my $op = shift;

	check_loc($op);
	return if context::get($op,"status") ne "";

	inner_look($op);
	return;
	}

sub do_write
	{
	my $op = shift;

	check_loc($op);
	return if context::get($op,"status") ne "";

	my $hash = pack("H*",context::get($op,"hash"));
	my $hash2 = sha256::bin($hash);

	my $old_bytes = loom_db::get("ar_C$hash2");

	if ($old_bytes eq "")
		{
		context::put($op,"status","fail");
		context::put($op,"error_loc","vacant");
		return;
		}

	return if context::get($op,"status") ne "";

	my $content = context::get($op,"content");

	context::put($op,"content","");
		# clear out content field so we don't echo back

	my $content_hash = unpack("H*",sha256::bin($content));
	context::put($op,"content_hash",$content_hash);

	my $guard = context::get($op,"guard");
	if ($guard ne "")
		{
		if (!id::valid_hash($guard))
			{
			context::put($op,"status","fail");
			context::put($op,"error_guard","not_valid_hash");
			return;
			}

		my $key = id::fold_hash($hash);
		my $old_content = crypt_span::decrypt($key,$old_bytes);
		my $correct_guard = unpack("H*",sha256::bin($old_content));

		if ($guard ne $correct_guard)
			{
			context::put($op,"status","fail");
			context::put($op,"error_guard","changed");
			return;
			}
		}

	my $key = id::fold_hash($hash);
	my $new_bytes = crypt_span::encrypt($key,$content);

	inner_write($op,$hash,$old_bytes,$new_bytes);
	return;
	}

# API entry point
sub respond
	{
	my $op = shift;

	my $action = context::get($op,"action");

	if ($action eq "look")
		{
		look($op);
		}
	elsif ($action eq "touch")
		{
		touch($op);
		}
	elsif ($action eq "write")
		{
		do_write($op);
		}
	elsif ($action eq "buy")
		{
		buy($op);
		}
	elsif ($action eq "sell")
		{
		sell($op);
		}
	else
		{
		context::put($op,"status","fail");
		context::put($op,"error_action","unknown");
		}

	return;
	}

return 1;
