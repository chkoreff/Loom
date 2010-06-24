package Loom::Crypt::Span;
use strict;
use Loom::Crypt::AES_CBC;
use Loom::Crypt::Blocks;

=pod

=head1 NAME

Encryption and decryption of arbitrary text using "span" encoding.

=head1 DESCRIPTION

This pads the text to an even number of 16-byte blocks and encrypts them with
an AES cipher.

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

PADDING METHOD:

Text is first converted into the "span" format and padded with NUL bytes so
it's a multiple of the block size.  Then the block cipher is applied to the
blocks in the encoded text.

This "span" format is:

    len str len str ...

where len is a length byte (0..255) and str is a string of bytes of that
length.  As long as the len byte is greater than zero, the text continues.
When the len byte is 0, that indicates the end of the text.

This format allows distinct encrypted strings to be stored end-to-end in a
contiguous block of memory without any leading length indicators, and easily
decrypted in a streaming fashion without any confusion about where each string
ends.

=cut

sub new
	{
	my $class = shift;
	my $key = shift;

	my $cipher = Loom::Crypt::AES_CBC->new($key);  # single-block cipher
	$cipher = Loom::Crypt::Blocks->new($cipher);   # multi-block cipher
	return $class->with_cipher($cipher);
	}

sub with_cipher
	{
	my $class = shift;
	my $cipher = shift;  # any block cipher

	my $s = bless({},$class);
	$s->{cipher} = $cipher;
	return $s;
	}

# Return the inner block cipher.
sub cipher
	{
	my $s = shift;
	return $s->{cipher};
	}

sub encrypt
	{
	my $s = shift;
	my $text = shift;

	die if !defined $text;

	# Quote the text into the span format.

	my $quoted = "";
	{
	my $len = length($text);
	my $pos = 0;
	my $span = 0;

	while ($pos < $len)
		{
		$pos++;
		$span++;

		if ($span == 255 || $pos == $len)
			{
			$quoted .= chr($span);
			$quoted .= substr($text, $pos - $span, $span);

			$span = 0;
			}
		}

	$quoted .= "\000";
	$text = "";
	}

	# Pad the quoted text with NULs to an even multiple of blocksize.

	my $blocksize = $s->{cipher}->blocksize;
	my $len = length($quoted);

	my $num_whole_blocks = int($len / $blocksize);
	my $num_trail_bytes = $len - $blocksize * $num_whole_blocks;

	if ($num_trail_bytes > 0)
		{
		my $num_missing_bytes = $blocksize - $num_trail_bytes;
		$quoted .= "\000" x $num_missing_bytes;  # pad with nuls
		}

	die if (length($quoted) % $blocksize) != 0;

	return $s->{cipher}->encrypt($quoted);
	}

sub decrypt
	{
	my $s = shift;
	my $text = shift;

	die if !defined $text;

	$text = $s->{cipher}->decrypt($text);

	my $pos = 0;
	my $unquoted = "";

	my $len = length($text);

	while (1)
		{
		last if $pos >= $len;
		my $span = ord(substr($text,$pos,1));
		$pos += ($span + 1);
		last if $span == 0;
		$unquoted .= substr($text, $pos - $span, $span);
		}

	return $unquoted;
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
