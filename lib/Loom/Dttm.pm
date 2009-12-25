package Loom::Dttm;
use strict;

sub new
	{
	my $class = shift;
	my $time = shift;  # epoch seconds, defaults to current time

	$time = time() if !defined $time;

	my $s = bless(\$time,$class);
	return $s;
	}

# Return epoch seconds.
sub epoch
	{
	my $s = shift;
	return $$s;
	}

sub as_gmt
	{
	my $s = shift;

	return "" if !$s->valid;

	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
		gmtime($s->epoch);

	my $dttm = sprintf("%04d-%02d-%02d %02d:%02d:%02d",
		$year+1900, $mon+1, $mday, $hour, $min, $sec);

	return $dttm;
	}

sub as_local
	{
	my $s = shift;

	return "" if !$s->valid;

	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
		localtime($s->epoch);

	my $dttm = sprintf("%04d-%02d-%02d %02d:%02d:%02d",
		$year+1900, $mon+1, $mday, $hour, $min, $sec);

	return $dttm;
	}

# Format the epoch time according to the GMT (Greenwich Mean Time) standard
# in HTML, e.g. "Thu, 29-Nov-2007 16:18:42 GMT".  This format is typically
# used for cookie expiration times.

sub as_cookie
	{
	my $s = shift;

	return "" if !$s->valid;

	my @gm = gmtime($s->epoch);
	my $dow = (qw(Sun Mon Tue Wed Thu Fri Sat Sun))[$gm[6]];
	my $mday = $gm[3];
	my $mon = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)[$gm[4]];
	my $year = $gm[5] + 1900;

	my $str = sprintf("%s, %02d-%s-%04d %02d:%02d:%02d GMT",
		$dow, $mday, $mon, $year, $gm[2], $gm[1], $gm[0]);

	return $str;
	}

sub valid
	{
	my $s = shift;

	my $time = $s->epoch;

	return 0 if !defined $time;
	return 1 if $time =~ /^\d+$/;
	return 0;
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
