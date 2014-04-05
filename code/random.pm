package random;
use strict;
use random_stream;

my $g_source;
my $g_buffer = "";

# Return a 128-bit random quantity (packed binary).
sub id
	{
	$g_source = random_stream::new() if !defined $g_source;
	return random_stream::get($g_source);
	}

# Return a random id in hex format.
sub hex
	{
	return unpack("H*",id());
	}

# Return a random unsigned long value.
sub ulong
	{
	$g_source = random_stream::new() if !defined $g_source;
	return random_stream::get_ulong($g_source);
	}

sub byte
	{
	$g_buffer = id() if $g_buffer eq "";

	my $byte = substr($g_buffer,0,1);
	$g_buffer = substr($g_buffer,1);

	return $byte;
	}

# We make sure that the random byte values mod N result in a
# true uniform distribution across 0..N-1 so there's no bias.

sub tiny_int
	{
	my $N = shift;  # the modulus (1..256)

	die if $N < 1 || $N > 256;

	my $top_byte = $N * int(256 / $N) - 1;

	my $num_tries = 0;

	while (1)
		{
		my $val = ord(byte());

		if ($val <= $top_byte)
			{
			my $result = $val % $N;
			return $result;
			}
		else
			{
			# Byte value is too large, try again.
			$num_tries++;
			if ($num_tries > 100)
				{
				die "something is wrong with random number generator!";
				}
			}
		}
	}

# Return a random number in the range 1 through 6.
sub dice_roll
	{
	return 1 + tiny_int(6);
	}

return 1;
