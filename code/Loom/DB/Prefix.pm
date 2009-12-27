package Loom::DB::Prefix;
use strict;

=pod

=head1 NAME

Loom::DB::Prefix - Wrap a prefix around a put/get db

=cut

sub new
	{
	my $class = shift;
	my $db = shift;
	my $prefix = shift;

	my $s = bless({},$class);
	$s->{db} = $db;
	$s->{prefix} = $prefix;
	return $s;
	}

sub get
	{
	my $s = shift;
	my $key = shift;

	return "" if !defined $key || ref($key) ne "";

	return $s->{db}->get($s->{prefix} . $key);
	}

sub put
	{
	my $s = shift;
	my $key = shift;
	my $val = shift;

	return if !defined $key || ref($key) ne "";

	return $s->{db}->put($s->{prefix} . $key, $val);
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
