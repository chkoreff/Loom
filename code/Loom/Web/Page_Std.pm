package Loom::Web::Page_Std;
use strict;

# Render a page out of the archive with standard styling.

sub new
	{
	my $class = shift;
	my $site = shift;
	my $loc = shift;
	my $title = shift;

	$title = "" if !defined $title;

	my $s = bless({},$class);
	$s->{site} = $site;
	$s->{loc} = $loc;
	$s->{title} = $title;
	return $s;
	}

sub respond
	{
	my $s = shift;

	my $site = $s->{site};

	$site->set_title($s->{title});

	my $text = $site->archive_get($s->{loc});

	if (!defined $text)
		{
		$site->page_not_found;
		return;
		}

	$site->{body} .= $text;

	push @{$site->{top_links}},
		$site->highlight_link(
			$site->url,
			"Home");

	push @{$site->{top_links}},
		$site->highlight_link(
			$site->url($site->{op}->slice("function")),
			$s->{title}, 1);

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
