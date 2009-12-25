package Loom::Qty;
use strict;
use Loom::Int128;

# Creates an object which formats quantities in various ways.  This might not
# be the most elegant way to do these rather tricky functions, but it sure does
# the job reliably.

sub new
	{
	my $class = shift;
	my $s = bless({},$class);
	return $s;
	}

# Format an integer as a ones-complement float.  For example, "-1" renders as
# "-0" (with scale 0).

sub ones_complement_float
	{
	my $s = shift;
	my $value = shift;
	my $scale = shift;
	my $min_precision = shift;
	my $max_precision = shift;

	my $sign = "";
	if ($value =~ /^-/)
		{
		$sign = "-";
		$value = substr($value,1);

		my $bv = Loom::Int128->from_dec($value);
		my $one = Loom::Int128->from_dec("1");

		$bv->subtract($one);
		$value = $bv->to_dec;
		}

	my $q_value =
	$s->twos_complement_float($value,$scale,$min_precision,$max_precision);

	return $sign.$q_value;
	}

# Convert integer to float.  Examples:
#
# ("1234567",3)   => "1234.567"
# ("1230000",4)   => "123"
# ("1230000",4,2) => "123.00"
#
# Return null if not valid in any way.

sub twos_complement_float
	{
	my $s = shift;
	my $int_rep = shift;    # string
	my $scale = shift;      # the float is $int_rep * (10 ^ -$scale)
	my $min_precision = shift;
	my $max_precision = shift;

	$scale = "" if !$s->valid_scale($scale);
	$min_precision = "" if !$s->valid_scale($min_precision);
	$max_precision = "" if !$s->valid_scale($max_precision);

	$scale = 0 if $scale eq "";
	$min_precision = 0 if $min_precision eq "";
	$max_precision = $scale if $max_precision eq "";

	return "" if $int_rep !~ /^-?[0-9]+$/;

	return $int_rep if $scale eq "0";  # just an int, so return it

	my $format = "%0${scale}s";

	my $sign = "";
	if ($int_rep =~ /^-/)
		{
		$sign = "-";
		$int_rep = substr($int_rep,1);
		}

	$int_rep =~ s/^0+//;  # strip any existing leading zeroes
	$int_rep = sprintf($format, $int_rep);
		# pad leading zeroes so length is at least $scale

	my $int_part = substr($int_rep,0,length($int_rep)-$scale);
	$int_part = "0" if $int_part eq "";

	my $frac_part = $scale > 0 ? substr($int_rep,-$scale) : "";
	$frac_part = substr($frac_part,0,$max_precision);

	while (length($frac_part) > $min_precision &&
		substr($frac_part,-1) eq '0')
		{
		substr($frac_part,-1) = "";
		}

	my $float_rep = $sign . $int_part;
	$float_rep .= ".$frac_part" if $frac_part ne "";

	return $float_rep;
	}

# Convert float to integer.  Examples:
#
# ("0.16",6)     => "160000"
# (".000001",6)  => "1"
# ("12345678901234.567890",6) => "12345678901234567890"
#
# Return null string if not valid.  This includes the case where there is too
# much precision in the number, e.g. "0.001" when the scale is only 2.

sub float_to_int
	{
	my $s = shift;
	my $float_rep = shift;   # string
	my $scale = shift;

	$scale = "" if !$s->valid_scale($scale);
	$scale = 0 if $scale eq "";

	return "" if $float_rep !~ /^-?([0-9]*)((?:\.[0-9]+)?)$/;

	my $int_part = $1;
	my $frac_part = $2;

	my $sign = "";
	if ($float_rep =~ /^-/)
		{
		$sign = "-";
		$float_rep = substr($float_rep,1);
		}

	$frac_part = substr($frac_part,1) if $frac_part ne "";
		# drop decimal point

	my $num_zeroes = $scale - length($frac_part);
	return "" if $num_zeroes < 0;  # too much precision

	$frac_part .= '0' x $num_zeroes;
	$frac_part = substr($frac_part,0,$scale);

	my $int_rep = $int_part.$frac_part;

	$int_rep =~ s/^0+//;
	$int_rep = "0" if $int_rep eq "";
	$int_rep = $sign . $int_rep;

	return $int_rep;
	}

# Return true if the string is valid for use as a scale or min_precision
# parameter.  A valid string is either null or a two-digit number.

sub valid_scale
	{
	my $s = shift;
	my $str = shift;

	return 0 if !defined $str;
	return 1 if $str eq "";
	return 0 if length($str) > 2;
	return 1 if $str =~ /^\d{1,2}$/;
	return 0;
	}

return 1;

__END__

# Copyright 2008 Patrick Chkoreff
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
