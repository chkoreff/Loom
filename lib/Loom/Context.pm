package Loom::Context;
use strict;
use Loom::Format::Buffer;
use Loom::Format::KV;

sub new
	{
	my $class = shift;
	my $s = bless({},$class);

	$s->{list} = [];
	$s->{hash} = {};

	$s->put(@_);

	return $s;
	}

sub get
	{
	my $s = shift;
	my $key = shift;

	my $val = $s->{hash}->{$key};
	$val = "" if !defined $val;
	return $val;
	}

sub put
	{
	my $s = shift;

	while (@_)
		{
		my $key = shift;
		my $val = shift;

		if (!defined $val || $val eq "")
			{
			if (defined $s->{hash}->{$key})
				{
				delete $s->{hash}->{$key};
				my $pos = 0;
				for (@{$s->{list}})
					{
					if ($_ eq $key)
						{
						splice @{$s->{list}}, $pos, 1;
						last;
						}
					$pos++;
					}
				}
			}
		else
			{
			if (!defined $s->{hash}->{$key})
				{
				push @{$s->{list}}, $key;
				}

			$s->{hash}->{$key} = "".$val;
				# prepend null to force numbers to be stored as strings
			}
		}
	}

sub names
	{
	my $s = shift;

	return @{$s->{list}};
	}

sub pairs
	{
	my $s = shift;

	return $s->slice($s->names);
	}

sub slice
	{
	my $s = shift;

	my @pairs;

	for my $key (@_)
		{
		push @pairs, $key, $s->get($key);
		}

	return @pairs;
	}

# Read the KV text into the Context, or into a new Context if you pass in a
# class.

sub read_kv
	{
	my $s = shift;
	my $text = shift;

	$s = $s->new if ref($s) eq "";

	my $kv = Loom::Format::KV->new;
	$kv->put($text);

	while (1)
		{
		my @rsp = $kv->get;
		last if @rsp == 0;

		my $verb = shift @rsp;
		last if $verb eq "!" || $verb eq "E";
		next if $verb ne "P";

		my $key = shift @rsp;
		my $val = shift @rsp;
		$s->put($key,$val);
		}

	return $s;
	}

sub write_kv
	{
	my $s = shift;

	my $kv = Loom::Format::KV::Out->new;
	my $out = Loom::Format::Buffer->new;

	$out->put($kv->put("B"));
	for my $key ($s->names)
		{
		my $val = $s->get($key);
		$out->put($kv->put("P",$key,$val));
		}
	$out->put($kv->put("E"));

	return $out->get;
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
