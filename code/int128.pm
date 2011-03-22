use strict;
use Bit::Vector;

=pod

=head1 NAME

128-bit integers

=cut

my $g_num_bits = 128;

# Convert decimal to a 128-bit integer value.
#
# max = +2^128-1 =  170141183460469231731687303715884105727
# min = -2^128   = -170141183460469231731687303715884105728
#
# Since we know there's a maximum of 39 digits, we go ahead and check that
# first even though the Bit::Vector routines detect over/underflow.  Their
# detection of overflow is spotty -- they just return a negative number.
# Therefore I have an additional check to ensure that the sign of the result
# is the expected sign.

sub int128_from_dec
	{
	my $str = shift;

	return undef if !defined $str || $str eq "";
	return undef if $str !~ /^-?\d{1,39}$/;

	my $num;

	# Using eval to catch error if $str malformed.
	eval { $num = Bit::Vector->new_Dec($g_num_bits,$str); };

	if (defined $num)
		{
		my $sign = $num->bit_test($g_num_bits-1);
		my $check_sign = (substr($str,0,1) eq "-") ? 1 : 0;
		$num = undef if $sign != $check_sign;
		}

	return $num;
	}

# Convert 128-bit integer to decimal.

sub int128_to_dec
	{
	my $num = shift;

	return $num->to_Dec;
	}

# Determine if the number is zero.

sub int128_is_zero
	{
	my $num = shift;

	return $num->is_empty;
	}

# Return the sign of the number:  1 for negative, 0 for non-negative.

sub int128_sign
	{
	my $num = shift;

	return $num->bit_test($g_num_bits-1);
	}

# Add amount to the number destructively.

sub int128_add
	{
	my $num = shift;
	my $amount = shift;

	$num->add($num, $amount, 0);
	}

# Subtract amount from the number destructively.

sub int128_sub
	{
	my $num = shift;
	my $amount = shift;

	$num->subtract($num, $amount, 0);
	}

# Increment the number destructively.

sub int128_inc
	{
	my $num = shift;

	$num->increment;
	}

return 1;
