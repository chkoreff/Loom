package Loom::Crypt::Span;
use strict;
use Loom::Crypt::AES_CBC;
use Loom::Crypt::Blocks;
use Loom::Quote::Span;

=pod

=head1 NAME

Encryption and decryption of arbitrary text using "span" encoding.

=head1 DESCRIPTION

This uses an AES cipher and automatically pads to 16-byte blocks using the
"span" encoding technique.

SYNOPSIS:

  my $key = [packed binary key:  16, 24, or 32 bytes]
  my $cipher = Loom::Crypt::Span->new($key);
  my $plain = [arbitrary text];
  my $crypt = $cipher->encrypt($plain);
  my $test = $cipher->decrypt($crypt);
  die if $test ne $plain;

With this module you can encrypt and decrypt arbitrary strings without
worrying about block sizes and padding.  Each encrypt and decrypt operation
is self-contained and repeatable -- there is no chaining of state across
separate calls.

Text is first converted into the "span" format (len str len str ...) and
padded with NUL bytes so it's a multiple of the block size.  Then the block
cipher is applied to the blocks in the encoded text.

=cut

sub new
	{
	my $class = shift;
	my $key = shift;

	my $s = bless({},$class);
	$s->{cipher} = Loom::Crypt::AES_CBC->new($key);  # single-block cipher
	$s->{cipher} = Loom::Crypt::Blocks->new($s->{cipher});  # multi-block cipher
	$s->{quote} = Loom::Quote::Span->new;
	return $s;
	}

# Cipher arbitrary text with padding.

sub encrypt
	{
	my $s = shift;
	my $text = shift;

	return $s->encrypt_blocks( $s->pad($text) );
	}

sub decrypt
	{
	my $s = shift;
	my $text = shift;

	return $s->unpad( $s->decrypt_blocks($text) );
	}

# Cipher blocks directly without padding.

sub encrypt_blocks
	{
	my $s = shift;
	my $text = shift;

	return $s->{cipher}->encrypt($text);
	}

sub decrypt_blocks
	{
	my $s = shift;
	my $text = shift;

	return $s->{cipher}->decrypt($text);
	}

# Padding routines.

sub pad
	{
	my $s = shift;
	my $text = shift;

	my $blocksize = $s->{cipher}->blocksize;

	return $s->{quote}->pad_quote($text,$blocksize);
	}

sub unpad
	{
	my $s = shift;
	my $text = shift;

	return $s->{quote}->unquote_span($text);
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
