use strict;

sub page_grid_api_respond
	{
	my $api = op_new();

	my $action = http_get("action");

	op_put($api,"function","grid");
	op_put($api,"action",$action);

	if ($action eq "buy")
		{
		op_put($api,
			"type",http_get("type"),
			"loc",http_get("loc"),
			"usage",http_get("usage"),
			);
		}
	elsif ($action eq "sell")
		{
		op_put($api,
			"type",http_get("type"),
			"loc",http_get("loc"),
			"usage",http_get("usage"),
			);
		}
	elsif ($action eq "issuer")
		{
		op_put($api,
			"type",http_get("type"),
			"orig",http_get("orig"),
			"dest",http_get("dest"),
			);
		}
	elsif ($action eq "touch")
		{
		op_put($api,
			"type",http_get("type"),
			"loc",http_get("loc"),
			);
		}
	elsif ($action eq "look")
		{
		op_put($api,
			"type",http_get("type"),
			"hash",http_get("hash"),
			);
		}
	elsif ($action eq "move")
		{
		op_put($api,
			"type",http_get("type"),
			"qty",http_get("qty"),
			"orig",http_get("orig"),
			"dest",http_get("dest"),
			);
		}
	elsif ($action eq "scan")
		{
		op_put($api,
			"locs",http_get("locs"),
			"types",http_get("types"),
			"zeroes",http_get("zeroes"),
			);
		}

	api_respond($api);

	my $response_code = "200 OK";
	my $headers = "Content-Type: text/plain\n";
	my $result = op_write_kv($api);

	format_HTTP_response($response_code,$headers,$result);
	return;
	}

return 1;
