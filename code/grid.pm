use strict;
use api;

sub grid_buy
	{
	my $type = shift;
	my $loc = shift;
	my $usage = shift;

	my $op = op_new
		(
		"function","grid",
		"action","buy",
		"type",$type,
		"loc",$loc,
		"usage",$usage
		);

	return api_respond($op);
	}

sub grid_sell
	{
	my $type = shift;
	my $loc = shift;
	my $usage = shift;

	my $op = op_new
		(
		"function","grid",
		"action","sell",
		"type",$type,
		"loc",$loc,
		"usage",$usage
		);

	return api_respond($op);
	}

sub grid_issuer
	{
	my $type = shift;
	my $orig = shift;
	my $dest = shift;

	my $op = op_new
		(
		"function","grid",
		"action","issuer",
		"type",$type,
		"orig",$orig,
		"dest",$dest
		);

	return api_respond($op);
	}

sub grid_touch
	{
	my $type = shift;
	my $loc = shift;

	die if !defined $loc;

	my $op = op_new
		(
		"function","grid",
		"action","touch",
		"type",$type,
		"loc",$loc,
		);

	api_respond($op);
	return op_get($op,"value");
	}

sub grid_look
	{
	my $type = shift;
	my $hash = shift;

	die if !defined $hash;

	my $op = op_new
		(
		"function","grid",
		"action","look",
		"type",$type,
		"hash",$hash,
		);

	api_respond($op);
	return op_get($op,"value");
	}

sub grid_move
	{
	my $type = shift;
	my $qty = shift;
	my $orig = shift;
	my $dest = shift;

	my $op = op_new
		(
		"function","grid",
		"action","move",
		"type",$type,
		"qty",$qty,
		"orig",$orig,
		"dest",$dest,
		);

	return api_respond($op);
	}

sub grid_scan
	{
	my $locs = shift;
	my $types = shift;
	my $zeroes = shift;  # optional flag to include 0 values

	my $op = op_new
		(
		"function","grid",
		"action","scan",
		"locs",join(" ",@$locs),
		"types",join(" ",@$types),
		"zeroes",($zeroes ? "1" : ""),
		);

	return api_respond($op);
	}

return 1;
