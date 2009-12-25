package Loom::Crypt::CBC;
use strict;

=pod

=head1 NAME

CBC (Chained Block Cipher) mode on any block cipher

=head1 DESCRIPTION

The initial value (iv) is optional.  If specified, it must have the same
length as the cipher blocksize.  If omitted, it defaults to a string of
NUL bytes of the proper length.

Note that all text passed to the decrypt and encrypt routines must have the
same length as the cipher blocksize.

=cut

sub new
	{
	my $class = shift;
	my $cipher = shift;
	my $iv = shift;  # optional

	my $s = bless({},$class);
	$s->{cipher} = $cipher;
	$s->reset($iv);
	return $s;
	}

sub blocksize
	{
	my $s = shift;
	return $s->{cipher}->blocksize;
	}

# Reset the initial value (iv) used in chaining.
sub reset
	{
	my $s = shift;
	my $iv = shift;  # optional

	$iv = "\000" x $s->blocksize if !defined $iv;
	$s->{iv} = $iv;

	die if length($iv) != $s->blocksize;

	return;
	}

# Decrypt a single block.
sub decrypt
	{
	my $s = shift;
	my $crypt = shift;

	die if !defined $crypt;
	die if length($crypt) != length($s->{iv});

	my $block = $s->{cipher}->decrypt($crypt);
	my $plain = $s->{iv} ^ $block;
	$s->{iv} = $crypt;

	return $plain;
	}

# Encrypt a single block.
sub encrypt
	{
	my $s = shift;
	my $plain = shift;

	die if !defined $plain;
	die if length($plain) != length($s->{iv});

	my $block = $s->{iv} ^ $plain;
	my $crypt = $s->{cipher}->encrypt($block);
	$s->{iv} = $crypt;

	return $crypt;
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
