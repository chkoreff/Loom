package page_grid_api;
use strict;
use api;
use context;
use http;
use page;

sub respond
	{
	my $api = context::new();

	my $action = http::get("action");

	context::put($api,"function","grid");
	context::put($api,"action",$action);

	if ($action eq "buy")
		{
		context::put($api,
			"type",http::get("type"),
			"loc",http::get("loc"),
			"usage",http::get("usage"),
			);
		}
	elsif ($action eq "sell")
		{
		context::put($api,
			"type",http::get("type"),
			"loc",http::get("loc"),
			"usage",http::get("usage"),
			);
		}
	elsif ($action eq "issuer")
		{
		context::put($api,
			"type",http::get("type"),
			"orig",http::get("orig"),
			"dest",http::get("dest"),
			);
		}
	elsif ($action eq "touch")
		{
		context::put($api,
			"type",http::get("type"),
			"loc",http::get("loc"),
			);
		}
	elsif ($action eq "look")
		{
		context::put($api,
			"type",http::get("type"),
			"hash",http::get("hash"),
			);
		}
	elsif ($action eq "move")
		{
		context::put($api,
			"type",http::get("type"),
			"qty",http::get("qty"),
			"orig",http::get("orig"),
			"dest",http::get("dest"),
			);
		}
	elsif ($action eq "scan")
		{
		context::put($api,
			"locs",http::get("locs"),
			"types",http::get("types"),
			"zeroes",http::get("zeroes"),
			);
		}

	api::respond($api);

	my $response_code = "200 OK";
	my $headers = "Content-Type: text/plain\n";
	my $result = context::write_kv($api);

	page::format_HTTP_response($response_code,$headers,$result);
	return;
	}

return 1;
