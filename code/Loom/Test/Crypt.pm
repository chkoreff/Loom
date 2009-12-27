package Loom::Test::Crypt;
use strict;
use Loom::Crypt;
use Loom::Quote::C;
use Loom::Random;

# TODO integrate somewhere

=pod

=head1 NAME

Test suite for crypto operations

=cut

sub new
	{
	my $class = shift;

	my $s = bless({},$class);r
	$s->{C} = Loom::Quote::C->new;
	return $s;
	}

sub test_crypto
	{
	my $s = shift;

	my $genrand = Loom::Random->new;
	my $key = $genrand->get;

	my $key_len = length($key);
	my $q_key = unpack("H*",$key);

	print STDERR <<EOM;
== begin crypto test with key length $key_len, key = $q_key
EOM

	$s->{cipher} = Loom::Crypt->new($key);

	$s->test_crypto_case("");
	$s->test_crypto_case("a");
	$s->test_crypto_case("abcdefghijklmnopqrstuvwxyz");
	$s->test_crypto_case("abcdefghijklmnopqrstuvwxyz" x 18);

	# Test many lengths

	for (0 .. 1000)
		{
		$s->test_crypto_case("abc" x $_);
		}

	my $beg_time = time;

	#my $large_string = "abcdefghijklmnopqrstuvwxyz" x 8000;
	#my $large_string = "abcdefghijklmnopqrstuvwxyz" x 16000;
	my $large_string = "abcdefghijklmnopqrstuvwxyz" x 32000;

	# 32000 reps = 832,000 bytes : 4 seconds
	# 16000 reps = 416,000 bytes : 2 seconds
	#  8000 reps = 208,000 bytes : 1 seconds

	my $len_large_string = length($large_string);

	print STDERR <<EOM;
begin test of large value round trip with $len_large_string bytes
EOM


	$s->test_crypto_case($large_string);

	delete $s->{cipher};

	my $elapsed = time - $beg_time;

	print STDERR <<EOM;
that took $elapsed seconds
EOM

	print STDERR <<EOM;
== finish crypto test
EOM

	return;
	}

sub test_crypto_case
	{
	my $s = shift;
	my $plain = shift;

	my $cipher = $s->{cipher};

	my $crypt = $cipher->encrypt($plain);
	my $test = $cipher->decrypt($crypt);

	my $q_test = $s->{C}->quote($test);

	if ($test eq $plain)
	{
	print STDERR <<EOM if 0;
== succeed "$plain"
EOM
	}
	else
	{
	print STDERR <<EOM;
== fail    "$plain"
   test    "$q_test"
EOM
	}

	return;
	}

return 1;
