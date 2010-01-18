package Loom::DB::Object;
use strict;
use Loom::Crypt;
use Loom::Random;

=pod

=head1 NAME

Crypto layer on top of a transaction db (get/put/commit/cancel).

=head1 DESCRIPTION

The $db is normally of type Loom::DB::Trans_File.

=cut

sub new
	{
	my $class = shift;
	my $db = shift;
	my $salt = shift;

	die "The salt is not a valid hex id.\n" unless $class->valid_id($salt);

	my $s = bless({},$class);
	$s->{db} = $db;
	$s->{salt} = $salt;
	$s->{genrand} = Loom::Random->new;
	return $s;
	}

sub get
	{
	my $s = shift;
	my $hex_id = shift;

	return "" unless $s->valid_id($hex_id);

	my ($path,$cipher) = $s->map_object_id($hex_id);

	my $val = $s->{db}->get($path);
	return "" if $val eq "";

	return $cipher->decrypt($val);
	}

sub put
	{
	my $s = shift;
	my $hex_id = shift;
	my $val = shift;

	return unless $s->valid_id($hex_id);

	$val = "" if !defined $val;
	return if ref($val) ne "";

	my ($path,$cipher) = $s->map_object_id($hex_id);

	$val = $cipher->encrypt($val) if $val ne "";

	$s->{db}->put($path,$val);
	return;
	}

# Return a random object id.  The caller should check for collisions with
# existing objects, which should be exceedingly rare.  You can say something
# like:
#
#   my $count = 0;
#   while (1)
#     {
#     die if ++$count > 1000;  # something is wrong
#     my $session_id = $db->random;
#     next if $db->get($session_id) ne "";  # collision, try again
#     # Now we have a new session id which does not collide. ...
#     }
#
# We don't want to check for collisions in this routine because, in the rare
# case of collisions, we would buffer the non-null value(s) which we read, and
# that would affect the caller's commit.  So we leave it up to the caller,
# which handles the commit loop in its own way.

sub random
	{
	my $s = shift;

	return unpack("H*",$s->{genrand}->get);
	}

sub commit
	{
	my $s = shift;
	return $s->{db}->commit;
	}

sub cancel
	{
	my $s = shift;
	$s->{db}->cancel;
	}

# Here is the scheme for encrypted storage of objects, expressed in functional
# notation (Fexl).
#
# \salt     # 128-bit secret system "salt"
# \xor      # computes exclusive-OR of two 128-bit values
#
# \encrypt  # a function which encrypts a sequence of 128-bit blocks
# \decrypt  # a function which decrypts a sequence of 128-bit blocks
#
# \pad      # pad a byte string to a sequence of 128-bit blocks
#    This appends NUL bytes as necessary and prepends a single byte 0-15
#    telling how many NUL bytes were used.
#
# \unpad    # unpad a sequence of 128-bit blocks to a byte string
#    This strips off the leading count byte and the trailing NUL bytes.
#
# \id     # 128-bit object identifier
# \text   # object content, an arbitrary string of bytes
#
# \key   = (xor salt id)             # cipher key for this object
# \loc   = (encrypt key id)          # location on file system for this object
# \crypt = (encrypt key (pad text))  # value stored on file system
#
# When we look up the object we read loc and retrieve crypt, then recover the
# literal text with:
#
# \text  = (unpad (decrypt key crypt))

sub map_object_id
	{
	my $s = shift;
	my $hex_id = shift;

	die if !$s->valid_id($hex_id);
	die if !$s->valid_id($s->{salt});

	my $bin_id = pack("H*",$hex_id);
	my $bin_salt = pack("H*",$s->{salt});

	die if length($bin_id) != 16;
	die if length($bin_salt) != 16;

	my $bin_key = $bin_id ^ $bin_salt;
	my $cipher = Loom::Crypt->new($bin_key);

	my $bin_loc = $cipher->encrypt_blocks($bin_id);
	my $hex_loc = unpack("H*",$bin_loc);

	my $level1 = substr($hex_loc,0,2);
	my $level2 = substr($hex_loc,2,2);

	my $path = "$level1/$level2/$hex_loc";

	return ($path,$cipher);
	}

sub valid_id
	{
	my $s = shift;
	my $str = shift;

	return 0 if !defined $str || $str eq "";
	return 0 if length($str) != 32;
	return 1 if $str =~ /^[a-f0-9]{32}$/;
	return 0;
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
