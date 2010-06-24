package Loom::Test::Loom;
use strict;
use Loom::Test::Crypt;
use Loom::Test::File;
use Loom::Test::Grid;
use Loom::Test::Random;
use Loom::Test::SHA256;

# Test the overall Loom system.

sub new
	{
	my $class = shift;
	my $arena = shift;

	my $s = bless({},$class);
	$s->{arena} = $arena;
	return $s;
	}

# LATER: a verbose option

sub run
	{
	my $s = shift;

	print "Testing the Loom system.\n";

	# We call umask here so that when the server creates a new file the
	# permissions are restricted to read and write by the owner only.
	# The octal 077 value disables the "group" and "other" permission bits.

	umask(077);

	$s->check_dependencies;

	Loom::Test::Format->new->run;
	Loom::Test::Crypt->new->run;
	Loom::Test::Random->new->run;
	Loom::Test::SHA256->new->run;
	Loom::Test::Grid->new({embedded => 1})->run;

	# Test concurrent file operations with many processes.

	# LATER 0318 After we actually port the current GNU DB over to individual
	# files, I'll write a massively parallel test suite for API operations
	# themselves, in addition to this raw file test.

	{
	my $arena =
		{
		embedded => 1,
		count => 128,
		verbose => 0,
		TOP => $s->{arena}->{TOP},
		};

	Loom::Test::File->new($arena)->run;
	}

	print "The Loom system test succeeded.\n";

	return;
	}

sub check_dependencies
	{
	my $s = shift;

	# Flat prerequisites

	my @modules =
		qw(
		Bit::Vector
		Crypt::Rijndael
		Digest::SHA256
		Fcntl
		GDBM_File
		Getopt::Long
		Socket
		URI::Escape
		);

	my @missing = ();

	for my $module (@modules)
		{
		eval "require $module";
		push @missing, $module if $@ ne "";
		}

	if (@missing != 0)
		{
		print STDERR "These Perl modules need to be installed before you "
			."can run the server:\n";

		for my $module (@missing)
			{
			print STDERR "  $module\n";
			}

		exit(1);
		}

	return;
	}

package Loom::Test::Format;
use strict;
use Loom::KV;
use Loom::Quote::C;

sub new
	{
	my $class = shift;

	my $s = bless({},$class);
	$s->{C} = Loom::Quote::C->new;
	$s->{ok} = 1;
	return $s;
	}

sub run
	{
	my $s = shift;

	$s->test_parse_lines;
	$s->test_parse_kv;

	#$s->test_quote("  abc def - \n\n \003\007\nfoobar \"hi\"  ");
	#$s->test_quote("\000\000 hi \t\t \015\n\n  ");

	if (!$s->{ok})
		{
		print STDERR "ERROR: Some tests failed.\n";
		exit(1);
		}

	return;
	}

sub test_parse_lines
	{
	my $s = shift;

	my $input =
		qq{abc\n}.
		qq{defg\015\nhij\nkl\011m"n"o\015\n}.
		qq{\015\n}.
		qq{pqrstuvwxyz};

	my $expect = <<'EOM';
line "abc"
line "defg"
line "hij"
line "kl\tm\"n\"o"
line ""
line "pqrstuvwxyz"
EOM

	my $result = "";

	for my $line (split(/\r?\n/,$input))
		{
		my $q_line = $s->{C}->quote($line);
		$result .= qq{line "$q_line"\n};
		}

	if ($result ne $expect)
		{
		$s->{ok} = 0;
		print <<EOM;
test_parse_lines : fail
== result
$result
== expect
$expect
EOM
		}

	return;
	}

sub test_parse_kv
	{
	my $s = shift;

	my $input = <<EOM;
Stuff up here to skip.
(
:x123
=123

# embedded comment
:x24
=24
:x25
strange line here instead of value
=25
# another comment here


strange line here instead of key
:x26
=26
)
extra stuff on the end.
(
:x99
=99
)
EOM

	my $expect = <<EOM;
:x123
=123
:x24
=24
:x25
=25
:x26
=26
:x99
=99
EOM

	my $kv = Loom::KV->new;
	my $hash = $kv->hash($input);
	my $result = $kv->text($hash);

	if ($result ne $expect)
		{
		$s->{ok} = 0;
		print <<EOM;
test_parse_kv : fail
== result
$result
== expect
$expect
EOM
		}

	return;
	}

# LATER integrate some tests here

# For example:
#  test_quote("  abc def - \n\n \003\007\nfoobar \"hi\"  ");
#  test_quote("\000\000 hi \t\t \015\n\n  ");

sub test_quote
	{
	my $s = shift;
	my $str = shift;

	my $quote_str = $s->{C}->quote($str);
	my $test_str = $s->{C}->unquote($quote_str);

	print "quote str ='$quote_str'\n";
	print "test str  : ".($test_str eq $str)."\n";
	}

return 1;

__END__

# Copyright 2007 Patrick Chkoreff
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
