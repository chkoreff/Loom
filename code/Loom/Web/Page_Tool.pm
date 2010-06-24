package Loom::Web::Page_Tool;
use strict;

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

	my $op = $site->{op};

	push @{$site->{top_links}},
		$site->highlight_link(
			$site->url,
			"Home");

	push @{$site->{top_links}},
		$site->highlight_link(
			$site->url(help => 1),
			"Advanced");

	push @{$site->{top_links}},
		$site->highlight_link(
		$site->url(function => "folder_tools"),
		"Tools", 1);

	if ($op->get("random_id") ne "")
		{
		my $id = unpack("H*",$site->{random}->get);
		$op->put("id",$id);
		$op->put("passphrase","");
		}
	elsif ($op->get("random_passphrase") ne "")
		{
		$op->put("passphrase",$site->diceware->get(5));
		$op->put("id","");
		}
	elsif ($op->get("hash_passphrase") ne "")
		{
		my $passphrase = $op->get("passphrase");
		my $id = $site->{login}->location($passphrase);
		$op->put("id",$id);
		}

	$site->set_title("Tools");

	my $hidden = $s->{html}->hidden_fields($op->slice(qw(function session)));

	my $passphrase = $op->get("passphrase");
	my $q_passphrase = $s->{html}->quote($passphrase);

	my $id = $op->get("id");
	my $q_id = $s->{html}->quote($id);

	my $input_size_id = 32 + 4;

	my $table = "";
	$table .= <<EOM;
<table border=0 cellpadding=5 style='border-collapse:collapse'>
<colgroup>
<col width=100>
</colgroup>
EOM

	$table .= <<EOM;
<tr>
<td>Identifier:</td>
<td>
<input type=text class=mono name=id size=$input_size_id value="$q_id">
<input type=submit class=small name=random_id value="Random">
</td>
</tr>
<tr>
<td>Passphrase:</td>
<td>
<input type=text class=small name=passphrase size=50 value="$q_passphrase">
<input type=submit class=small name=random_passphrase value="Random">
<input type=submit class=small name=hash_passphrase value="Hash">
</td>
</tr>
EOM

	$table .= <<EOM;
</table>
EOM

	$site->{body} .= <<EOM;
<form method=post action="" autocomplete=off>
$hidden
EOM

	$site->{body} .= <<EOM;
<h1> Tools </h1>
On this panel, you may generate a new random identifier or random passphrase.
You may also compute the "hash" of a passphrase, which converts a passphrase
into an identifier.  You may enter the passphrase manually if you don't want
to use a random one.
<p>
$table
EOM

	$site->{body} .= <<EOM;
</form>
EOM

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
