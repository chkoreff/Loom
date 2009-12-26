package Loom::Random;
use strict;
use Loom::Crypt::AES_CBC;

=pod

=head1 NAME

Strong random number generator

=cut

sub new
	{
	my $class = shift;
	my $entropy = shift;  # optional, defaults to /dev/urandom

	$entropy = "/dev/urandom" if !defined $entropy;
	$entropy = Loom::Random::Source->new($entropy) if ref($entropy) eq "";

	my $s = bless({},$class);
	$s->{entropy} = $entropy;
	$s->{encrypt} = undef;
	$s->{count} = 0;  # use new key when count reaches zero
	return $s;
	}

# Get a random 16-byte quantity.

sub get
	{
	my $s = shift;

	my $seed = $s->{entropy}->get;

	die if !defined $seed;
	die if length($seed) != 16;

	$s->refresh($seed) if $s->{count} == 0;
	$s->{count}--;

	die if $s->{count} < 0;

	return $s->{encrypt}->encrypt($seed);
	}

# Get a random unsigned long.  This can be useful as a seed to "srand" when
# you want to generate lower-strength random numbers with "rand()", e.g.:
#   srand( Loom::Random->new->get_ulong );

sub get_ulong
	{
	my $s = shift;

	return unpack("L",$s->get);
	}

# Refresh the crypto key which we use to encrypt the entropy source.  We
# do this automatically after every 32 random numbers generated.

sub refresh
	{
	my $s = shift;
	my $seed = shift;

	die if !defined $seed;
	die if length($seed) != 16;

	# If we already have a crypto object, push the seed into it and
	# use the result as the IV of the new crypto object.

	my $iv = defined $s->{encrypt}
		? $s->{encrypt}->encrypt($seed)
		: "\000" x 16;

	$s->{encrypt} = Loom::Crypt::AES_CBC->new($seed,$iv);
	$s->{count} = 32;  # use new key every 32 rounds

	return;
	}

# LATER maybe an XOR object for doing distinct pseudo-random streams?

package Loom::Random::Source;
use strict;
use Loom::File;

sub new
	{
	my $class = shift;
	my $name = shift;

	my $s = bless({},$class);
	$s->{file} = Loom::File->new($name);
	$s->{file}->read;
	return $s;
	}

sub get
	{
	my $s = shift;

	return $s->{file}->get_bytes(16);
	}

return 1;

__END__

# Copyright 2007 Patrick Chkoreff
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
