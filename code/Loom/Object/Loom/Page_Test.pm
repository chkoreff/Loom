package Loom::Object::Loom::Page_Test;
use strict;
use Loom::Context;
use Loom::Quote::C;

sub new
	{
	my $class = shift;
	my $site = shift;

	my $s = bless({},$class);
	$s->{site} = $site;
	$s->{html} = $site->{html};
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
<h1>Test</h1>
<p>
This is a test of HTML quoting rules in urls and hidden form fields.
<p>
This extreme test case doesn't work perfectly when using the form, because
I've included \\015 (CR) chars in the value.  Works fine with the link though,
because uri_escape works like a charm there.
EOM

	my $context = Loom::Context->new($op->slice(qw(function)));

	# LATER doesn't work as hidden field with \015 in key or val.

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
<a href="$url">Test using the link</a>
EOM

	my $val_found = $op->get($key_expect);

	my $C = Loom::Quote::C->new;

	my $q_key_expect = $s->{html}->quote($C->quote($key_expect));
	my $q_val_found = $s->{html}->quote($C->quote($val_found));
	my $q_val_expect = $s->{html}->quote($C->quote($val_expect));

	my $hidden = $s->{html}->hidden_fields($context->pairs);

	$site->{body} .= <<EOM;
<p>
<form method=post action="">
$hidden
<p>
<input type=submit name=go value="Test using the form">
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
