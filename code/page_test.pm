package page_test;
use strict;
use context;
use cstring;
use html;
use http;
use loom_config;
use page;

sub html_c_quote
	{
	my $string = shift;
	return html::quote(cstring::quote($string));
	}

sub respond
	{
	page::set_title("Test");

	if (http::get("help"))
		{
		# LATER there's no link to reach this help
		page::top_link(page::highlight_link(html::top_url("function","test"), "Test"));

		page::emit(<<EOM
<h1>Test</h1>

<p>
The Test function is just a collection of miscellaneous tests we may
accumulate over time.  Right now it includes a way to test very tricky
HTML urls and form posts.  It's probably not something you need to
concern yourself with.
EOM
);
		return;
		}

	page::emit(<<EOM
<h1>Test quoted values in HTML links and forms</h1>
<p>
This is a test of HTML quoting rules in urls and hidden form fields.
<p>
This is an extreme test which includes a \\015 (CR) character in a parameter
value.  It works fine with both the link and the multipart encoded form, but
it fails with the urlencoded form.
EOM
);

	my $context = context::new(http::slice(qw(function)));

	# LATER can we put \015 in the key?

	my $key_expect =
		##qq{color/"green&="\015 <test>\007</test> };
		qq{color/"green&=" <test>\007</test> };

	my $val_expect =
		qq{hello\nworld/!!!\015 <a> "backslash" \\ & oct8=\010+hello!\n};

	context::put($context,$key_expect,$val_expect);
	context::put($context,"go",1);

	my $url = html::top_url(context::pairs($context));

	page::emit(<<EOM
<p>
<a href="$url">Test using the link (this succeeds)</a>
EOM
);

	my $val_found = http::get($key_expect);

	my $q_key_expect = html_c_quote($key_expect);
	my $q_val_found = html_c_quote($val_found);
	my $q_val_expect = html_c_quote($val_expect);

	# LATER 20110311 the form tests FAIL now.  There's a problem with "/" in
	# the name.
	#if (http::get("go") ne "")
	#{
	## LATER we're seeing the key "color/" -- it's truncated
	#print "keys are: ".join(" ",http::names())."\n";
	#}

	# LATER At one point I noticed this:
	# "the multipart succeeds only after you've hit the link fails if you go
	# straight in with /test"
	# But now it never works.

	my $hidden = html::hidden_fields(context::pairs($context));

	page::emit(<<EOM
<p>
<form method=post action="" enctype="multipart/form-data">
$hidden
<p>
<input type=submit name=go value="Test with multipart/form-data (this USED TO succeed)">
</form>
EOM
);

	page::emit(<<EOM
<p>
<form method=post action="">
$hidden
<p>
<input type=submit name=go value="Test with urlencoded (this fails)">
</form>
EOM
);

	if (http::get("go") ne "")
	{
	my $status = $val_found eq $val_expect
		? "<span style='color:green'><b>Success</b></span>"
		: "<span class=alarm><b>ERROR</b></span>";

	page::emit(<<EOM
<h2>Result</h2>
<table border=1 style='border-collapse:collapse'>
<colgroup>
<col width=300>
<col width=450>
<col width=80>
</colgroup>
<tr>
<th align=left>Key</th>
<th align=left>Val</th>
<th align=left>Status</th>
</tr>

<tr>
<td>
"$q_key_expect"
</td>
<td>
"$q_val_found"
</td>
<td>
$status
</td>
</tr>
EOM
);

	if ($val_found ne $val_expect)
	{
	page::emit(<<EOM
<tr>
<td align=right>
<b>Expected:</b>
</td>
<td>
"$q_val_expect"
</td>
<td>
</td>
</tr>
EOM
);
	}

	page::emit(<<EOM

</table>
EOM
);
	}

	{
	my $prefix = sloop_config::get("path_prefix");
	my $url = $prefix . q{/test/path/a///%3Cbr%3E%3F%2F%22hi%22%25%2F..%2Fweird%20/two%0D%0Alines here/c/};

	page::emit(<<EOM
<h1>Test path interpretation</h1>
<a href="$url"> Example of a strange path </a>
EOM
);

	my $path = http::path();
	my @path = http::split_path($path);

	shift @path;   # drop "test"
	my $verb = shift @path;

	if (defined $verb && $verb eq "path")
		{
		my $result = "";
		$result .= "<ol class=mono>\n";
		for my $leg (@path)
			{
			my $q_leg = html_c_quote($leg);
			$result .= qq{<li>"$q_leg"</li>\n};
			}
		$result .= "</ol>\n";

		my $q_path = html_c_quote($path);

		page::emit(<<EOM
<p>
Path = <span class=mono>"$q_path"</span>
<p>
Interpreted as:
$result
EOM
);
		}
	}

	return;
	}

return 1;
