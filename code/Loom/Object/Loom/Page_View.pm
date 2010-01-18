package Loom::Object::Loom::Page_View;
use strict;

sub new
	{
	my $class = shift;
	my $site = shift;

	my $s = bless({},$class);
	$s->{site} = $site;
	return $s;
	}

sub respond
	{
	my $s = shift;

	my $site = $s->{site};

	my $op = $site->{op};
	my $loc = $op->get("hash");

	my $text = $site->archive_get($loc);

	if (!defined $text)
		{
		$site->page_not_found;
		return;
		}

	$site->page_ok($text);

	return;
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
