package archive;
use strict;
use api;
use context;
use id;
use random;

# LATER unify with page::split_content

sub read_http_headers
	{
	my $obj = shift;

	my $content = context::get($obj,"content");

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
			context::put($obj,$1,$2);
			$pos = $new_pos + 1;
			}
		else
			{
			$pos = $new_pos + 1 if $line eq "";
			last;
			}
		}

	$content = substr($content,$pos);
	context::put($obj,"content",$content);
	return;
	}

sub buy
	{
	my $loc = shift;
	my $usage = shift;

	my $op = context::new
		(
		"function","archive",
		"action","buy",
		"loc",$loc,
		"usage",$usage
		);

	return api::respond($op);
	}

sub sell
	{
	my $loc = shift;
	my $usage = shift;

	my $op = context::new
		(
		"function","archive",
		"action","sell",
		"loc",$loc,
		"usage",$usage
		);

	return api::respond($op);
	}

sub touch
	{
	my $loc = shift;

	my $op = context::new
		(
		"function","archive",
		"action","touch",
		"loc",$loc,
		);

	api::respond($op);
	return context::get($op,"content");
	}

sub look
	{
	my $hash = shift;

	my $op = context::new
		(
		"function","archive",
		"action","look",
		"hash",$hash,
		);

	api::respond($op);
	return context::get($op,"content");
	}

sub get
	{
	my $loc = shift;  # id or hash

	return touch($loc) if id::valid_id($loc);
	return look($loc) if id::valid_hash($loc);
	return "";
	}

sub do_write
	{
	my $loc = shift;
	my $content = shift;
	my $usage = shift;

	my $op = context::new
		(
		"function","archive",
		"action","write",
		"loc",$loc,
		"content",$content,
		"usage",$usage,
		);

	return api::respond($op);
	}

sub is_vacant
	{
	my $loc = shift;

	my $op = context::new
		(
		"function","archive",
		"action","touch",
		"loc",$loc,
		);

	api::respond($op);

	return (context::get($op,"status") eq "fail"
		&& context::get($op,"error_loc") eq "vacant");
	}

sub random_vacant_location
	{
	my $count = 0;

	while (1)
		{
		my $loc = random::hex();
		return $loc if is_vacant($loc);

		$count++;
		die if $count >= 1000;
		}
	}

# Operations with whole objects.

sub touch_object
	{
	my $loc = shift;

	my $obj = context::new();

	my $content = touch($loc);
	return $obj if $content eq "";

	context::put($obj,"content",$content);  # LATER still needed in read_http_headers
	read_http_headers($obj);

	# Here we truncate the content to the text after the headers.

	my $text = context::get($obj,"content");
	context::put($obj,"content","");  # don't need raw content any more

	context::read_kv($obj,$text);

	return $obj;
	}

sub object_text
	{
	my $obj = shift;

	my $content_type = context::get($obj,"Content-Type");
	$content_type = context::get($obj,"Content-type") if $content_type eq "";

	# Force Content-Type to be first line in HTTP format.

	my $copy = context::new(context::pairs($obj));
	context::put($copy,"Content-Type","");
	context::put($copy,"Content-type","");

	my $obj_str = context::write_kv($copy);

	my $content = <<EOM;
Content-Type: $content_type

$obj_str
EOM

	return $content;
	}

sub write_object
	{
	my $loc = shift;
	my $obj = shift;
	my $usage = shift;

	my $content = object_text($obj);
	return do_write($loc,$content,$usage);
	}

return 1;
