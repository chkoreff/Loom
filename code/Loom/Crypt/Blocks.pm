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
