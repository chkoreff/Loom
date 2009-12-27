package Loom::ID;
use strict;

# Return true if string is a valid 32 character (128 bit) hexadecimal value.

sub new
	{
	my $class = shift;
	my $s = bless({},$class);
	return $s;
	}

sub valid_id
	{
	my $s = shift;
	my $str = shift;

	return 0 if !defined $str || $str eq "";
	return 0 if length($str) != 32;
	return 1 if $str =~ /^[a-f0-9]{32}$/;
	return 0;
	}

# Return true if string is a valid 64 character (256 bit) hexadecimal value.

sub valid_hash
	{
	my $s = shift;
	my $str = shift;

	return 0 if !defined $str || $str eq "";
	return 0 if length($str) != 64;
	return 1 if $str =~ /^[a-f0-9]{64}$/;
	return 0;
	}

sub xor_hex
	{
	my $s = shift;
	my $a = shift;
	my $b = shift;

	$a = pack("H*",$a);
	$b = pack("H*",$b);

	die if length($a) != length($b);

	my $c = $a ^ $b;
	return unpack("H*",$c);
	}

return 1;
