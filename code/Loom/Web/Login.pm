package Loom::Web::Login;
use strict;
use Loom::Digest::SHA256;
use Loom::ID;
use Loom::Web::EZ_Archive;
use Loom::Web::EZ_Grid;

# Session and passphrase operations.
#
# A passphrase is an arbitrary string of between 8 and 255 characters which is
# mapped to a location using a fixed hashing algorithm.  See the "location"
# routine below for details on how this is done.  The mapping uses no salt.
# If you want salt in your hash, add it yourself:  i.e., use a stronger
# passphrase.  There's a browser trick you can use to help with with very long
# passphrases.  Just bookmark the login page with &passphrase=<prefix>, where
# <prefix> is an initial prefix of your passphrase.  When you click that
# bookmark, all you have to enter is the trailing suffix of the passphrase.
#
# A session is a random id which servers as a proxy for the the passphrase
# location in the archive.  The session is the id which is passed around in
# your browser links in the url parameter called "session".  Note that there
# is *always* a session for a given passphrase, but it is changed to a new
# random value upon logout.  If we did not always keep a session in the
# archive, the user might move all her usage tokens away from the passphrase
# location, log out, and then not be able to log back in because there are
# not enough usage tokens to create the session object!  (Wow, the economics
# of usage tokens really makes you think.)
#
# By always keeping a session, we guarantee that the user can always log in
# even if she has *zero* usage tokens at the passphrase location.

my $type_usage = "00000000000000000000000000000000";

sub new
	{
	my $class = shift;
	my $api = shift;

	die if !defined $api;

	my $s = bless({},$class);
	$s->{grid} = Loom::Web::EZ_Grid->new($api);
	$s->{archive} = Loom::Web::EZ_Archive->new($api);
	$s->{id} = Loom::ID->new;
	$s->{hasher} = Loom::Digest::SHA256->new;
	return $s;
	}

# Retrieve the existing session id for this passphrase location.

sub login
	{
	my $s = shift;
	my $passphrase = shift;

	my $loc_object =  $s->location($passphrase);
	my $loc_session_ptr = $s->{id}->xor_hex($loc_object, "0" x 31 . "1");
	my $session = $s->{archive}->touch($loc_session_ptr);
	return $session;
	}

# Destroy the existing session and create a new random one.
#
# This stores the session id immediately "adjacent" to the object.  To compute
# the adjacent location, we XOR the object location with "1", inverting the
# low-order bit.
#
# This XOR technique is a powerful way to associate information with a location
# without actually modifying or looking at the contents of that location.  If
# you need to associate many things with a location, you can store them at any
# number of related locations, e.g. xor(loc,1), xor(loc,2), xor(loc,3) ... etc.

sub logout
	{
	my $s = shift;
	my $session = shift;

	my $loc_object = $s->{archive}->touch($session);
	my $loc_session_ptr = $s->{id}->xor_hex($loc_object, "0" x 31 . "1");

	$s->{archive}->write($session,"",$loc_object);
	$s->{archive}->sell($session,$loc_object);

	$session = $s->{archive}->random_vacant_location;

	$s->{archive}->write($loc_session_ptr,$session,$loc_object);

	$s->{archive}->buy($session,$loc_object);
	$s->{archive}->write($session,$loc_object,$loc_object);
	}

# Map a passphrase to an archive location.  This computes the SHA256 hash of
# the passphrase, and then reduces that 256-bit hash to a 128-bit location by
# XOR-ing the first half with the second half.

sub location
	{
	my $s = shift;
	my $passphrase = shift;

	my $hash = $s->{hasher}->sha256($passphrase);
	my $loc = substr($hash,0,16) ^ substr($hash,16,16);
	$loc = unpack("H*",$loc);

	return $loc;
	}

# Return true if the session is valid.

sub valid_session
	{
	my $s = shift;
	my $session = shift;

	return 0 if !$s->{id}->valid_id($session);

	my $loc_object = $s->{archive}->touch($session);

	return 1 if $s->{id}->valid_id($loc_object);
	return 0;
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
