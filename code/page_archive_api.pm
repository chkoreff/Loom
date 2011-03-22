use strict;

sub page_archive_api_respond
	{
	my $api = op_new();

	my $action = http_get("action");

	op_put($api,"function","archive");
	op_put($api,"action",$action);

	if ($action eq "look")
		{
		op_put($api,"hash",http_get("hash"));
		}
	elsif ($action eq "touch")
		{
		op_put($api,"loc",http_get("loc"));
		}
	elsif ($action eq "write")
		{
		op_put($api,
			"usage",http_get("usage"),
			"loc",http_get("loc"),
			"content",http_get("content"),
			"guard",http_get("guard"),
			);
		}
	elsif ($action eq "buy")
		{
		op_put($api,
			"usage",http_get("usage"),
			"loc",http_get("loc"),
			);
		}
	elsif ($action eq "sell")
		{
		op_put($api,
			"usage",http_get("usage"),
			"loc",http_get("loc"),
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
