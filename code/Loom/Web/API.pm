package Loom::Web::API;
use strict;
use Loom::Context;
use Loom::DB::Prefix;
use Loom::Web::API_Archive;
use Loom::Web::API_Grid;

sub new
	{
	my $class = shift;
	my $db = shift;

	my $s = bless({},$class);
	$s->{db} = $db;

	my $grid_space = Loom::DB::Prefix->new($s->{db},"grid_");
	my $grid = Loom::Web::API_Grid->new($grid_space);

	my $archive_space = Loom::DB::Prefix->new($s->{db},"ar_");
	my $archive = Loom::Web::API_Archive->new($archive_space,$grid);

	$s->{grid} = $grid;
	$s->{archive} = $archive;

	$s->{rsp} = Loom::Context->new;  # response from last API operation
	return $s;
	}

# This routine takes a list of name => value pairs as arguments.  It bundles
# those into a context object for you and calls run_op.

sub run
	{
	my $s = shift;

	return $s->run_op(Loom::Context->new(@_));
	}

# This routine takes a context argument and runs the API function from that.

sub run_op
	{
	my $s = shift;
	my $op = shift;

	my $function = $op->get("function");

	if ($function eq "grid")
		{
		$s->{grid}->respond($op);
		}
	elsif ($function eq "archive")
		{
		$s->{archive}->respond($op);
		}
	else
		{
		$op->put("error_function","unknown");
		}

	$s->{rsp} = $op;
	return $op;
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
