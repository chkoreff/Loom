use strict;
use URI::Escape;

=pod

=head1 NAME

HTML utilities including safe quoting

=cut

sub trimblanks
	{
	my $str = shift;

	$str = '' unless defined $str;
	$str =~ s/\s+$//;
	$str =~ s/^\s+//;
	return $str;
	}

sub char_remove_nonprintable
	{
	my $ch = shift;

	return "" if $ch lt ' ' || $ch gt '~';
	return $ch;
	}

sub remove_nonprintable
	{
	my $str = shift;

	$str =~ s/(.)/char_remove_nonprintable($1)/egs;
	return $str;
	}

sub html_quote
	{
	my $str = shift;

	$str = '' unless defined $str;
	$str =~ s/&/&amp;/g;
	$str =~ s/"/&quot;/g;
	$str =~ s/</&lt;/g;
	$str =~ s/>/&gt;/g;

	return $str;
	}

# This quotes everything but & (ampersand).  That way we can include special
# HTML character entities, such as Russian &#1059;&#1089;&#1083;&#1086;
# We use this in memo fields.

sub html_semiquote
	{
	my $str = shift;

	$str = '' unless defined $str;
	$str =~ s/"/&quot;/g;
	$str =~ s/</&lt;/g;
	$str =~ s/>/&gt;/g;

	return $str;
	}

# Quoting for use in hidden form fields.
# LATER : the Test link with the Form post still doesn't quite work with
# newline embedded in hidden field.

sub html_quote_form
	{
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

sub html_hidden_fields
	{
	my $str = "";

	while (@_)
		{
		my $key = shift @_;
		my $val = shift @_;

		next if $val eq "";

		my $q_key = html_quote_form($key);
		my $q_val = html_quote_form($val);

		$str .= qq{<input type=hidden name="$q_key" value="$q_val">\n};
		}

	$str = "<div>\n$str</div>\n";  # compliance with HTML 4.0 STRICT

	return $str;
	}

# Returns the effective display length of an HTML-quoted string.
# For example, html_display_length("&amp;foo&lt;") == 3

sub html_display_length
	{
	my $str = shift;

	$str =~ s/&\S+?;/X/g;  # convert quoted chars to 'X'
	return length($str);
	}

sub make_url
	{
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

sub top_url
	{
	return make_url("/", @_);
	}

return 1;
