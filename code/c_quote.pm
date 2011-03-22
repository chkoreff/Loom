use strict;

=pod

=head1 NAME

C quoting and unquoting

=cut

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

sub code_to_char
	{
	my $code = shift;

	return "\n" if $code eq "n";
	return $code if $code eq "\"";
	return "\t" if $code eq "t";
	return $code if $code eq "\\";
	return chr(oct($code));
	}

sub c_quote
	{
	my $str = shift;

	$str =~ s/(.)/char_to_code($1)/egs;
	return $str;
	}

sub c_unquote
	{
	my $str = shift;

	$str =~ s/\\(\d{3}|\\|n|t|\")/code_to_char($1)/egs;
	return $str;
	}

return 1;
