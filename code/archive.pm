use strict;
use api;
use id;
use random;

# LATER unify with split_content

sub read_http_headers
	{
	my $obj = shift;

	my $content = op_get($obj,"content");

	my $pos = 0;

	while (1)
		{
		my $new_pos = index($content,"\n",$pos);
		last if $new_pos < 0;

		my $line = substr($content, $pos, $new_pos-$pos);
		$line =~ s/\015$//;  # strip CR if there

		if ($line =~ /^(\S+):\s*(\S+)$/)
			{
			# Line matches "name: value".  Save in object.
			op_put($obj,$1,$2);
			$pos = $new_pos + 1;
			}
		else
			{
			$pos = $new_pos + 1 if $line eq "";
			last;
			}
		}

	$content = substr($content,$pos);
	op_put($obj,"content",$content);
	return;
	}

sub archive_buy
	{
	my $loc = shift;
	my $usage = shift;

	my $op = op_new
		(
		"function","archive",
		"action","buy",
		"loc",$loc,
		"usage",$usage
		);

	return api_respond($op);
	}

sub archive_sell
	{
	my $loc = shift;
	my $usage = shift;

	my $op = op_new
		(
		"function","archive",
		"action","sell",
		"loc",$loc,
		"usage",$usage
		);

	return api_respond($op);
	}

sub archive_touch
	{
	my $loc = shift;

	my $op = op_new
		(
		"function","archive",
		"action","touch",
		"loc",$loc,
		);

	api_respond($op);
	return op_get($op,"content");
	}

sub archive_look
	{
	my $hash = shift;

	my $op = op_new
		(
		"function","archive",
		"action","look",
		"hash",$hash,
		);

	api_respond($op);
	return op_get($op,"content");
	}

sub archive_get
	{
	my $loc = shift;  # id or hash

	return archive_touch($loc) if valid_id($loc);
	return archive_look($loc) if valid_hash($loc);
	return "";
	}

sub archive_write
	{
	my $loc = shift;
	my $content = shift;
	my $usage = shift;

	my $op = op_new
		(
		"function","archive",
		"action","write",
		"loc",$loc,
		"content",$content,
		"usage",$usage,
		);

	return api_respond($op);
	}

sub archive_is_vacant
	{
	my $loc = shift;

	my $op = op_new
		(
		"function","archive",
		"action","touch",
		"loc",$loc,
		);

	api_respond($op);

	return (op_get($op,"status") eq "fail"
		&& op_get($op,"error_loc") eq "vacant");
	}

sub archive_random_vacant_location
	{
	my $count = 0;

	while (1)
		{
		my $loc = unpack("H*",random_id());
		return $loc if archive_is_vacant($loc);

		$count++;
		die if $count >= 1000;
		}
	}

# Operations with whole objects.

sub archive_touch_object
	{
	my $loc = shift;

	my $obj = op_new();

	my $content = archive_touch($loc);
	return $obj if $content eq "";

	op_put($obj,"content",$content);  # LATER still needed in read_http_headers
	read_http_headers($obj);

	# Here we truncate the content to the text after the headers.

	my $text = op_get($obj,"content");
	op_put($obj,"content","");  # don't need raw content any more

	op_read_kv($obj,$text);

	return $obj;
	}

sub archive_object_text
	{
	my $obj = shift;

	my $content_type = op_get($obj,"Content-Type");
	$content_type = op_get($obj,"Content-type") if $content_type eq "";

	# Force Content-Type to be first line in HTTP format.

	my $copy = op_new(op_pairs($obj));
	op_put($copy,"Content-Type","");
	op_put($copy,"Content-type","");

	my $obj_str = op_write_kv($copy);

	my $content = <<EOM;
Content-Type: $content_type

$obj_str
EOM

	return $content;
	}

sub archive_write_object
	{
	my $loc = shift;
	my $obj = shift;
	my $usage = shift;

	my $content = archive_object_text($obj);
	return archive_write($loc,$content,$usage);
	}

return 1;
