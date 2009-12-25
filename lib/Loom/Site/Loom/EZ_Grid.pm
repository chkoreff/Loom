package Loom::Site::Loom::EZ_Grid;
use strict;

sub new
	{
	my $class = shift;
	my $api = shift;

	my $s = bless({},$class);
	$s->{api} = $api;
	return $s;
	}

sub buy
	{
	my $s = shift;
	my $type = shift;
	my $loc = shift;
	my $usage = shift;

	$s->{api}->run(
		function => "grid",
		action => "buy",
		type => $type,
		loc => $loc,
		usage => $usage
		);
	}

sub sell
	{
	my $s = shift;
	my $type = shift;
	my $loc = shift;
	my $usage = shift;

	$s->{api}->run(
		function => "grid",
		action => "sell",
		type => $type,
		loc => $loc,
		usage => $usage
		);
	}

sub issuer
	{
	my $s = shift;
	my $type = shift;
	my $orig = shift;
	my $dest = shift;

	$s->{api}->run(
		function => "grid",
		action => "issuer",
		type => $type,
		orig => $orig,
		dest => $dest
		);
	}

sub touch
	{
	my $s = shift;
	my $type = shift;
	my $loc = shift;

	die if !defined $loc;

	$s->{api}->run(
		function => "grid",
		action => "touch",
		type => $type,
		loc => $loc,
		);

	return $s->{api}->{rsp}->get("value");
	}

sub look
	{
	my $s = shift;
	my $type = shift;
	my $hash = shift;

	die if !defined $hash;

	$s->{api}->run(
		function => "grid",
		action => "look",
		type => $type,
		hash => $hash,
		);

	return $s->{api}->{rsp}->get("value");
	}

sub move
	{
	my $s = shift;
	my $type = shift;
	my $qty = shift;
	my $orig = shift;
	my $dest = shift;

	$s->{api}->run(
		function => "grid",
		action => "move",
		type => $type,
		qty => $qty,
		orig => $orig,
		dest => $dest,
		);
	}

sub scan
	{
	my $s = shift;
	my $locs = shift;
	my $types = shift;
	my $zeroes = shift;  # optional flag to include 0 values

	$s->{api}->run(
		"function" => "grid",
		"action" => "scan",
		"locs" => join(" ",@$locs),
		"types" => join(" ",@$types),
		"zeroes" =>  ($zeroes ? "1" : ""),
		);
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
