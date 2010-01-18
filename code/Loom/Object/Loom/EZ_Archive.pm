package Loom::Object::Loom::EZ_Archive;
use strict;
use Loom::Context;
use Loom::Random;

sub new
	{
	my $class = shift;
	my $api = shift;

	my $s = bless({},$class);
	$s->{api} = $api;
	return $s;
	}

sub buy
	{
	my $s = shift;
	my $loc = shift;
	my $usage = shift;

	$s->{api}->run(
		function => "archive",
		action => "buy",
		loc => $loc,
		usage => $usage
		);
	}

sub sell
	{
	my $s = shift;
	my $loc = shift;
	my $usage = shift;

	$s->{api}->run(
		function => "archive",
		action => "sell",
		loc => $loc,
		usage => $usage
		);
	}

sub touch
	{
	my $s = shift;
	my $loc = shift;

	$s->{api}->run(
		function => "archive",
		action => "touch",
		loc => $loc,
		);

	return $s->{api}->{rsp}->get("content");
	}

sub write
	{
	my $s = shift;
	my $loc = shift;
	my $content = shift;
	my $usage = shift;

	$s->{api}->run(
		function => "archive",
		action => "write",
		loc => $loc,
		content => $content,
		usage => $usage,
		);
	}

# Operations with whole objects.

# LATER could move this into folder code. I don't think this sort of thing
# needs to be mixed into this module.

sub touch_object
	{
	my $s = shift;
	my $loc = shift;

	$s->touch($loc);

	my $obj = Loom::Context->new;
	return $obj if $s->{api}->{rsp}->get("status") ne "success";

	my $content = $s->{api}->{rsp}->get("content");

	$obj->put("content",$content);  # LATER still needed in read_http_headers
	$s->read_http_headers($obj);

	# LATER Here the content is truncated to the text after the headers.
	# We should use streaming to clarify this.

	my $text = $obj->get("content");
	$obj->put("content","");  # don't need raw content any more

	$obj->read_kv($text);

	return $obj;
	}

# LATER could unify with split_content
# LATER could have this return pairs, which we can then send into the
# $obj using ordinary "put" all at once.

sub read_http_headers
	{
	my $s = shift;
	my $obj = shift;

	my $content = $obj->get("content");

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
			$obj->put($1,$2);
			$pos = $new_pos + 1;
			}
		else
			{
			$pos = $new_pos + 1 if $line eq "";
			last;
			}
		}

	$content = substr($content,$pos);
	$obj->put("content",$content);
	}

sub write_object
	{
	my $s = shift;
	my $loc = shift;
	my $obj = shift;
	my $usage = shift;

	my $content = $s->object_text($obj);
	$s->write($loc,$content,$usage);
	}

sub object_text
	{
	my $s = shift;
	my $obj = shift;

	my $content_type = $obj->get("Content-type");

	# Force Content-type to be first line in HTTP format.

	my $copy = Loom::Context->new($obj->pairs, "Content-type" => "");
	my $obj_str = $copy->write_kv;

	my $content = <<EOM;
Content-type: $content_type

$obj_str
EOM

	return $content;
	}

sub random_vacant_location
	{
	my $s = shift;

	my $random = Loom::Random->new;

	my $count = 0;

	while (1)
		{
		$count++;
		die if $count >= 1000;

		my $loc = unpack("H*",$random->get);

		$s->{api}->run(
			function => "archive",
			action => "touch",
			loc => $loc,
			);

		my $rsp = $s->{api}->{rsp};

		if ($rsp->get("status") eq "fail"
			&& $rsp->get("error_loc") eq "vacant")
			{
			return $loc;
			}
		}
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
