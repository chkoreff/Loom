package random_stream;
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

sub new
	{
	my $source = shift;
	$source = "/dev/urandom" if !defined $source;

	my $stream = {};

	$stream->{entropy} = file::new($source);
	file::open_read($stream->{entropy});

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
		? aes::encrypt($stream->{encrypt},$seed)
		: "\000" x 16;

	$stream->{encrypt} = aes::new($seed,$iv);
	$stream->{count} = 32;  # use new key every 32 rounds

	return;
	}

# Get the next 128-bit random number from the stream.  This returns 16 bytes of
# packed binary data.  To display it in hex you can say unpack("H*",$id).

sub get
	{
	my $stream = shift;
	die if !defined $stream;

	my $seed = file::get_bytes($stream->{entropy},16);

	die if !defined $seed;
	die if length($seed) != 16;

	random_refresh($stream,$seed) if $stream->{count} == 0;
	$stream->{count}--;

	die if $stream->{count} < 0;

	return aes::encrypt($stream->{encrypt},$seed);
	}

# Get a random unsigned long.  This can be useful as a seed to "srand" when
# you want to generate lower-strength random numbers with "rand()", e.g.:
#   srand( random_stream::get_ulong( random_stream::new() ) );

sub get_ulong
	{
	my $stream = shift;

	return unpack("L",get($stream));
	}

return 1;
