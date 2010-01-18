package Loom::Load;
use strict;

=pod

=head1 NAME

Dynamic loading of modules

=cut

sub new
	{
	my $class = shift;
	my $s = bless({},$class);
	return $s;
	}

sub require
	{
	my $s = shift;
	my $type = shift;

	die if !defined $type || $type eq "";

	my $module = $type;
	$module =~ s/::/\//g;

	eval { require "$module.pm" };

	if ($@)
		{
		print STDERR "Could not get object of type '$type'\n";
		print STDERR "Error was:\n$@\n";
		die "\n";
		}

	return $type;
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
