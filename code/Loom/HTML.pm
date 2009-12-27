package Loom::HTML;
use strict;
use URI::Escape;

=pod

=head1 NAME

HTML utilities including safe quoting

=cut

sub new
	{
	my $class = shift;
	my $s = bless({},$class);
	return $s;
	}

sub trimblanks
	{
	my $s = shift;
	my $str = shift;

	$str = '' unless defined $str;
	$str =~ s/\s+$//;
	$str =~ s/^\s+//;
	return $str;
	}

sub quote
	{
	my $s = shift;
	my $str = shift;

	$str = '' unless defined $str;
	$str =~ s/&/&amp;/g;
	$str =~ s/"/&quot;/g;
	$str =~ s/</&lt;/g;
	$str =~ s/>/&gt;/g;

	return $str;
	}

# Quoting for use in hidden form fields.
# LATER : the Test link with the Form post still doesn't quite work with
# newline embedded in hidden field.

sub quote_form
	{
	my $s = shift;
	my $str = shift;

	$str = '' unless defined $str;
	$str =~ s/&/&amp;/g;
	$str =~ s/"/&quot;/g;
	$str =~ s/</&lt;/g;
	$str =~ s/>/&gt;/g;

	# Map nonprintable characters to their HTML equivalents, e.g.
	#   "\007" => "&#07;"

	$str =~ s/([^ -~])/"&#".sprintf("%02d",ord($1)).";"/egs;

	return $str;
	}

# This quotes everything but & (ampersand).  That way we can include special
# HTML character entities, such as Russian &#1059;&#1089;&#1083;&#1086;

sub semiquote
	{
	my $s = shift;
	my $str = shift;

	$str = '' unless defined $str;
	$str =~ s/"/&quot;/g;
	$str =~ s/</&lt;/g;
	$str =~ s/>/&gt;/g;

	return $str;
	}

# Returns the effective display length of an HTML-quoted string.
# For example, $s->display_length("&amp;foo&lt;") == 3

sub display_length
	{
	my $s = shift;
	my $str = shift;

	$str =~ s/&\S+?;/X/g;  # convert quoted chars to 'X'
	return length($str);
	}

sub remove_nonprintable
	{
	my $s = shift;
	my $str = shift;

	$str =~ s/(.)/char_remove_nonprintable($1)/egs;

	return $str;
	}

sub char_remove_nonprintable
	{
	my $ch = shift;

	return "" if $ch lt ' ' || $ch gt '~';
	return $ch;
	}

sub make_link
	{
	my $s = shift;
	my $url = shift;

	my $params = "";

	while (@_)
		{
		my $key = shift @_;
		my $val = shift @_;

		if (defined $val && $val ne "")
			{
			$params .= "&amp;" if $params ne "";

			my $q_key = uri_escape($key);
			my $q_val = uri_escape($val);

			$params .= "$q_key=$q_val";
			}
		}

	$url .= "?$params" if $params ne "";
	return $url;
	}

sub hidden_fields
	{
	my $s = shift;
	my $str = "";

	while (@_)
		{
		my $key = shift @_;
		my $val = shift @_;

		next if $val eq "";

		my $q_key = $s->quote_form($key);
		my $q_val = $s->quote_form($val);

		$str .= qq{<input type=hidden name="$q_key" value="$q_val">\n};
		}

	$str = "<div>\n$str</div>\n";  # compliance with HTML 4.0 STRICT

	return $str;
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
