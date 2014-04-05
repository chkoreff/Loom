package grid;
use strict;
use api;
use context;

sub buy
	{
	my $type = shift;
	my $loc = shift;
	my $usage = shift;

	my $op = context::new
		(
		"function","grid",
		"action","buy",
		"type",$type,
		"loc",$loc,
		"usage",$usage
		);

	return api::respond($op);
	}

sub sell
	{
	my $type = shift;
	my $loc = shift;
	my $usage = shift;

	my $op = context::new
		(
		"function","grid",
		"action","sell",
		"type",$type,
		"loc",$loc,
		"usage",$usage
		);

	return api::respond($op);
	}

sub issuer
	{
	my $type = shift;
	my $orig = shift;
	my $dest = shift;

	my $op = context::new
		(
		"function","grid",
		"action","issuer",
		"type",$type,
		"orig",$orig,
		"dest",$dest
		);

	return api::respond($op);
	}

sub touch
	{
	my $type = shift;
	my $loc = shift;

	die if !defined $loc;

	my $op = context::new
		(
		"function","grid",
		"action","touch",
		"type",$type,
		"loc",$loc,
		);

	api::respond($op);
	return context::get($op,"value");
	}

sub look
	{
	my $type = shift;
	my $hash = shift;

	die if !defined $hash;

	my $op = context::new
		(
		"function","grid",
		"action","look",
		"type",$type,
		"hash",$hash,
		);

	api::respond($op);
	return context::get($op,"value");
	}

sub move
	{
	my $type = shift;
	my $qty = shift;
	my $orig = shift;
	my $dest = shift;

	my $op = context::new
		(
		"function","grid",
		"action","move",
		"type",$type,
		"qty",$qty,
		"orig",$orig,
		"dest",$dest,
		);

	return api::respond($op);
	}

sub scan
	{
	my $locs = shift;
	my $types = shift;
	my $zeroes = shift;  # optional flag to include 0 values

	my $op = context::new
		(
		"function","grid",
		"action","scan",
		"locs",join(" ",@$locs),
		"types",join(" ",@$types),
		"zeroes",($zeroes ? "1" : ""),
		);

	return api::respond($op);
	}

return 1;
