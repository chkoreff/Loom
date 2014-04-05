package token;
use strict;

# LATER define in terms of $source
# LATER include the extra functions from fexl

# Get the next token with newlines significant.
sub get_nl
	{
	my $in = \shift;
	my $pos = \shift;

	while (1)
		{
		return undef if $$pos >= length($$in);
		my $ch = substr($$in,$$pos,1);
		$$pos++;

		if ($ch eq "\n")
			{
			return "\n";
			}
		elsif ($ch =~ /\s/)
			{
			# Skip white space.
			}
		elsif ($ch eq "#")
			{
			# Skip comment to end of line.
			my $eol = index($$in,"\n",$$pos);
			return undef if $eol < 0;
			my $line = substr($$in,$$pos,$eol - $$pos);
			$$pos = $eol + 1;
			return "\n";
			}
		elsif ($ch eq "~")
			{
			# Gather ending string up to the first white space.
			my $end = "";
			while (1)
				{
				return undef if $$pos >= length($$in);
				$ch = substr($$in,$$pos,1);
				$$pos++;
				last if $ch =~ /\s/;
				$end .= $ch;
				}

			return undef if $end eq "";  # no ending string

			# Gather token characters up to the ending string.

			my $token = "";
			while (1)
				{
				return undef if $$pos >= length($$in);  # no matching end

				$ch = substr($$in,$$pos,1);
				$$pos++;
				$token .= $ch;

				return substr($token,0,-length($end))
					if substr($token,-length($end)) eq $end;
				}
			}
		elsif ($ch eq "\"")
			{
			# Grab token up to ending quote.
			my $token = "";
			while (1)
				{
				return undef if $$pos >= length($$in);
				$ch = substr($$in,$$pos,1);
				$$pos++;
				return $token if $ch eq "\"";
				$token .= $ch;
				}
			}
		else
			{
			# Grab token up to ending white space or end of string.
			my $token = "";
			while (1)
				{
				$token .= $ch;
				return $token if $$pos >= length($$in);
				$ch = substr($$in,$$pos,1);
				return $token if $ch =~ /\s/;
				$$pos++;
				}
			}
		}
	}

# Get the next token but skip newlines.
sub get
	{
	my $in = \shift;
	my $pos = \shift;

	while (1)
		{
		my $token = get_nl($$in,$$pos);
		return if !defined $token;
		return $token if $token ne "\n";
		}
	}

return 1;
