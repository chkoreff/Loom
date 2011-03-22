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

sub sha256_process_chunks
	{
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

# Return the SHA256 digest as a 32-byte BINARY string (i.e. 256 bits).  This
# allows you to feed the result into other hashes in a standard way.  To view
# the result as a human-readable hex string, just use:
#
#   my $hash = unpack("H*", sha256("my stuff"));
#   print "$hash\n";
#
# That will show you the hash value WITHOUT the spaces.

sub sha256
	{
	my $str = shift;

	return substr(sha256_process_chunks($str)->digest, 0, 32);
	}

# Return the SHA256 digest as a hexadecimal string, broken up with spaces in
# groups of 8 digits each (the same way GPG returns it).

sub sha256_hex
	{
	my $str = shift;

	return sha256_process_chunks($str)->hexdigest;
	}

return 1;
