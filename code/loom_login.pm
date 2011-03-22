use strict;

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


# Map a passphrase to an archive location.  This computes the SHA256 hash of
# the passphrase, and then reduces that 256-bit hash to a 128-bit location by
# XOR-ing the first half with the second half.

sub passphrase_location
	{
	my $passphrase = shift;

	my $hash = sha256($passphrase);
	my $loc = fold_hash($hash);
	$loc = unpack("H*",$loc);

	return $loc;
	}

# Retrieve the existing session id for this passphrase location.

sub passphrase_session
	{
	my $passphrase = shift;

	my $loc_object =  passphrase_location($passphrase);
	my $loc_session_ptr = xor_hex($loc_object, "0" x 31 . "1");
	my $session = archive_touch($loc_session_ptr);
	return $session;
	}

# Return true if the session is valid.

sub valid_session
	{
	my $session = shift;

	return 0 if !valid_id($session);

	my $loc_object = archive_touch($session);

	return 1 if valid_id($loc_object);
	return 0;
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

sub kill_session
	{
	my $session = shift;

	my $loc_object = archive_touch($session);
	my $loc_session_ptr = xor_hex($loc_object, "0" x 31 . "1");

	archive_write($session,"",$loc_object);
	archive_sell($session,$loc_object);

	$session = archive_random_vacant_location();

	archive_write($loc_session_ptr,$session,$loc_object);

	archive_buy($session,$loc_object);
	archive_write($session,$loc_object,$loc_object);
	return;
	}

return 1;
