package Loom::DB::File;
use strict;

=pod

=head1 NAME

A get/update layer over a directory object.

=head1 DESCRIPTION

Converts the Loom::File directory interface to a simple get/update
interface used by the transaction layer Loom::DB::Trans.

=cut

sub new
	{
	my $class = shift;
	my $dir = shift;

	my $s = bless({},$class);
	$s->{dir} = $dir;
	return $s;
	}

sub get
	{
	my $s = shift;
	my $key = shift;

	my $file = $s->{dir}->child($key);
	return "" if !defined $file;

	my $val = $file->get;
	$file->release;

	return "" if !defined $val;
	return $val;
	}

# TODO include "put" to be like Loom::DB::Mem

sub update
	{
	my $s = shift;
	my $new = shift;
	my $old = shift;

	return $s->{dir}->update($new,$old);
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
