package Loom::DB::Tree;
use strict;

=pod

=head1 NAME

Tree-structured "set" layered on top of db (not currently used)

=head1 DESCRIPTION

This module is a layer over a put/get db which splits keys on "/" and creates
full indexing at each level.  The "follow" routine allows you to get the
previous or next key starting from any point, allowing you to iterate through
the tree structure starting anywhere without using recursion.

This may be a bit more general-purpose than you'll ever need, but it's
interesting to see that it can be done.  I don't use it anywhere yet.

=cut

sub new
	{
	my $class = shift;
	my $db = shift;
	my $index = shift;  # name of key which stores entries at each level

	die if !defined $index || $index eq "";

	my $s = bless({},$class);
	$s->{db} = $db;
	$s->{index} = $index;
	return $s;
	}

sub include
	{
	my $s = shift;
	my $key = shift;
	my $prefix = shift;

	return if !defined $key || $key eq "";
	$prefix = "" if !defined $prefix;

	my $db = $s->{db};
	my $index = $s->{index};

	my $top = $db->get("$prefix$index");
	my @list = split("/",$top);

	my %hash;
	@hash{@list} = ();

	my ($head,$tail) = split("/",$key,2);

	if (!exists $hash{$head})
		{
		$hash{$head} = undef;
		$top = join("/",sort keys %hash);
		$db->put("$prefix$index",$top);
		}

	$s->include($tail, "$prefix$head/");
	}

sub exclude
	{
	my $s = shift;
	my $key = shift;

	my $prefix = shift;

	return if !defined $key || $key eq "";
	$prefix = "" if !defined $prefix;

	my $db = $s->{db};
	my $index = $s->{index};

	my ($head,$tail) = split("/",$key,2);

	$s->exclude($tail,"$prefix$head/");

	my $top = $db->get("$prefix$head/$index");
	return if $top ne "";

	$top = $db->get("$prefix$index");
	my @list = split("/",$top);

	my %hash;
	@hash{@list} = ();

	return if !exists $hash{$head};

	delete $hash{$head};
	$top = join("/",sort keys %hash);
	$db->put("$prefix$index",$top);
	return;
	}

sub has
	{
	my $s = shift;
	my $key = shift;
	my $prefix = shift;

	return 0 if !defined $key || $key eq "";

	$prefix = "" if !defined $prefix;

	my $db = $s->{db};
	my $index = $s->{index};

	my $top = $db->get("$prefix$index");
	my @list = split("/",$top);

	my %hash;
	@hash{@list} = ();

	my ($head,$tail) = split("/",$key,2);
	return 0 if !exists $hash{$head};

	$top = $db->get("$prefix$head/$index");

	return 1 if $top eq "";
	return $s->has($tail,"$prefix$head/");
	}

sub follow
	{
	my $s = shift;
	my $key = shift;
	my $forward = shift;
	my $prefix = shift;

	$key = "" if !defined $key;
	$prefix = "" if !defined $prefix;
	$forward = 1 if !defined $forward;

	my $db = $s->{db};
	my $index = $s->{index};

	my $top = $db->get("$prefix$index");
	my @list = split("/",$top);
	@list = reverse @list if !$forward;

	my ($head,$tail) = split("/",$key,2);
	$head = "" if !defined $head;

	for my $item (@list)
		{
		my $cmp = ($item cmp $head);
		next if $forward ? ($cmp < 0) : ($head ne "" && $cmp > 0);

		$tail = "" if $cmp != 0;
		my $follow = $s->follow($tail,$forward,"$prefix$item/");

		return "$item/$follow" if $follow ne "";
		next if $cmp == 0;
		return $item;
		}

	return "";
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
