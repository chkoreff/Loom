package help_archive;
use strict;
use loom_config;
use page_help;
use page;
use URI::Escape;

sub buy
	{
	page::emit(<<EOM
<div class=color_heading>
<h1>Buy</h1>
</div>

<p>
Buy a location in the archive.  This costs 1 usage token.  The location must
currently be vacant (not bought) in order to buy it.  The input is:
EOM
);
	page_help::context_table(
	["function","archive",""],
	["action","buy","Name of operation"],
	["loc","<b>id</b>","Location to buy"],
	["usage","<b>id</b>","Location of usage tokens"],
	);

	page::emit(<<EOM
<p>
If the Buy operation succeeds, you will see the following keys in the
result:
EOM
);

	page_help::context_table(
	["status","success","Everything went well."],
	["cost","<b>qty</b>","Cost of operation"],
	["usage_balance","<b>qty</b>","New usage balance"],
	["hash","<b>hash</b>","Hash of location"],
	);

	page::emit(<<EOM
<p>
If the operation fails, the status will be <em>fail</em>, and the
reason for the failure will be indicated with any keys below which
apply:
EOM
);

	page_help::context_table(
	["status","fail","Something went wrong."],
	["error_loc","not_valid_id", "loc is not a valid id"],
	["error_loc","occupied", "loc is already occupied (bought)"],
	["content","<b>string</b>", "existing content at loc if occupied"],
	["error_usage","not_valid_id", "usage is not a valid id"],
	["error_usage","insufficent",
		"usage location did not have at least one usage token"],
	);
	}

sub sell
	{
	page::emit(<<EOM
<div class=color_heading>
<h1>Sell</h1>
</div>

<p>
Sell a location in the archive.  This refunds 1 usage token.  The content
at the location must currently be empty (null) in order to sell the location.
The input is:
EOM
);
	page_help::context_table(
	["function","archive",""],
	["action","sell","Name of operation"],
	["loc","<b>id</b>","Location to sell"],
	["usage","<b>id</b>","Location of usage tokens"],
	);

	page::emit(<<EOM
<p>
If the Sell operation succeeds, you will see the following keys in the
result:
EOM
);

	page_help::context_table(
	["status","success","Everything went well."],
	["cost","<b>qty</b>","Cost of operation (-1 meaning refund)"],
	["usage_balance","<b>qty</b>","New usage balance"],
	["hash","<b>hash</b>","Hash of location"],
	);

	page::emit(<<EOM
<p>
If the operation fails, the status will be <em>fail</em>, and the
reason for the failure will be indicated with any keys below which
apply:
EOM
);

	page_help::context_table(
	["status","fail","Something went wrong."],
	["error_loc","not_valid_id", "loc is not a valid id"],
	["error_loc","vacant", "loc is already vacant (sold)"],
	["error_loc","not_empty", "loc has non-empty content"],
	["content","<b>string</b>", "existing content at loc (if non-empty)"],
	["error_usage","not_valid_id", "usage is not a valid id"],
	);
	}

sub touch
	{
	page::emit(<<EOM
<div class=color_heading>
<h1>Touch</h1>
</div>

<p>
Touch a location in the archive.  The input is:
EOM
);
	page_help::context_table(
	["function","archive",""],
	["action","touch","Name of operation"],
	["loc","<b>id</b>","Location to touch"],
	);

	page::emit(<<EOM
<p>
If the Touch operation succeeds, you will see the following keys in the
result:
EOM
);

	page_help::context_table(
	["status","success","Everything went well."],
	["content","<b>string</b>","Content at archive location"],
	["hash","<b>hash</b>","Hash of location"],
	["content_hash","<b>hash</b>","Hash of content"],
	);

	page::emit(<<EOM
<p>
If the operation fails, the status will be <em>fail</em>, and the
reason for the failure will be indicated with any keys below which
apply:
EOM
);

	page_help::context_table(
	["status","fail","Something went wrong."],
	["error_loc","not_valid_id", "loc is not a valid id"],
	["error_loc","vacant", "loc is vacant (sold)"],
	);
	}

sub look
	{
	page::emit(<<EOM
<div class=color_heading>
<h1>Look</h1>
</div>

<p>
Look at a location in the archive by its hash.  The input is:
EOM
);
	page_help::context_table(
	["function","archive",""],
	["action","look","Name of operation"],
	["hash","<b>hash</b>","Hash of location to examine"],
	);

	page::emit(<<EOM
<p>
If the Look operation succeeds, you will see the following keys in the
result:
EOM
);

	page_help::context_table(
	["status","success","Everything went well."],
	["content","<b>string</b>","Content at hash of location"],
	["content_hash","<b>hash</b>","Hash of content"],
	);

	page::emit(<<EOM
<p>
If the operation fails, the status will be <em>fail</em>, and the
reason for the failure will be indicated with any keys below which
apply:
EOM
);

	page_help::context_table(
	["status","fail","Something went wrong."],
	["error_hash","not_valid_id", "hash is not a valid hash"],
	["error_loc","vacant", "loc is vacant (sold)"],
	);
	}

sub do_write
	{
	page::emit(<<EOM
<div class=color_heading>
<h1>Write</h1>
</div>

<p>
Write content into the archive.  The system first encrypts the content using
a key derived from the location.  This may impose an overhead of a few bytes.
It then compares the new encrypted length with the length of any existing
content at this location, and determines how many bytes would be added or
subtracted <em>on net</em> if it were to write out the new content.  It then
charges 1 usage token per 16 bytes added, or refunds 1 usage token per 16 bytes
subtracted.
<p>
The input is:
EOM
);
	page_help::context_table(
	["function","archive",""],
	["action","write","Name of operation"],
	["loc","<b>id</b>","Location to write"],
	["content","<b>id</b>","Content to write into that location"],
	["usage","<b>id</b>","Location of usage tokens"],
	["guard","<b>hash</b>",
		"Optional SHA256 hash of previous content to guard against "
		."overlapping writes"
		],
	);

	page::emit(<<EOM
<p>
If the Write operation succeeds, you will see the following keys in the
result:
EOM
);

	page_help::context_table(
	["status","success","Everything went well."],
	["cost","<b>qty</b>","Cost of operation"],
	["usage_balance","<b>qty</b>","New usage balance"],
	["hash","<b>hash</b>","Hash of location"],
	["content_hash","<b>hash</b>","Hash of content"],
	);

	page::emit(<<EOM

<p>
<b>NOTE:</b> the "content" key supplied in the input is <em>not</em> echoed
back in the result, because that would just be a waste of time and bandwidth.
EOM
);

	page::emit(<<EOM
<p>
If the operation fails, the status will be <em>fail</em>, and the
reason for the failure will be indicated with any keys below which
apply:
EOM
);

	page_help::context_table(
	["status","fail","Something went wrong."],
	["error_loc","not_valid_id", "loc is not a valid id"],
	["error_loc","vacant", "loc is vacant (sold)"],
	["error_usage","not_valid_id", "usage is not a valid id"],
	["error_usage","insufficent",
		"usage location is vacant or did not have enough usage tokens "
		."to cover the cost"
		],
	["error_guard","not_valid_hash",
		"guard was specified and is not a valid hash"],
	["error_guard","changed",
		"The hash of the previous content did not match the specified"
		." guard, so the new content was not written.  Essentially this "
		."means that the content changed \"under our feet\" since the "
		."last time we looked at it, so we don't clobber those changes."
		],
	);
	}

sub respond
	{
	page::emit(<<EOM
<h1>Archive</h1>

<p>
The Archive function provides a general purpose data storage facility paid
with usage tokens.  You can Look at an archive entry by its hash, which lets
you read the content but not change it.  You can also Touch an entry directly
by its location, which lets you change the content with the Write operation.
Writing new content costs 1 usage token per 16 bytes of <em>encrypted</em>
data added to the database, or yields a 1 token refund per 16 bytes reduced.
(There can be a few bytes of overhead added in the encryption process.)

<p>
Before you can write an entry, you must first Buy its location for 1 usage
token.  This helps prevent accidentally writing to an incorrect location.
You may then write arbitrary content into the purchased location.  Later, if
you want to Sell the location back to receive a 1 token refund, you must first
clear it out by writing null content into it.

<p>
All content is encrypted in the database using a key derived from the archive
location.

EOM
);

	{
	my $loc = "c80481226973dfec6dc06c8dfe8a5b1c";
	my $usage = "29013fc66a653f6765151dd352675d0f";

	my $test_str = "first/line\nsecond/line\n";
	my $q_test_str = uri_escape($test_str);

	my $this_url = loom_config::get("this_url");

	page::emit(<<EOM
<h1>Example API Call</h1>
<p>
Here is a url which writes the string "abc" into archive location $loc,
paying for the storage from usage location $usage.  Note that in order
for this to work, you must have already bought the archive location.

<pre class=mono style='margin-left:20px'>
$this_url?function=archive&action=write
	&usage=$usage
	&loc=$loc
	&content=abc
</pre>

<p>
(The url is broken up across lines for clarity.  In practice you would keep
the entire url on a single line.)

<p>
You may use content with multiple lines or arbitrary binary characters.  All
you have to do is "uri_escape" the content to convert it into a form suitable
for use in a url.  (For you perl programmers, see the URI::Escape module.)
For example, this multi-line string:

<pre style='margin-left:20px'>
$test_str
</pre>

<p>
would be encoded by uri_escape as:

<pre style='margin-left:20px'>
$q_test_str
</pre>

<p>
For better support of very large content, there will soon be an API call which
is compatible with the HTTP "file upload" protocol.  But for now, the simple
"write" operation should suffice just fine for most purposes (even with large
content).
EOM
);
	}

	page::emit(<<EOM
<h1>Archive Operations</h1>
<p>
Here we describe the API (application programming interface) for the Archive.
The operations are Buy, Sell, Touch, Look, and Write.

EOM
);

	buy();
	sell();
	touch();
	look();
	do_write();
	}

return 1;
