package Loom::KV::Nest;
use strict;
use Loom::Quote::C;

=pod

=head1 NAME

Elaborate nested KV (key-value) format

=head1 DESCRIPTION

LATER: Note that we do not currently use this anywhere except in a test.
=cut

sub new
	{
	my $class = shift;

	my $s = bless({},$class);
	$s->{C} = Loom::Quote::C->new;
	return $s;
	}

# Create a nested hash from a text description.
sub parse
	{
	my $s = shift;
	my $text = shift;

	$text = "" if !defined $text;

	my $mode = "K";
	my $key = "";

	my @stack = ({});

	for my $line (split("\n",$text))
		{
		$line =~ s/\015$//;  # chop any trailing CR
		$line =~ s/^\s+//;   # chop any leading white space
		next if $line =~ /^\s*$/;  # ignore blank lines
		next if $line =~ /^#/;     # ignore comments

		if ($mode eq "K")
			{
			if ($line =~ /^:/)
				{
				$key = $s->{C}->unquote(substr($line,1));
				$mode = "V";
				}
			elsif ($line =~ /^\)/)
				{
				shift @stack;
				}
			elsif ($line =~ /^\((.*)$/)
				{
				my $leg = $s->{C}->unquote($1);

				my $next = $stack[0]->{$leg};
				if (!defined $next)
					{
					$next = {};
					$stack[0]->{$leg} = $next;
					}

				unshift @stack, $next;
				}
			else
				{
				$mode = "E";
				}
			}
		elsif ($mode eq "V")
			{
			if ($line =~ /^=/)
				{
				my $val = $s->{C}->unquote(substr($line,1));
				$stack[0]->{$key} = $val;

				$mode = "K";
				}
			else
				{
				$mode = "E";
				}
			}
		}

	return $stack[0];
	}

# Create a text description from a nested hash.
sub string
	{
	my $s = shift;
	my $hash = shift;
	my $indent = shift;  # optional, default " " (one space)
	my $level = shift;   # optional, default 0

	$indent = " " if !defined $indent;
	$level = 0 if !defined $level;

	my $prefix = $indent x $level;

	my $str = "";

	for my $key (sort keys %$hash)
		{
		my $val = $hash->{$key};
		next if !defined $val;
		if (ref($val) eq "")
			{
			$str .= "$prefix:".$s->{C}->quote($key)."\n";
			$str .= "$prefix=".$s->{C}->quote($val)."\n";
			}
		else
			{
			$str .= "$prefix(".$s->{C}->quote($key)."\n";
			$str .= $s->string($val,$indent,$level+1);
			$str .= "$prefix)\n";
			}
		}

	return $str;
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
