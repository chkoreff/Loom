package page_archive_api;
use strict;
use api;
use context;
use http;
use page;

sub respond
	{
	my $api = context::new();

	my $action = http::get("action");

	context::put($api,"function","archive");
	context::put($api,"action",$action);

	if ($action eq "look")
		{
		context::put($api,"hash",http::get("hash"));
		}
	elsif ($action eq "touch")
		{
		context::put($api,"loc",http::get("loc"));
		}
	elsif ($action eq "write")
		{
		context::put($api,
			"usage",http::get("usage"),
			"loc",http::get("loc"),
			"content",http::get("content"),
			"guard",http::get("guard"),
			);
		}
	elsif ($action eq "buy")
		{
		context::put($api,
			"usage",http::get("usage"),
			"loc",http::get("loc"),
			);
		}
	elsif ($action eq "sell")
		{
		context::put($api,
			"usage",http::get("usage"),
			"loc",http::get("loc"),
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
