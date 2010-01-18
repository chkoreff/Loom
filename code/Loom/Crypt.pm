package Loom::Crypt;
use strict;
use Loom::Crypt::AES_CBC;
use Loom::Crypt::Blocks;

=pod

=head1 NAME

Simple encryption and decryption of arbitrary pieces of text

=head1 DESCRIPTION

This pads the text to an even number of 16-byte blocks and encrypts them with
an AES cipher.

SYNOPSIS:

  my $key = [packed binary key:  16, 24, or 32 bytes]
  my $cipher = Loom::Crypt->new($key);
  my $plain = [arbitrary text];
  my $crypt = $cipher->encrypt($plain);
  my $test = $cipher->decrypt($crypt);
  die if $test ne $plain;

With this module you can encrypt and decrypt arbitrary strings without
worrying about block sizes and padding.  Each encrypt and decrypt operation
is self-contained and repeatable -- there is no chaining of state across
separate calls.

PADDING METHOD:

Append NUL bytes as necessary and then a single byte 0-15 indicating how many
NUL bytes were used.

=cut

sub new
	{
	my $class = shift;
	my $key = shift;

	my $s = bless({},$class);
	$s->{cipher} = Loom::Crypt::AES_CBC->new($key);  # single-block cipher
	$s->{cipher} = Loom::Crypt::Blocks->new($s->{cipher});  # multi-block cipher
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

	my $len = length($text) + 1;  # allow for pad count byte at end

	my $num_whole_blocks = int($len / $blocksize);
	my $num_trail_bytes = $len - $blocksize * $num_whole_blocks;

	my $num_pad_bytes = 0;

	if ($num_trail_bytes > 0)
		{
		$num_pad_bytes = $blocksize - $num_trail_bytes;
		$text .= "\000" x $num_pad_bytes;  # pad with nuls
		}

	$text .= chr($num_pad_bytes);

	die if (length($text) % $blocksize) != 0;

	return $text;
	}

sub unpad
	{
	my $s = shift;
	my $text = shift;

	my $num_pad_bytes = ord(substr($text,-1,1));
	my $result_length = length($text) - 1 - $num_pad_bytes;

	return substr($text, 0, $result_length);
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
