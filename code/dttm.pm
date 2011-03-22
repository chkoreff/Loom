use strict;

=pod

=head1 NAME

Date and time operations.

=cut

sub valid_dttm
	{
	my $time = shift;

	return 0 if !defined $time;
	return 1 if $time =~ /^\d+$/;
	return 0;
	}

sub dttm_as_gmt
	{
	my $time = shift;

	return "" if !valid_dttm($time);

	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)
		= gmtime($time);

	my $dttm = sprintf("%04d-%02d-%02d %02d:%02d:%02d",
		$year+1900, $mon+1, $mday, $hour, $min, $sec);

	return $dttm;
	}

sub dttm_as_local
	{
	my $time = shift;

	return "" if !valid_dttm($time);

	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)
		= localtime($time);

	my $dttm = sprintf("%04d-%02d-%02d %02d:%02d:%02d",
		$year+1900, $mon+1, $mday, $hour, $min, $sec);

	return $dttm;
	}

# Format the epoch time according to the GMT (Greenwich Mean Time) standard
# in HTML, e.g. "Thu, 29-Nov-2007 16:18:42 GMT".  This format is typically
# used for cookie expiration times.

sub dttm_as_cookie
	{
	my $time = shift;

	return "" if !valid_dttm($time);

	my @gm = gmtime($time);
	my $dow = (qw(Sun Mon Tue Wed Thu Fri Sat Sun))[$gm[6]];
	my $mday = $gm[3];
	my $mon = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)[$gm[4]];
	my $year = $gm[5] + 1900;

	my $str = sprintf("%s, %02d-%s-%04d %02d:%02d:%02d GMT",
		$dow, $mday, $mon, $year, $gm[2], $gm[1], $gm[0]);

	return $str;
	}

return 1;
