package Loom::DB::Trans_Mem;
use strict;
use Loom::DB::Mem;
use Loom::DB::Trans;

=pod

=head1 NAME

Transaction layer (get/put/commit/cancel) over an in-memory db.

=head1 DESCRIPTION

Currently only used in the test suite Loom::Test::DB.

=cut

sub new
	{
	my $class = shift;
	my $hash = shift;  # optional

	return Loom::DB::Trans->new( Loom::DB::Mem->new($hash) );
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
