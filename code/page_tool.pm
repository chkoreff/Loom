use strict;
use diceware;

sub page_tool_respond
	{
	top_link(highlight_link(top_url(),"Home"));
	top_link(highlight_link(top_url("help",1),"Advanced"));
	top_link(highlight_link(top_url("function","folder_tools"),"Tools",1));

	if (http_get("random_id") ne "")
		{
		my $id = unpack("H*",random_id());
		http_put("id",$id);
		http_put("passphrase","");
		}
	elsif (http_get("random_passphrase") ne "")
		{
		http_put("passphrase",diceware_passphrase(5));
		http_put("id","");
		}
	elsif (http_get("hash_passphrase") ne "")
		{
		my $passphrase = http_get("passphrase");
		my $id = passphrase_location($passphrase);
		http_put("id",$id);
		}

	set_title("Tools");

	my $hidden = html_hidden_fields(http_slice(qw(function session)));

	my $passphrase = http_get("passphrase");
	my $q_passphrase = html_quote($passphrase);

	my $id = http_get("id");
	my $q_id = html_quote($id);

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

	emit(<<EOM
<form method=post action="" autocomplete=off>
$hidden
EOM
);

	emit(<<EOM
<h1> Tools </h1>
On this panel, you may generate a new random identifier or random passphrase.
You may also compute the "hash" of a passphrase, which converts a passphrase
into an identifier.  You may enter the passphrase manually if you don't want
to use a random one.
<p>
$table
EOM
);

	emit(<<EOM
</form>
EOM
);

	return;
	}

return 1;
