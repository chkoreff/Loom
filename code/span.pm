package span;
use strict;

sub quote
	{
	my $in = \shift;
	my $pos = \shift;

	die if !defined $$pos;

	my $len = length($$in);
	my $out = "";

	while (1)
		{
		my $span = $len - $$pos;
		$span = 0 if $span < 0;
		$span = 255 if $span > 255;

		$out .= chr($span);
		return $out if $span <= 0;

		$out .= substr($$in, $$pos, $span);
		$$pos += $span;
		}
	}

sub unquote
	{
	my $in = \shift;
	my $pos = \shift;

	die if !defined $$pos;

	my $len = length($$in);
	my $out = "";

	while (1)
		{
		last if $$pos >= $len;  # should not happen if well-formed
		my $span = ord(substr($$in,$$pos,1));
		$$pos += ($span + 1);
		last if $span == 0;
		$out .= substr($$in, $$pos - $span, $span);
		}

	return $out;
	}

return 1;
