use strict;
use crypt_span;
use random;

=pod

=head1 NAME

Test suite for crypto operations

=cut

my $g_trace_test_crypt = 0;
my $g_test_key;

sub test_crypto_case
	{
	my $plain = shift;
	my $label = shift;

	my $crypt = span_encrypt($g_test_key,$plain);
	my $test = span_decrypt($g_test_key,$crypt);

	if ($test ne $plain)
		{
		print STDERR <<EOM;
!!! failure: $label
EOM
		die;
		}

	print "success: $label\n" if $g_trace_test_crypt;

	return;
	}

sub test_crypt_run
	{
	$g_test_key = random_id();

	my $key_len = length($g_test_key);
	my $q_key = unpack("H*",$g_test_key);

	print <<EOM if $g_trace_test_crypt;
Begin crypto test key = $q_key (length $key_len).
EOM

	# A few miscellaneous tests.

	test_crypto_case("", "null string");
	test_crypto_case("a", "the letter 'a'");
	test_crypto_case("abcdefghijklmnopqrstuvwxyz", "the alphabet");
	test_crypto_case("abcdefghijklmnopqrstuvwxyz" x 18,
		"18 copies of the alphabet");

	# Test many lengths.
	{
	for my $count (0 .. 1000)
		{
		test_crypto_case("abc" x $count, "$count copies of 'abc'");
		}
	}

	# Test large string.
	{
	my $beg_time = time;

	my $large_string = "abcdefghijklmnopqrstuvwxyz" x 32000;

	# 32000 reps = 832,000 bytes : 4 seconds
	# 16000 reps = 416,000 bytes : 2 seconds
	#  8000 reps = 208,000 bytes : 1 seconds

	my $len_large_string = length($large_string);

	print <<EOM if $g_trace_test_crypt;
Begin test of large value round trip with $len_large_string bytes ...
EOM

	test_crypto_case($large_string,
		"large string of $len_large_string bytes");

	my $elapsed = time - $beg_time;

	print <<EOM if $g_trace_test_crypt;
... That took $elapsed seconds.
EOM
	}

	print <<EOM if $g_trace_test_crypt;
Finished crypt test
EOM

	$g_test_key = "";

	return;
	}

return 1;
