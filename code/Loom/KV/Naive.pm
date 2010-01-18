package Loom::KV::Naive;
use strict;

=pod

=head1 NAME

Naive key-value (KV) text format on single lines

=head1 DESCRIPTION

Synopsis:

   my $KV = "Loom::KV::Naive";

   my $hash = $KV->hash($text);
   my $text = $KV->text($hash);

Sample text:

   my $text = <<EOM;
   color red
   count 42
   val/a 1
   val/b 2
   val/c/x X
   val/c/y Y
   val/c/z Z
   value_with_3_leading_spaces    xyz
   EOM

Note that the slashes in those keys are not significant.  Keys and values
are just plain strings that are not interpreted in any way.

So what do we do about binary keys or values?  NOTHING.  There are no binary
keys or values.  If you want to use "binary" data you'll just have to encode
it in a non-binary form.  For example if you wanted to store image data you
might encode it in hexadecimal format like this:

   type png
   data e4991ceb60ee089d15fe990e037dc802...

Or use uuencode or whatever.  You could even use a key to describe what
encoding is being used, if you want to support different options.

All of this is up to the application.  That keeps the format specification
as simple as possible, and implementable using Perl one-liners.  Besides,
99.99% of the time you'll be using simple readable keys and values anyway.

Any blank lines in the $text are ignored naturally with no special handling.
If you want "comments" you can include a line such as "# a comment" but be
aware that this will map the key "#" to the value "a comment".

When we split the text on newlines, we use the regex /\r?\n/ which allows the
lines to be terminated with either CR-LF or just LF.

=cut


# Convert the text to a hash reference.

sub hash
	{
	my $class = shift;
	my $text = shift;

	return { map { split(/ /,$_,2) } split(/\r?\n/,$text) };
	}

# Convert the hash reference to text.

sub text
	{
	my $class = shift;
	my $hash = shift;

	return join("\n", map { "$_ $hash->{$_}" } sort keys %$hash);
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
