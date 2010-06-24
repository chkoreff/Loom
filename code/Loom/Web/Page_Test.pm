package Loom::Web::Page_Test;
use strict;
use Loom::Context;
use Loom::Quote::C;
use URI::Escape;

sub new
	{
	my $class = shift;
	my $site = shift;

	my $s = bless({},$class);
	$s->{site} = $site;
	$s->{html} = $site->{html};
	$s->{C} = Loom::Quote::C->new;
	return $s;
	}

sub respond
	{
	my $s = shift;

	my $site = $s->{site};

	$site->set_title("Test");
	my $op = $site->{op};

	if ($op->get("help"))
		{
		$site->{top_links} =
			[
			$site->highlight_link($site->url(function => "test"), "Test"),
			];

		$site->{body} .= <<EOM;
<h1>Test</h1>

<p>
The Test function is just a collection of miscellaneous tests we may
accumulate over time.  Right now it includes a way to test very tricky
HTML urls and form posts.  It's probably not something you need to
concern yourself with.
EOM
		return;
		}

	$site->{body} .= <<EOM;
<h1>Test quoted values in HTML links and forms</h1>
<p>
This is a test of HTML quoting rules in urls and hidden form fields.
<p>
This is an extreme test which includes a \\015 (CR) character in a parameter
value.  It works fine with both the link and the multipart encoded form, but
it fails with the urlencoded form.
EOM

	my $context = Loom::Context->new($op->slice(qw(function)));

	# LATER can we put \015 in the key?

	my $key_expect =
		##qq{color/"green&="\015 <test>\007</test> };
		qq{color/"green&=" <test>\007</test> };

	my $val_expect =
		qq{hello\nworld/!!!\015 <a> "backslash" \\ & oct8=\010+hello!\n};

	$context->put($key_expect,$val_expect);

	$context->put(go => 1);

	my $url = $site->url($context->pairs);

	$site->{body} .= <<EOM;
<p>
<a href="$url">Test using the link (this succeeds)</a>
EOM

	my $val_found = $op->get($key_expect);

	my $q_key_expect = $s->quote($key_expect);
	my $q_val_found = $s->quote($val_found);
	my $q_val_expect = $s->quote($val_expect);

	my $hidden = $s->{html}->hidden_fields($context->pairs);

	$site->{body} .= <<EOM;
<p>
<form method=post action="" enctype="multipart/form-data">
$hidden
<p>
<input type=submit name=go value="Test with multipart/form-data (this succeeds)">
</form>
EOM

	$site->{body} .= <<EOM;
<p>
<form method=post action="">
$hidden
<p>
<input type=submit name=go value="Test with urlencoded (this fails)">
</form>
EOM

	if ($op->get("go") ne "")
	{
	my $status = $val_found eq $val_expect
		? "<span style='color:green'><b>Success</b></span>"
		: "<span class=alarm><b>ERROR</b></span>";

	$site->{body} .= <<EOM;
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

	if ($val_found ne $val_expect)
	{
	$site->{body} .= <<EOM;
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
	}

	$site->{body} .= <<EOM;

</table>
EOM
	}

	{
	my $this_url = $site->{config}->get("this_url");
	my $url = q{/test/path/a///%3Cbr%3E%3F%2F%22hi%22%25%2F..%2Fweird%20/two%0D%0Alines here/c/};

	$site->{body} .= <<EOM;
<h1>Test path interpretation</h1>
<a href="$url"> Example of a strange path </a>
EOM

	my $path = $site->{http}->path;
	my @path = $site->split_path($path);

	shift @path;   # drop "test"
	my $verb = shift @path;

	if (defined $verb && $verb eq "path")
		{
		my $result = "";
		$result .= "<ol class=mono>\n";
		for my $leg (@path)
			{
			my $q_leg = $s->quote($leg);
			$result .= qq{<li>"$q_leg"</li>\n};
			}
		$result .= "</ol>\n";

		my $q_path = $s->quote($path);

		$site->{body} .= <<EOM;
<p>
Path = <span class=mono>"$q_path"</span>
<p>
Interpreted as:
$result
EOM
		}
	}

	return;
	}

sub quote
	{
	my $s = shift;
	my $string = shift;

	return $s->{html}->quote($s->{C}->quote($string));
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
