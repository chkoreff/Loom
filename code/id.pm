use strict;

# Return true if string is a valid 32 character (128 bit) hexadecimal value.

sub valid_id
	{
	my $str = shift;

	return 0 if !defined $str || $str eq "";
	return 0 if length($str) != 32;
	return 1 if $str =~ /^[a-f0-9]{32}$/;
	return 0;
	}

# Return true if string is a valid 64 character (256 bit) hexadecimal value.

sub valid_hash
	{
	my $str = shift;

	return 0 if !defined $str || $str eq "";
	return 0 if length($str) != 64;
	return 1 if $str =~ /^[a-f0-9]{64}$/;
	return 0;
	}

# Do a logical exclusive-or operation on the two IDs.

sub xor_hex
	{
	my $a = shift;
	my $b = shift;

	$a = pack("H*",$a);
	$b = pack("H*",$b);

	die if length($a) != length($b);

	my $c = $a ^ $b;
	return unpack("H*",$c);
	}

sub fold_hash
	{
	my $hash = shift;   # packed binary

	die if length($hash) != 32;

	my $key = substr($hash,0,16) ^ substr($hash,16,16);
	return $key;
	}

return 1;
