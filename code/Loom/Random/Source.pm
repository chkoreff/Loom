package Loom::Random::Source;
use strict;
use Loom::File;

=pod

=head1 NAME

Make a file look like a source of 128-bit numbers.

=cut

sub new
	{
	my $class = shift;
	my $name = shift;

	my $s = bless({},$class);
	$s->{file} = Loom::File->new($name);
	$s->{file}->read;
	return $s;
	}

sub get
	{
	my $s = shift;

	return $s->{file}->get_bytes(16);
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
