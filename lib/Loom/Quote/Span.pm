package Loom::Quote::Span;
use strict;

# This module converts text to and from the "span" format:
#
#   len str len str ...
#
# where len is a length byte (0..255) and str is a string of bytes of that
# length.  As long as the len byte is greater than zero, the text continues.
# When the len byte is 0, that indicates the end of the text.

sub new
	{
	my $class = shift;
	my $s = bless({},$class);
	return $s;
	}

sub quote_span
	{
	my $s = shift;
	my $text = shift;

	my $pos = 0;
	my $quoted = "";

	$s->quote_span_run($text, \$pos, length($text), \$quoted);
	return $quoted;
	}

sub unquote_span
	{
	my $s = shift;
	my $quoted = shift;

	my $pos = 0;
	my $text = "";

	$s->unquote_span_run($quoted, \$pos, \$text);
	return $text;
	}

sub quote_span_run
	{
	my $s = shift;
	my $l_str = shift;
	my $pos = shift;    # reference
	my $len = shift;
	my $q_str = shift;  # reference

	my $span = 0;

	while ($$pos < $len)
		{
		$$pos++;
		$span++;

		if ($span == 255 || $$pos == $len)
			{
			$$q_str .= chr($span);
			$$q_str .= substr($l_str, $$pos - $span, $span);
			$span = 0;
			}
		}

	$$q_str .= "\000";
	}

sub unquote_span_run
	{
	my $s = shift;
	my $q_str = shift;
	my $pos = shift;    # reference
	my $l_str = shift;  # reference

	my $len = length($q_str);

	while (1)
		{
		last if $$pos >= $len;
		my $span = ord(substr($q_str,$$pos,1));
		$$pos += ($span + 1);
		last if $span == 0;
		$$l_str .= substr($q_str, $$pos - $span, $span);
		}
	}

sub pad_quote
	{
	my $s = shift;
	my $text = shift;
	my $blocksize = shift;

	return $s->pad_blocks($s->quote_span($text),$blocksize);
	}

# Pad text with NULs to an even multiple of blocksize.

sub pad_blocks
	{
	my $s = shift;
	my $text = shift;
	my $blocksize = shift;

	my $len = length($text);

	my $num_whole_blocks = int($len / $blocksize);
	my $num_trail_bytes = $len - $blocksize * $num_whole_blocks;

	if ($num_trail_bytes > 0)
		{
		my $num_missing_bytes = $blocksize - $num_trail_bytes;
		$text .= "\000" x $num_missing_bytes;  # pad with nuls
		}

	die if (length($text) % $blocksize) != 0;

	return $text;
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
