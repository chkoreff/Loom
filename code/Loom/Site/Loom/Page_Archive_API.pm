package Loom::Site::Loom::Page_Archive_API;
use strict;
use Loom::Context;

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

	my $api = Loom::Context->new;

	my $action = $op->get("action");

	$api->put(function => "archive");
	$api->put(action => $action);

	if ($action eq "look")
		{
		$api->put(hash => $op->get("hash"));
		}
	elsif ($action eq "touch")
		{
		$api->put(loc => $op->get("loc"));
		}
	elsif ($action eq "write")
		{
		$api->put(
			usage => $op->get("usage"),
			loc => $op->get("loc"),
			content => $op->get("content"),
			guard => $op->get("guard"),
			);
		}
	elsif ($action eq "buy")
		{
		$api->put(
			usage => $op->get("usage"),
			loc => $op->get("loc"),
			);
		}
	elsif ($action eq "sell")
		{
		$api->put(
			usage => $op->get("usage"),
			loc => $op->get("loc"),
			);
		}

	$site->{loom}->run_op($api);

	my $response_code = "200 OK";
	my $headers = "Content-type: text/plain\n";
	my $result = $api->write_kv;

	$site->format_HTTP_response($response_code,$headers,$result);
	return;
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
