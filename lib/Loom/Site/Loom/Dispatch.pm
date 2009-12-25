package Loom::Site::Loom::Dispatch;
use strict;

sub new
	{
	my $class = shift;

	my $s = bless({},$class);
	$s->{name_object} = {};    # map object name to constructor list
	$s->{module_status} = {};  # flag when we've already loaded a module
	return $s;
	}

sub map_named_object
	{
	my $s = shift;
	my $name = shift;    # logical name of object
	# ... remaining args specify the object: (module,...)

	return if defined $s->{name_object}->{$name};

	$s->{name_object}->{$name} = [@_];
	return;
	}

# Get the named live object in the context of the given environment.

sub get_named_object
	{
	my $s = shift;
	my $name = shift;
	my $env = shift;

	my $spec = $s->{name_object}->{$name};
	return if !defined $spec;

	my @args = @$spec;

	my $module = shift @args;
	return if !defined $module;

	return $s->get_object($module,$env,@args);
	}

sub get_object
	{
	my $s = shift;
	my $module = shift;
	my $env = shift;
	# ... any additional args are passed into object constructor

	# Load (require) the module dynamically.  We could just drop into the
	# require every time, since Perl only loads modules once, but we keep our
	# own flag to detect when we've already tried to load the module.  This
	# also gives us the ability to flag erroneous modules so we don't keep
	# trying to create objects with them and get repeated error messages.

	{
	my $status = $s->{module_status}->{$module};

	if (!defined $status)
		{
		my $filename = $module;
		$filename =~ s/::/\//g;
		$filename .= ".pm";

		eval { require $filename };

		if ($@ ne "")
			{
			$s->log_error($@);
			$s->{module_status}->{$module} = "B";  # bad
			return;
			}

		$s->{module_status}->{$module} = "G";  # good
		}
	elsif ($status eq "B")
		{
		return;
		}
	}

	# Create the object.

	my $object;
	eval { $object = $module->new($env,@_) };

	$s->log_error($@) if $@ ne "";

	if ($@ ne "")
		{
		$s->log_error($@);
		return;
		}

	return $object;
	}

sub log_error
	{
	my $s = shift;
	my $msg = shift;

	$msg .= "\n" if $msg !~ /\n$/;
	print STDERR time." $$ $msg";
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
