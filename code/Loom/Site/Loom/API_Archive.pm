package Loom::Site::Loom::API_Archive;
use strict;
use Loom::Context;
use Loom::Crypt::Span;
use Loom::Digest::SHA256;
use Loom::ID;

sub new
	{
	my $class = shift;
	my $db = shift;
	my $grid = shift;

	my $s = bless({},$class);
	$s->{db} = $db;
	$s->{grid} = $grid;
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

	if ($action eq "look")
		{
		$s->do_look($op);
		}
	elsif ($action eq "touch")
		{
		$s->do_touch($op);
		}
	elsif ($action eq "write")
		{
		$s->do_write($op);
		}
	elsif ($action eq "buy")
		{
		$s->do_buy($op);
		}
	elsif ($action eq "sell")
		{
		$s->do_sell($op);
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

	$s->check_loc($op);
	return if $op->get("status") ne "";

	my $hash = pack("H*",$op->get("hash"));
	my $hash2 = $s->{hasher}->sha256($hash);

	my $old_bytes = $s->{db}->get("C$hash2");
	my $content = "";

	if ($old_bytes ne "")
		{
		my $key = $s->hash_key($hash);
		$content = Loom::Crypt::Span->new($key)->decrypt($old_bytes);

		$op->put("status","fail");
		$op->put("error_loc","occupied");
		}

	$op->put("content",$content);

	return if $op->get("status") ne "";

	die if $old_bytes ne "";
	die if $content ne "";

	my $key = $s->hash_key($hash);
	my $new_bytes = Loom::Crypt::Span->new($key)->encrypt($content);

	$s->inner_write($op,$hash,$old_bytes,$new_bytes);
	return;
	}

sub do_sell
	{
	my $s = shift;
	my $op = shift;

	$s->check_loc($op);
	return if $op->get("status") ne "";

	my $hash = pack("H*",$op->get("hash"));
	my $hash2 = $s->{hasher}->sha256($hash);

	my $old_bytes = $s->{db}->get("C$hash2");
	my $content = "";

	if ($old_bytes eq "")
		{
		# loc is already vacant (sold)
		$op->put("status","fail");
		$op->put("error_loc","vacant");
		}
	else
		{
		my $key = $s->hash_key($hash);
		$content = Loom::Crypt::Span->new($key)->decrypt($old_bytes);

		if ($content ne "")
			{
			# loc is not empty
			$op->put("status","fail");
			$op->put("error_loc","not_empty");
			}
		}

	$op->put("content",$content);

	return if $op->get("status") ne "";

	die if $old_bytes eq "";
	die if $content ne "";

	my $new_bytes = "";

	$s->inner_write($op,$hash,$old_bytes,$new_bytes);
	return;
	}

sub do_look
	{
	my $s = shift;
	my $op = shift;

	my $hash = $op->get("hash");

	if (!$s->{id}->valid_hash($hash))
		{
		$op->put(status => "fail");
		$op->put(error_hash => "not_valid_hash");
		}

	return if $op->get("status") ne "";

	$s->inner_look($op);
	return;
	}

sub do_touch
	{
	my $s = shift;
	my $op = shift;

	$s->check_loc($op);
	return if $op->get("status") ne "";

	$s->inner_look($op);
	return;
	}

sub do_write
	{
	my $s = shift;
	my $op = shift;

	$s->check_loc($op);
	return if $op->get("status") ne "";

	my $hash = pack("H*",$op->get("hash"));
	my $hash2 = $s->{hasher}->sha256($hash);

	my $old_bytes = $s->{db}->get("C$hash2");

	if ($old_bytes eq "")
		{
		$op->put("status","fail");
		$op->put("error_loc","vacant");
		return;
		}

	return if $op->get("status") ne "";

	my $content = $op->get("content");

	$op->put("content","");
		# clear out content field so we don't echo back

	my $content_hash = unpack("H*",$s->{hasher}->sha256($content));
	$op->put("content_hash",$content_hash);

	my $guard = $op->get("guard");
	if ($guard ne "")
		{
		if (!$s->{id}->valid_hash($guard))
			{
			$op->put("status","fail");
			$op->put("error_guard","not_valid_hash");
			return;
			}

		my $key = $s->hash_key($hash);
		my $old_content = Loom::Crypt::Span->new($key)->decrypt($old_bytes);
		my $correct_guard = unpack("H*",$s->{hasher}->sha256($old_content));

		if ($guard ne $correct_guard)
			{
			$op->put("status","fail");
			$op->put("error_guard","changed");
			return;
			}
		}

	my $key = $s->hash_key($hash);
	my $new_bytes = Loom::Crypt::Span->new($key)->encrypt($content);

	$s->inner_write($op,$hash,$old_bytes,$new_bytes);
	return;
	}

sub inner_look
	{
	my $s = shift;
	my $op = shift;

	my $hash = pack("H*",$op->get("hash"));
	my $hash2 = $s->{hasher}->sha256($hash);

	my $crypt_content = $s->{db}->get("C$hash2");

	if ($crypt_content eq "")
		{
		$op->put("status","fail");
		$op->put("error_loc","vacant");
		}

	return if $op->get("status") ne "";

	my $key = $s->hash_key($hash);
	my $content = Loom::Crypt::Span->new($key)->decrypt($crypt_content);
	my $content_hash = unpack("H*",$s->{hasher}->sha256($content));

	$op->put("status","success");
	$op->put("content",$content);
	$op->put("content_hash",$content_hash);

	return;
	}

sub inner_write
	{
	my $s = shift;
	my $op = shift;
	my $hash = shift;
	my $old_bytes = shift;
	my $new_bytes = shift;

	# Assess usage token cost/refund.

	my $len_old = length($old_bytes);
	my $len_new = length($new_bytes);

	my $cost = int( ($len_new - $len_old) / 16);

	$op->put("cost",$cost);

	my $usage = $op->get("usage");
	if (!$s->{id}->valid_id($usage))
		{
		$op->put("status","fail");
		$op->put("error_usage","not_valid_id");
		return;
		}

	return if $op->get("status") ne "";

	my $api_charge = Loom::Context->new;
	$usage = pack("H*",$usage);
	$s->{grid}->charge_usage($api_charge,$usage,$cost);

	$op->put("usage_balance",$api_charge->get("usage_balance"));
	if ($api_charge->get("status") ne "")
		{
		$op->put("status","fail");
		$op->put("error_usage",$api_charge->get("error_usage"));
		}

	return if $op->get("status") ne "";

	my $hash2 = $s->{hasher}->sha256($hash);
	$s->{db}->put("C$hash2", $new_bytes);

	$op->put("status","success");
	return;
	}

sub check_loc
	{
	my $s = shift;
	my $op = shift;

	my $loc = $op->get("loc");

	if (!$s->{id}->valid_id($loc))
		{
		$op->put(status => "fail");
		$op->put(error_loc => "not_valid_id");
		}

	return if $op->get("status") ne "";

	$loc = pack("H*",$loc);
	die if length($loc) != 16;

	my $hash = $s->{hasher}->sha256($loc);

	$op->put("hash", unpack("H*",$hash));
	return;
	}

sub hash_key
	{
	my $s = shift;
	my $hash = shift;   # packed binary

	die if length($hash) != 32;

	my $key = substr($hash,0,16) ^ substr($hash,16,16);
	return $key;
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
