package Loom::Site::Loom::API_Vend;
use strict;
use Loom::Context;

sub new
	{
	my $class = shift;
	my $db = shift;
	my $grid = shift;

	my $s = bless({},$class);
	$s->{db} = $db;
	$s->{grid} = $grid;
	return $s;
	}

# API entry point
sub respond
	{
	my $s = shift;
	my $op = shift;

	my $action = $op->get("action");

	# LATER buy, sell vending location?  or is "define" enough in itself?
	# How about create and destroy?

	if ($action eq "define")
		{
		$op->put("status","fail");
		$op->put("error_action","not_implemented");
		}
	elsif ($action eq "query")
		{
		$op->put("status","fail");
		$op->put("error_action","not_implemented");
		}
	elsif ($action eq "trade")
		{
		# LATER is this the right word?
		$op->put("status","fail");
		$op->put("error_action","not_implemented");
		}
	else
		{
		$op->put("status","fail");
		$op->put("error_action","unknown");
		}

	return;
	}

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
