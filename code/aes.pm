package aes;
use strict;
use Crypt::Rijndael;

=pod

=head1 NAME

Standard AES bit cipher in CBC (Chained Block Cipher) mode.

=head1 DESCRIPTION

The key size must be one of:
  128 bits     (16 bytes)
  192 bits     (24 bytes)
  256 bits     (32 bytes)

The initial value (iv) is optional, with a default value of 16 NUL bytes.
If specified, its length must be a multiple of 16 bytes.

Note that all text passed to the decrypt and encrypt routines must have the
same length as the cipher blocksize.

=cut

sub new
	{
	my $key = shift;
	my $iv = shift;  # optional

	my $cipher = {};
	$cipher->{ecb} = new Crypt::Rijndael $key, Crypt::Rijndael::MODE_ECB;
	clear($cipher,$iv);
	return $cipher;
	}

sub blocksize
	{
	my $cipher = shift;
	return $cipher->{ecb}->blocksize;
	}

# Reset the initial value (iv) used in chaining.
sub clear
	{
	my $cipher = shift;
	my $iv = shift;  # optional

	$iv = "\000" x blocksize($cipher) if !defined $iv;
	$cipher->{iv} = $iv;

	die if length($iv) != blocksize($cipher);

	return;
	}

# Decrypt a single block.
sub decrypt
	{
	my $cipher = shift;
	my $crypt = shift;

	die if !defined $crypt;
	die if length($crypt) != length($cipher->{iv});

	my $block = $cipher->{ecb}->decrypt($crypt);
	my $plain = $cipher->{iv} ^ $block;
	$cipher->{iv} = $crypt;

	return $plain;
	}

# Encrypt a single block.
sub encrypt
	{
	my $cipher = shift;
	my $plain = shift;

	die if !defined $plain;
	die if length($plain) != length($cipher->{iv});

	my $block = $cipher->{iv} ^ $plain;
	my $crypt = $cipher->{ecb}->encrypt($block);
	$cipher->{iv} = $crypt;

	return $crypt;
	}

return 1;
