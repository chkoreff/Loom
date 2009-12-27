package Loom::Format::Lines;
use strict;

sub new
	{
	my $class = shift;

	my $s = bless({},$class);
	$s->{text} = "";
	$s->{pos} = 0;
	return $s;
	}

sub put
	{
	my $s = shift;

	for (@_)
		{
		$s->{text} .= $_ if defined $_;
		}

	return;
	}

sub get
	{
	my $s = shift;

	my $index = index($s->{text},"\012",$s->{pos});
	return if $index < 0;

	my $line = substr($s->{text},$s->{pos},$index-$s->{pos});
	$line =~ s/\015$//;  # chop any trailing CR

	$s->{pos} = $index + 1;

	if ($s->{pos} >= length($s->{text}))
		{
		$s->{pos} = 0;
		$s->{text} = "";
		}

	return $line;
	}

sub finish
	{
	my $s = shift;

	my $remain = substr($s->{text},$s->{pos});
	$s->{text} = "";
	$s->{pos} = 0;
	return $remain;
	}

package Loom::Format::Lines::Out;
use strict;

sub new
	{
	my $class = shift;

	my $s = bless({},$class);
	return $s;
	}

sub put
	{
	my $s = shift;
	my $line = shift;

	return "$line\n";
	}

return 1;

__END__

# Copyright 2009 Patrick Chkoreff
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
