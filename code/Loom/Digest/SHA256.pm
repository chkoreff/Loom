package Loom::Digest::SHA256;
use strict;
use Digest::SHA256;

=pod

=head1 NAME

SHA-256 hash

=head1 DESCRIPTION

This module works around a bug in Digest::SHA256, which does not handle
chunk sizes greater than 255 bytes.  So this module chops the string into
smaller chunk sizes.  Just to be extra-safe we use chunk size 127.

=cut

sub new
	{
	my $class = shift;
	my $s = bless({},$class);
	return $s;
	}

# Return the SHA256 digest as a hexadecimal string, broken up with spaces in
# groups of 8 digits each (the same way GPG returns it).

sub sha256_hex
	{
	my $s = shift;
	my $str = shift;

	return $s->process_chunks($str)->hexdigest;
	}

# Return the SHA256 digest as a 32-byte BINARY string (i.e. 256 bits).  This
# allows you to feed the result into other hashes in a standard way.  To view
# the result as a human-readable hex string, just use:
#
#   my $hash = unpack("H*", $s->sha256("my stuff"));
#   print "$hash\n";
#
# That will show you the hash value WITHOUT the spaces.

sub sha256
	{
	my $s = shift;
	my $str = shift;

	return substr($s->process_chunks($str)->digest, 0, 32);
	}

sub process_chunks
	{
	my $s = shift;
	my $str = shift;

	my $chunk_size = 127;

	my $len = length($str);

	my $num_chunks = int($len / $chunk_size);
	my $remainder = $len - $num_chunks * $chunk_size;

	die if $num_chunks * $chunk_size + $remainder != $len;

	my $context = Digest::SHA256::new(256);

	my $pos = 0;

	for (1 .. $num_chunks)
		{
		$context->add(substr($str,$pos,$chunk_size));
		$pos += $chunk_size;
		}

	if ($remainder)
		{
		$context->add(substr($str,$pos,$remainder));
		}

	return $context;
	}

return 1;

__END__

# Copyright 2006 Patrick Chkoreff
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
