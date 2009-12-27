package Loom::Crypt::AES_CBC;
use strict;
use Crypt::Rijndael;
use Loom::Crypt::CBC;

=pod

=head1 NAME

Standard AES bit cipher in CBC (Chained Block Cipher) mode.

=head1 DESCRIPTION

The key size must be one of:
  128 bits     (16 bytes)
  192 bits     (24 bytes)
  256 bits     (32 bytes)

The initial value (iv) is optional, with a default value of 16 NUL bytes.
If specified, its length must be a multiple of 16 bytes.

=cut

sub new
	{
	my $class = shift;
	my $key = shift;
	my $iv = shift;  # optional

	my $cipher = new Crypt::Rijndael $key, Crypt::Rijndael::MODE_ECB;
	return Loom::Crypt::CBC->new($cipher,$iv);
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
