use strict;
use aes;
use file;

=pod

=head1 NAME

# Strong random number generator

=cut

# Get a stream of random 128-bit numbers using entropy gathered from the given
# source file.  The source file defaults to "/dev/urandom".  For repeatable
# numbers you can pass in "/dev/zero".

sub random_new
	{
	my $source = shift;
	$source = "/dev/urandom" if !defined $source;

	my $stream = {};

	$stream->{entropy} = file_new($source);
	file_read($stream->{entropy});

	$stream->{encrypt} = undef;
	$stream->{count} = 0;  # use new key when count reaches zero
	return $stream;
	}

# Refresh the crypto key which we use to encrypt the entropy source.  We
# do this automatically after every 32 random numbers generated.

sub random_refresh
	{
	my $stream = shift;
	my $seed = shift;

	die if !defined $seed;
	die if length($seed) != 16;

	# If we already have a crypto object, push the seed into it and
	# use the result as the IV of the new crypto object.

	my $iv = defined $stream->{encrypt}
		? aes_encrypt($stream->{encrypt},$seed)
		: "\000" x 16;

	$stream->{encrypt} = aes_new($seed,$iv);
	$stream->{count} = 32;  # use new key every 32 rounds

	return;
	}

# Get the next 128-bit random number from the stream.  This returns 16 bytes of
# packed binary data.  To display it in hex you can say unpack("H*",$id).

sub random_get
	{
	my $stream = shift;
	die if !defined $stream;

	my $seed = file_get_bytes($stream->{entropy},16);

	die if !defined $seed;
	die if length($seed) != 16;

	random_refresh($stream,$seed) if $stream->{count} == 0;
	$stream->{count}--;

	die if $stream->{count} < 0;

	return aes_encrypt($stream->{encrypt},$seed);
	}

# Get a random unsigned long.  This can be useful as a seed to "srand" when
# you want to generate lower-strength random numbers with "rand()", e.g.:
#   srand( random_get_ulong( random_new() ) );

sub random_get_ulong
	{
	my $stream = shift;

	return unpack("L",random_get($stream));
	}

return 1;
