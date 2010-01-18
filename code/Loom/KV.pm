package Loom::KV;
use strict;
use Loom::Quote::C;

=pod

=head1 NAME

KV format, flat on separate lines with C-quoting

=head1 SYNOPSIS

=over 1

=item my $KV = Loom::KV->new;

=item my $hash = $KV->hash($text);

=item my $text = $KV->text($hash);

=back

=cut

sub new
	{
	my $class = shift;

	my $s = bless({},$class);
	$s->{C} = Loom::Quote::C->new;
	return $s;
	}

# Convert the text to a hash reference.
#
# The text is split into lines using either CR-LF or LF as line boundaries.
# Any leading white space on each line is discarded.  Any line that starts
# with ':' is a key line.  Any line that starts with '=' is a value line.
# Any other line is silently ignored.  This allows arbitrary boilerplate to
# be skipped easily, e.g. if you get KV data back from a web query.

sub hash
	{
	my $s = shift;
	my $text = shift;

	$text = "" if !defined $text;

	my $hash = {};
	my $key = "";

	for my $line (split(/\r?\n/,$text))
		{
		$line =~ s/^\s+//;   # chop any leading white space
		next if $line eq ""; # skip blank lines

		my $type = substr($line,0,1);
		next if $type ne ":" && $type ne "=";

		my $data = $s->{C}->unquote(substr($line,1));

		if ($type eq ":")
			{
			$key = $data;
			}
		else
			{
			$hash->{$key} = $data;
			}
		}

	return $hash;
	}

# Convert the hash reference to text.

sub text
	{
	my $s = shift;
	my $hash = shift;

	my $text = "";

	for my $key (sort keys %$hash)
		{
		my $val = $hash->{$key};
		next if !defined $val || ref($val) ne "";

		$text .= ":".$s->{C}->quote($key)."\n";
		$text .= "=".$s->{C}->quote($val)."\n";
		}

	return $text;
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
