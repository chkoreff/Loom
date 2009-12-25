package Loom::Quote::C;
use strict;

=pod

=head1 NAME

C quoting and unquoting

=cut

sub new
	{
	my $class = shift;
	my $s = bless({},$class);
	return $s;
	}

sub quote
	{
	my $s = shift;
	my $str = shift;

	$str =~ s/(.)/char_to_code($1)/egs;

	return $str;
	}

sub unquote
	{
	my $s = shift;
	my $str = shift;

	$str =~ s/\\(\d{3}|\\|n|t|\")/code_to_char($1)/egs;

	return $str;
	}

sub code_to_char
	{
	my $code = shift;

	return "\n" if $code eq "n";
	return $code if $code eq "\"";
	return "\t" if $code eq "t";
	return $code if $code eq "\\";
	return chr(oct($code));
	}

sub char_to_code
	{
	my $ch = shift;

	return "\\n" if $ch eq "\n";
	return "\\\"" if $ch eq '"';
	return "\\t" if $ch eq "\t";
	return "\\\\" if $ch eq "\\";
	return "\\".sprintf("%03lo", ord($ch)) if $ch lt ' ' || $ch gt '~';
	return $ch;
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
