package Loom::Digest::File;
use strict;
use Loom::File;
use Loom::Digest::SHA256;

=pod

=head1 NAME

Compute recursive SHA256 hash of directory or file.

=cut

sub new
	{
	my $class = shift;

	my $s = bless({},$class);
	$s->{hasher} = Loom::Digest::SHA256->new;
	return $s;
	}

sub hash
	{
	my $s = shift;
	my $dir = shift;
	my $long = shift;

	my $result = "";
	my $listing = "";

	my $type = $dir->type;

	if ($type eq "")
		{
		# It does not exist.
		}
	elsif ($type eq "f")
		{
		# It's a file.
		my $name = $dir->name;
		my $sum = $s->file_hash($dir);

		$listing .= "$sum $name\n";

		$result .= $listing if $long;
		$result .= "$sum\n";
		}
	elsif ($type eq "d")
		{
		# It's a directory.
		for my $name ($dir->deep_names)
			{
			my $sum = $s->file_hash($dir->child($name));
			$listing .= "$sum $name\n";
			}

		if ($listing ne "")
			{
			my $sum = unpack("H*",$s->{hasher}->sha256($listing));
			$result .= $listing if $long;
			$result .= "$sum\n";
			}
		}

	return $result;
	}

sub file_hash
	{
	my $s = shift;
	my $file = shift;

	$file->read;
	my $text = $file->get;
	$text = "" if !defined $text;

	return unpack("H*",$s->{hasher}->sha256($text));
	}

return 1;

__END__

# Copyright 2009 Patrick Chkoreff
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
