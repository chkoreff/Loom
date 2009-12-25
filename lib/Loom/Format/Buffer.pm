package Loom::Format::Buffer;
use strict;

sub new
	{
	my $class = shift;

	my $s = bless({},$class);
	$s->{text} = "";
	return $s;
	}

sub put
	{
	my $s = shift;

	$s->{text} .= $_ for @_;
	return;
	}

sub get
	{
	my $s = shift;

	my $text = $s->{text};
	$s->{text} = "";
	return $text;
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
