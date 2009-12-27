package Loom::Test::DB;
use strict;

=pod

=head1 NAME

Test suite for db operations

=cut

use Getopt::Long;

sub new
	{
	my $class = shift;
	my $TOP = shift;

	my $s = bless({},$class);
	$s->{TOP} = $TOP;
	return $s;
	}

sub run
	{
	my $s = shift;

	Loom::Test::DB::Mem->new->run;
	Loom::Test::DB::Set->new->run;
	}

package Loom::Test::DB::Mem;
use strict;
use Loom::DB::Trans_Mem;

sub new
	{
	my $class = shift;

	my $s = bless({},$class);
	$s->{key_hash} = {};
	$s->{db} = Loom::DB::Trans_Mem->new;
	return $s;
	}

sub run
	{
	my $s = shift;

	print "Test in-memory DB with cancel/commit\n";

	$s->check(<<EOM);
EOM

	$s->put("A","1");

	$s->check(<<EOM);
A 1
EOM

	$s->put("B","2");
	$s->put("X","24");

	$s->check(<<EOM);
A 1
B 2
X 24
EOM

	$s->put("X","24x");
	$s->check(<<EOM);
A 1
B 2
X 24x
EOM

	$s->put("X","");
	$s->check(<<EOM);
A 1
B 2
EOM

	$s->commit;

	$s->put("A","1a");
	$s->put("B","");
	$s->put("C","3");
	$s->put("X","24");

	$s->check(<<EOM);
A 1a
C 3
X 24
EOM

	$s->cancel;

	$s->check(<<EOM);
A 1
B 2
EOM

	print "success\n\n";

	return;
	}

sub put
	{
	my $s = shift;
	my $key = shift;
	my $val = shift;

	$s->{key_hash}->{$key} = 1;

	#print "put $key $val\n";
	$s->{db}->put($key,$val);
	return;
	}

sub check
	{
	my $s = shift;
	my $expect = shift;

	my $result = $s->string;

	return if $result eq $expect;

	my @caller = caller(0);
	my $filename = $caller[1];
	my $lineno = $caller[2];

	print STDERR <<EOM;
Unexpected result at $filename line $lineno

result:
$result
expected:
$expect
EOM

	die "\n";
	}

sub commit
	{
	my $s = shift;

	my $ok = $s->{db}->commit;
	die if !$ok;
	#print "commit\n";
	return;
	}

sub cancel
	{
	my $s = shift;

	#print "cancel\n";
	$s->{db}->cancel;
	return;
	}

sub string
	{
	my $s = shift;

	my $key_hash = $s->{key_hash};

	my $str = "";

	for my $key (sort keys %$key_hash)
		{
		my $val = $s->{db}->get($key);
		next if $val eq "";
		$str .= "$key $val\n";
		}

	return $str;
	}

package Loom::Test::DB::Set;
use strict;
use Loom::DB::Trans_Mem;
use Loom::DB::Tree;

sub new
	{
	my $class = shift;

	my $s = bless({},$class);
	return $s;
	}

sub run
	{
	my $s = shift;

	print "Test indexed set operations\n";

	$s->run_test_1;
	$s->run_test_2;

	print "success\n\n";
	return;
	}

sub init
	{
	my $s = shift;
	$s->{db} = Loom::DB::Trans_Mem->new;
	$s->{set} = Loom::DB::Tree->new($s->{db},",set");
	return;
	}

sub run_test_1
	{
	my $s = shift;

	$s->init;

	print "Set test 1\n";

	$s->{set}->include("4/4/4/6/9");
	$s->{set}->include("3/1/8/9");
	$s->{set}->include("4/4/7/4/9");
	$s->{set}->include("3/8/2/6");
	$s->{set}->include("3/8/2/6");
	$s->{set}->include("3/8/2/4");
	$s->{set}->include("4/4/3/3/3");
	$s->{set}->include("2/3/8");
	$s->{set}->include("4/6/7/0/0");
	$s->{set}->include("1/9");
	$s->{set}->include("3/7/0/0");
	$s->{set}->include("3/7/0/1");
	$s->{set}->include("5/1");
	$s->{set}->include("5/2");
	$s->{set}->include("5/3");

	$s->{db}->put("4/6/7/0/0/val","v6700");
	$s->{db}->put("3/8/2/6/val","v826");

	$s->check_has("4/4/4/6/9", 1);
	$s->check_has("4/4/4/6/8", 0);
	$s->check_has("3/8/2/6", 1);
	$s->check_has("3/8/2/7", 0);
	$s->check_has("2/3/8", 1);
	$s->check_has("", 0);
	$s->check_has("3", 0);

	$s->check_follow("","1/9");
	$s->check_follow("1/9","2/3/8");
	$s->check_follow("2/3/8","3/1/8/9");
	$s->check_follow("3/1/8/9","3/7/0/0");
	$s->check_follow("3/7/0/0","3/7/0/1");
	$s->check_follow("3/7/0/1","3/8/2/4");
	$s->check_follow("3/8/2/4","3/8/2/6");
	$s->check_follow("3/8/2/6","4/4/3/3/3");
	$s->check_follow("4/4/3/3/3","4/4/4/6/9");
	$s->check_follow("4/4/4/6/9","4/4/7/4/9");
	$s->check_follow("4/4/7/4/9","4/6/7/0/0");
	$s->check_follow("4/6/7/0/0","5/1");
	$s->check_follow("5/1","5/2");
	$s->check_follow("5/2","5/3");
	$s->check_follow("5/3","");

	print "\n";

	return;
	}

sub run_test_2
	{
	my $s = shift;

	$s->init;

	print "Set test 2\n";

	$s->{set}->include("4/4/4/6/9");
	$s->{set}->include("3/1/8/9");
	$s->{set}->include("4/4/7/4/9");
	$s->{set}->include("3/8/2/6");
	$s->{set}->include("3/8/2/6");
	$s->{set}->include("3/8/2/4");
	$s->{set}->include("4/4/3/3/3");
	$s->{set}->include("2/3/8");
	$s->{set}->include("4/6/7/0/0");
	$s->{set}->include("1/9");
	$s->{set}->include("3/7/0/0");
	$s->{set}->include("3/7/0/1");
	$s->{set}->include("5/1");
	$s->{set}->include("5/2");
	$s->{set}->include("5/3");

	$s->{db}->put("4/6/7/0/0/val","v6700");
	$s->{db}->put("3/8/2/6/val","v826");

	$s->{set}->exclude("1/9");

	$s->{set}->exclude("3/8/2/4");
	$s->{set}->exclude("3/8/2/7");  # not in the set
	#$s->{set}->exclude("3/8/2/6");
	$s->{db}->put("3/8/2/6/val","");
	$s->{set}->exclude("4/4/7/4/9");
	$s->{set}->exclude("4/4/3/3/3");
	$s->{set}->exclude("3/7/0/1");
	$s->{set}->exclude("3/1/8/9");
	$s->{set}->exclude("4/6/7/0/0");
	$s->{db}->put("4/6/7/0/0/val","");

	$s->{set}->exclude("5/3");
	$s->{set}->exclude("2/3/8");
	$s->{set}->exclude("3");  # has no effect

	$s->check_has("4/4/4/6/9", 1);
	$s->check_has("4/4/4/6/8", 0);
	$s->check_has("3/8/2/6", 1);
	$s->check_has("3/8/2/7", 0);
	$s->check_has("2/3/8", 0);
	$s->check_has("", 0);
	$s->check_has("3", 0);

	$s->check_follow("","3/7/0/0");
	$s->check_follow("3/7/0/0","3/8/2/6");
	$s->check_follow("3/8/2/6","4/4/4/6/9");
	$s->check_follow("4/4/4/6/9","5/1");
	$s->check_follow("5/1","5/2");
	$s->check_follow("5/2","");

	print "\n";

	return;
	}

sub check_has
	{
	my $s = shift;
	my $key = shift;
	my $expect = shift;

	my $has = $s->{set}->has($key);
	print "has '$key' = $has\n";

	die "expected '$expect' but got '$has'"
		if defined $expect && $has ne $expect;

	return;
	}

sub check_follow
	{
	my $s = shift;
	my $key = shift;
	my $expect = shift;

	my $after = $s->{set}->follow($key);
	print "after '$key' = '$after'\n";

	die "after '$after' is not in set"
		if $after ne "" && !$s->{set}->has($after);

	die "after '$after' le '$key'"
		if $after ne "" && $after le $key;

	die "expected '$expect' but got '$after'"
		if defined $expect && $after ne $expect;

	return $after;
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
