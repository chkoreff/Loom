package Loom::DB::Mem;
use strict;

=pod

=head1 NAME

In-memory db with get/put/update

=head1 DESCRIPTION

The update routine makes it easy to wrap a Loom::DB::Trans around it.

LATER This module is not currently used.

=cut

sub new
	{
	my $class = shift;
	my $hash = shift;  # optional

	my $s = bless({},$class);
	$hash = {} if !defined $hash;
	$s->{hash} = $hash;
	return $s;
	}

sub get
	{
	my $s = shift;
	my $key = shift;

	return "" if !defined $key || ref($key) ne "";

	my $val = $s->{hash}->{$key};
	$val = "" if !defined $val || ref($val) ne "";
	return $val;
	}

sub put
	{
	my $s = shift;
	my $key = shift;
	my $val = shift;

	return if !defined $key || ref($key) ne "";
	$val = "" if !defined $val;
	return if ref($val) ne "";

	if ($val eq "")
		{
		delete $s->{hash}->{$key};
		}
	else
		{
		$s->{hash}->{$key} = "".$val;
			# prepend null to force numbers to be stored as strings
		}

	return;
	}

sub update
	{
	my $s = shift;
	my $new = shift;
	my $old = shift;

	# Check any specified old values to make sure they still hold.

	for my $key (keys %$new)
		{
		my $old_val = $old->{$key};
		next if !defined $old_val;

		my $curr_val = $s->{hash}->{$key};
		next if defined $curr_val && $curr_val eq $old_val;

		return 0;  # an old value didn't match the current value
		}

	# Everything matched.  Update all the new keys.

	for my $key (keys %$new)
		{
		my $new_val = $new->{$key};

		next if !defined $new_val;
			# Don't update if new value is undefined.

		$s->put($key,$new_val);
		}

	return 1;
	}

return 1;

__END__

# Copyright 2006 Patrick Chkoreff
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
