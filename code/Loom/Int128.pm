package Loom::Int128;
use Bit::Vector;
use strict;

=pod

=head1 NAME

128-bit integers

=cut

my $g_num_bits = 128;

# Convert decimal to Bit::Vector value.
#
# max = +2^128-1 =  170141183460469231731687303715884105727
# min = -2^128   = -170141183460469231731687303715884105728
#
# Since we know there's a maximum of 39 digits, we go ahead and check that
# first even though the Bit::Vector routines detect over/underflow.  Their
# detection of overflow is spotty -- they just return a negative number.
# Therefore I have an additional check to ensure that the sign of the result
# is the expected sign.

sub from_dec
	{
	my $class = shift;
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

	my $s = undef;

	if (defined $num)
		{
		$s = bless({},$class);
		$s->{bv} = $num;
		}

	return $s;
	}

sub to_dec
	{
	my $s = shift;

	return $s->{bv}->to_Dec;
	}

sub is_zero
	{
	my $s = shift;

	return $s->{bv}->is_empty;
	}

# Return the sign of the number:  1 for negative, 0 for non-negative.

sub sign
	{
	my $s = shift;

	return $s->{bv}->bit_test($g_num_bits-1);
	}

sub add
	{
	my $s = shift;
	my $amount = shift;

	$s->{bv}->add($s->{bv}, $amount->{bv}, 0);
	}

sub subtract
	{
	my $s = shift;
	my $amount = shift;

	$s->{bv}->subtract($s->{bv}, $amount->{bv}, 0);
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
