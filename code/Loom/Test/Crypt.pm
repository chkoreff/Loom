package Loom::Test::Crypt;
use strict;
use Loom::Crypt::Span;
use Loom::Random;

=pod

=head1 NAME

Test suite for crypto operations

=cut

sub new
	{
	my $class = shift;
	my $trace = shift;

	my $s = bless({},$class);
	$s->{trace} = $trace;
	return $s;
	}

sub run
	{
	my $s = shift;

	my $genrand = Loom::Random->new;
	my $key = $genrand->get;

	$s->run_cipher_type("Loom::Crypt::Span",$key);

	return;
	}

sub run_cipher_type
	{
	my $s = shift;
	my $cipher_type = shift;
	my $key = shift;

	my $key_len = length($key);
	my $q_key = unpack("H*",$key);

	print <<EOM if $s->{trace};
Begin crypto test type $cipher_type key = $q_key (length $key_len).
EOM

	$s->{cipher} = $cipher_type->new($key);

	# A few miscellaneous tests.

	$s->test_crypto_case("", "null string");
	$s->test_crypto_case("a", "the letter 'a'");
	$s->test_crypto_case("abcdefghijklmnopqrstuvwxyz", "the alphabet");
	$s->test_crypto_case("abcdefghijklmnopqrstuvwxyz" x 18,
		"18 copies of the alphabet");

	# Test many lengths.
	{
	for my $count (0 .. 1000)
		{
		$s->test_crypto_case("abc" x $count, "$count copies of 'abc'");
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

	print <<EOM if $s->{trace};
Begin test of large value round trip with $len_large_string bytes ...
EOM

	$s->test_crypto_case($large_string,
		"large string of $len_large_string bytes");

	my $elapsed = time - $beg_time;

	print <<EOM if $s->{trace};
... That took $elapsed seconds.
EOM
	}

	delete $s->{cipher};

	print <<EOM if $s->{trace};
Finished crypt test type $cipher_type.
EOM

	return;
	}

sub test_crypto_case
	{
	my $s = shift;
	my $plain = shift;
	my $label = shift;

	my $cipher = $s->{cipher};

	my $crypt = $cipher->encrypt($plain);
	my $test = $cipher->decrypt($crypt);

	if ($test ne $plain)
		{
		print STDERR <<EOM;
!!! failure: $label
EOM
		die;
		}

	print "success: $label\n" if $s->{trace};

	return;
	}

return 1;

__END__

# Copyright 2008 Patrick Chkoreff
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
