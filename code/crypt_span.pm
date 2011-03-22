use strict;
use aes;
use span;

=pod

=head1 NAME

Encryption and decryption of arbitrary text using "span" encoding.

=head1 DESCRIPTION

This pads the text to an even number of 16-byte blocks and encrypts them with
an AES cipher.

SYNOPSIS:

  my $key = [packed binary key:  16, 24, or 32 bytes]
  my $plain = [arbitrary text];
  my $crypt = span_encrypt($plain);
  my $test = span_decrypt($crypt);
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

sub crypt_blocks
	{
	my $cipher = shift;
	my $encrypt = shift;  # true if encrypt; false if decrypt
	my $in = shift;

	my $len = length($in);
	my $blocksize = aes_blocksize($cipher);
	die if $len % $blocksize != 0;

	aes_reset($cipher);

	my $out = "";
	my $pos = 0;

	while ($pos + $blocksize <= $len)
		{
		my $block = substr($in,$pos,$blocksize);

		$out .= $encrypt
			? aes_encrypt($cipher,$block)
			: aes_decrypt($cipher,$block);

		$pos += $blocksize;
		}

	return $out;
	}

sub span_encrypt
	{
	my $key = shift;
	my $text = shift;

	die if !defined $text;

	my $cipher = aes_new($key);  # single-block cipher

	# Quote the text into the span format.

	my $quoted = span_quote($text,0);

	# Pad the quoted text with NULs to an even multiple of blocksize.

	my $blocksize = aes_blocksize($cipher);
	my $len = length($quoted);

	my $num_whole_blocks = int($len / $blocksize);
	my $num_trail_bytes = $len - $blocksize * $num_whole_blocks;

	if ($num_trail_bytes > 0)
		{
		my $num_missing_bytes = $blocksize - $num_trail_bytes;
		$quoted .= "\000" x $num_missing_bytes;  # pad with nuls
		}

	die if (length($quoted) % $blocksize) != 0;

	return crypt_blocks($cipher,1,$quoted);
	}

sub span_decrypt
	{
	my $key = shift;
	my $text = shift;

	die if !defined $text;

	my $cipher = aes_new($key);  # single-block cipher

	$text = crypt_blocks($cipher,0,$text);

	return span_unquote($text,0);
	}

return 1;
