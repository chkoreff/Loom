package Loom::Crypt::Blocks;
use strict;

=pod

=head1 NAME

Encrypt and decrypt strings of fixed-size blocks

=cut

sub new
	{
	my $class = shift;
	my $cipher = shift;  # any single-block cipher

	my $s = bless({},$class);
	$s->{cipher} = $cipher;
	return $s;
	}

sub encrypt
	{
	my $s = shift;
	my $in = shift;

	return $s->process(1,$in);
	}

sub decrypt
	{
	my $s = shift;
	my $in = shift;

	return $s->process(0,$in);
	}

sub blocksize
	{
	my $s = shift;
	return $s->{cipher}->blocksize;
	}

sub process
	{
	my $s = shift;
	my $encrypt = shift;  # true if encrypt; false if decrypt
	my $in = shift;

	my $cipher = $s->{cipher};

	my $len = length($in);
	my $blocksize = $cipher->blocksize;
	die if $len % $blocksize != 0;

	$cipher->reset;

	my $out = "";
	my $pos = 0;

	while ($pos + $blocksize <= $len)
		{
		my $block = substr($in,$pos,$blocksize);

		$out .= $encrypt
			? $cipher->encrypt($block)
			: $cipher->decrypt($block);

		$pos += $blocksize;
		}

	return $out;
	}

return 1;
