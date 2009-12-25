package Loom::Strq;
use strict;

sub new
	{
	my $class = shift;

	my $s = bless([@_],$class);
	return $s;
	}

sub parse
	{
	my $s = shift;
	my $string = shift;

	$string .= " ";  # extra space to force out last word

	my $pos = 0;
	my $len = length($string);

	my $in_word = 0;
	my $in_quote = 0;
	my $word = "";
	my $prev_ch = " ";

	while (1)
		{
		my $ch = substr($string,$pos,1);

		if ($in_word)
			{
			if ($in_quote)
				{
				if ($ch eq '"')
					{
					$in_quote = 0;
					}
				else
					{
					$word .= $ch;
					}
				}
			else
				{
				if ($ch =~ /^\s$/)
					{
					$in_word = 0;
					push @$s, $word;
					$word = "";
					}
				elsif ($ch eq '"')
					{
					$in_quote = 1;
					$word .= $ch if $prev_ch eq '"';
					}
				else
					{
					$word .= $ch;
					}
				}
			}
		elsif ($ch !~ /^\s$/)
			{
			$in_word = 1;

			if ($ch eq '"')
				{
				$in_quote = 1;
				}
			else
				{
				$word .= $ch;
				}
			}

		last if $pos >= $len;

		$prev_ch = $ch;
		$pos++;
		}

	return $s;
	}

sub string
	{
	my $s = shift;

	my $string = "";

	for my $item (@$s)
		{
		my $dsp = $item;

		if ($item =~ /[\s"]/ || $item eq "")
			{
			$dsp =~ s/"/""/g;
			$dsp = qq{"$dsp"};
			}

		$string .= " " if $string ne "";
		$string .= $dsp;
		}

	return $string;
	}

# Return the length of the list.
sub length
	{
	my $s = shift;

	return $#$s + 1;
	}

# Return true if the two lists are equal.
sub equal
	{
	my $x = shift;
	my $y = shift;

	return 0 if $#$x != $#$y;

	for (my $pos = 0; $pos <= $#$x; $pos++)
		{
		return 0 if $x->[$pos] ne $y->[$pos];
		}

	return 1;
	}

# Return true if there's a string in the queue.
sub ready
	{
	my $s = shift;
	return $#$s >= 0;
	}

# Put a string at the end of the queue.
sub put
	{
	my $s = shift;
	my $string = shift;

	push @$s, $string;
	return $s;
	}

# Get the string at the front of the queue and remove it.  Return undef if
# the list is empty.
sub get
	{
	my $s = shift;

	return shift @$s;
	}

sub find
	{
	my $s = shift;
	my $string = shift;

	my $pos = 0;

	for my $item (@$s)
		{
		return $pos if $item eq $string;
		$pos++;
		}

	return -1;
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
