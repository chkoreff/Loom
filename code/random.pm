use strict;
use random_stream;

my $g_random;
my $g_random_buffer = "";

# Return a 128-bit random quantity (packed binary).
sub random_id
	{
	$g_random = random_new() if !defined $g_random;
	return random_get($g_random);
	}

# Return a random unsigned long value.
sub random_ulong
	{
	$g_random = random_new() if !defined $g_random;
	return random_get_ulong($g_random);
	}

sub random_byte
	{
	$g_random_buffer = random_id() if $g_random_buffer eq "";

	my $byte = substr($g_random_buffer,0,1);
	$g_random_buffer = substr($g_random_buffer,1);

	return $byte;
	}

# We make sure that the random byte values mod N result in a
# true uniform distribution across 0..N-1 so there's no bias.

sub random_tiny_int
	{
	my $N = shift;  # the modulus (1..256)

	die if $N < 1 || $N > 256;

	my $top_byte = $N * int(256 / $N) - 1;

	my $num_tries = 0;

	while (1)
		{
		my $val = ord(random_byte());

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
sub random_dice_roll
	{
	return 1 + random_tiny_int(6);
	}

return 1;
