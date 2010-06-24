package Loom::Sloop::HTTP::Parse;
use strict;
use Loom::Context;
use URI::Escape;

=pod

=head1 NAME

HTTP Parser

=cut

######
# This module incrementally parses an HTTP request, even if the request is
# spread across multiple text chunks coming in sporadically on a socket.
#
# Reference
# ftp://ftp.isi.edu/in-notes/rfc2616.txt
#
# excerpt @
# HTTP-message = Request | Response    ; HTTP/1.1 messages
#
# Uses the generic message format of RFC 822 [9] for transferring entities
# (the payload of the message).  Both types of message consist of a start-
# line, zero or more header fields (also known as "headers"), an empty line
# (i.e. a line with nothing preceding the CRLF) indicating the end of the
# header fields, and possibly a message-body.
#
# generic-message = start-line
#                   *(message-header CRLF)
#                   CRLF
#                   [ message-body ]
# start-line = Request-Line | Status-Line
#
# In the interest of robustness, servers SHOULD ignore any empty line(s)
# received where a Request-Line is expected. In other words, if the server is
# reading the protocol stream at the beginning of a message and receives a
# CRLF first, it should ignore the CRLF.
#
# Certain buggy HTTP/1.0 client implementations generate extra CRLF's after a
# POST request. To restate what is explicitly forbidden by the BNF, an
# HTTP/1.1 client MUST NOT preface or follow a request with an extra CRLF.
# @
#
# Notice that we support queries with both url parameters and form paramters
# at the same time.  The Sloop test page demonstrates this.
#
# LATER port the Sloop test page over

sub new
	{
	my $class = shift;
	my $client = shift;

	my $s = bless({},$class);
	$s->{client} = $client;
	return $s;
	}

# The following methods should be called after read_complete_message.

# Return the path string.
sub path
	{
	my $s = shift;
	return $s->{path};
	}

# Return the key-value map of the query and post parameters.
sub op
	{
	my $s = shift;
	return $s->{op};
	}

# Return the key-value map of the HTTP headers.
sub header
	{
	my $s = shift;
	return $s->{header};
	}

# Return the key-value map of the uploaded files.
sub upload
	{
	my $s = shift;
	return $s->{upload};
	}

# Clear the input buffer.
sub clear
	{
	my $s = shift;
	$s->{buffer} = "";
	return;
	}

# Read a complete HTTP message and return true if successful.  Note that if you
# don't call "clear" before this, it will re-parse the last message we read
# into the buffer.   This is actually useful behavior which we use to replay a
# request upon database commit failure.

sub read_complete_message
	{
	my $s = shift;

	$s->{offset} = 0;   # Reset offset to beginning of buffer.

	$s->{max_size} = 2097152; # max 2^21 bytes (2 MiB) per complete message

	# LATER:  This currently limits the ability to upload very large files.
	# Later we can handle the upload function specially, switching to a
	# streaming mode which keeps reading and writing as long as you have
	# sufficient usage tokens.

	$s->{method} = "";
	$s->{uri} = "";
	$s->{proto} = "";
	$s->{path} = "";
	$s->{query} = "";

	$s->{bytes_read} = 0;

	$s->{content_length} = 0;
	$s->{content_type} = "";
	$s->{connection} = "";

	$s->{header} = undef;
	$s->{op} = undef;
	$s->{upload} = undef;

	$s->{header} = Loom::Context->new;    # headers go here
	$s->{op} = Loom::Context->new;        # params go here
	$s->{upload} = Loom::Context->new;    # uploads go here

	{
	# Read the request line, which should look something like:
	# GET /path?color=red HTTP/1.1

	my $line = $s->read_line;
	return if !defined $line;

	if ($line =~ /^(\w+)\s+(\S+)(?:\s+(\S+))?$/)
		{
		# Looks good.

		$s->{method} = $1;
		$s->{uri} = $2;
		$s->{proto} = $3;
		$s->{path} = "";
		$s->{query} = "";

		# split at '?'
		if ($s->{uri} =~ /([^?]*)(?:\?(.*))?/)
			{
			$s->{path} = $1;
			$s->{query} = $2;
			$s->{query} = "" if !defined $s->{query};

			$s->parse_urlencoded_body($s->{query});
			}
		}
	else
		{
		# Disconnect on unrecognized line.  The spec does suggest forgiving
		# leading blank lines, but then I'd have to implement a counter
		# limiting *how many* to forgive.  So I've decided not to tolerate
		# sloppy browsers until I see a compelling case.

		$s->{client}->disconnect;
		return;
		}
	}

	{
	# Read the header lines, terminated with a blank line.

	my $count = 0;

	while (1)
		{
		last if ++$count > 64;  # Impose limit to avoid looping forever.

		my @result = $s->read_header;
		my $verb = shift @result;

		return if $verb eq "";
		last if $verb eq "end";

		$s->{header}->put(@result);
		}
	}

	{
	# Read the subsequent content, whose length was specified in the
	# Content-Length header.

	my $max_read = 1048576;  # read at most 2^20 bytes (1 MiB) per round

	while (1)
		{
		return if $s->{client}->exiting;
		last if !$s->read_content($max_read);
		}
	}

	{
	# Request is complete.

	if ($s->{method} eq "POST")
		{
		if ($s->{content_type} eq "application/x-www-form-urlencoded")
			{
			$s->parse_urlencoded_body( substr($s->{buffer},$s->{offset}) );
			}
		elsif ($s->{content_type} =~
			/^multipart\/form-data; boundary=\"?([^\";,]+)\"?/)
			{
			my $boundary = $1;
			$s->parse_multipart_body($boundary);
			}
		}

	# Remain connected (Keep-Alive) by default, but check the connection
	# type(s) to see if we should close the socket.  Note that sometimes on
	# the initial message you'll see "Connection: Keep-Alive" but on
	# subsequent ones just "Connection: TE".  Those subsequent "TE" messages
	# will stay connected by default here.

	for my $type (split(/\s*,\s*/,$s->{connection}))
		{
		$type = lc($type);

		if ($type eq "close")
			{
			# Disconnect if the connection type is "close".
			$s->{client}->disconnect;
			}
		else
			{
			# Stay connected if the connection type is anything else, typically
			# "keep-alive".
			}
		}
	}

	return 1;
	}

sub read_header
	{
	my $s = shift;

	my $line = $s->read_line;
	return ("") if !defined $line;

	if ($line eq "")
		{
		# Blank line ends headers.
		return ("end");
		}
	elsif ($line =~ /^([\w\-]+): (.+)/i)
		{
		# We have a header line.
		my $key = $1;
		my $val = $2;

		if ($key eq "Content-Length")
			{
			$val = 0 unless $val =~ /^\d+$/;
			$s->{content_length} = $val;
			}
		elsif ($key eq "Content-Type")
			{
			$s->{content_type} = $val;
			}
		elsif ($key eq "Connection")
			{
			$s->{connection} = $val;
			}

		return ("pair",$1,$2);
		}
	else
		{
		# Disconnect on unrecognized line.
		$s->{client}->disconnect;
		return ("");
		}
	}

sub read_content
	{
	my $s = shift;
	my $max_read = shift;

	my $curr_length = length($s->{buffer}) - $s->{offset};
	my $remain = $s->{content_length} - $curr_length;

	return 0 if $remain <= 0;

	$remain = $max_read if $remain > $max_read;
	$s->receive($remain);

	return 1;
	}

sub read_line
	{
	my $s = shift;

	my $max_line = 4096;  # max 4096 bytes per line

	while (1)
		{
		return if $s->{client}->exiting;

		my $index = index($s->{buffer},"\012",$s->{offset});
		if ($index < 0)
			{
			my $len_line = length($s->{buffer}) - $s->{offset};

			if ($len_line > $max_line)
				{
				$s->{client}->disconnect;
				return;
				}

			$s->receive(128);
			}
		else
			{
			my $len_line = $index - $s->{offset};

			my $line = substr($s->{buffer}, $s->{offset}, $len_line);
			$line =~ s/\015$//;  # strip trailing CR

			$s->{offset} = $index + 1;  # skip over this line

			return $line;
			}
		}
	}

sub receive
	{
	my $s = shift;
	my $max_read = shift;

	my $max_size = $s->{max_size};
	my $bytes_read = $s->{bytes_read};

	$max_read = $max_size - $bytes_read
		if $bytes_read + $max_read > $max_size;

	if ($max_read <= 0)
		{
		$s->{client}->disconnect;
		return 0;
		}

	my $num_read = $s->{client}->receive($s->{buffer}, $max_read);
	$s->{bytes_read} += $num_read;

	return $num_read;
	}

sub parse_urlencoded_body
	{
	my $s = shift;
	my $body = shift;

	$body =~ tr/+/ /;

	for my $pair ( split( /[&;]/, $body ) )
		{
		my ($name, $value) = split(/=/, $pair);

		next unless defined $name;
		next unless defined $value;

		$name = uri_unescape($name);
		$value = uri_unescape($value);

		$s->{op}->put($name,$value);
		}

	return;
	}

# Reference:  ftp://ftp.isi.edu/in-notes/rfc1867.txt

sub parse_multipart_body
	{
	my $s = shift;
	my $boundary = shift;

	$boundary = "--$boundary";
		# actual search string has two extra dashes on the front

	# Search for boundary breaks in the body, breaking the body into chunks.

	my $chunks = [];
	my $pos = $s->{offset};

	while (1)
		{
		my $index = index($s->{buffer}, $boundary, $pos);
		last if $index < 0;

		my $chunk = substr($s->{buffer},$pos,$index-$pos);
		push @$chunks, $chunk;

		$pos = $index + length($boundary);
		}

	# Process each chunk between the boundary markers.

	for my $chunk (@$chunks)
		{
		my $pos = 0;

		# Skip any leading blank lines.  Then process non-blank lines within
		# the chunk, stopping when you reach the first blank line.

		my $saw_line = 0;
		my $headers = {};

		while (1)
			{
			my $index = index($chunk, "\012", $pos);
			last if $index < 0;

			my $line = substr($chunk,$pos,$index-$pos);
			$line =~ s/\015$//;  # strip trailing CR

			$pos = $index + 1;

			last if $line eq "" && $saw_line;

			$saw_line = 1;

			if ($line =~ /^([\w\-]+): (.+)/i)
				{
				my $key = $1;
				my $val = $2;

				$key = lc($key);  # normalize headers as lower-case

				$headers->{$key} = $val;
				}
			}

		# Now get the parameter name from the Content-Disposition header,
		# e.g.:
		#
		# Content-Disposition: form-data; name="color"
		#
		# If a file is being uploaded you'll also have a filename, e.g.
		#
		# Content-Disposition: form-data; name="file1"; filename="test.txt"

		{
		my $name;
		my $filename;

		my $disposition = $headers->{"content-disposition"};

		if (defined $disposition)
			{
			($name) = $disposition =~ / name="?([^\";]+)"?/;
			($filename) = $disposition =~ / filename="?([^\"]*)"?/;
			}

		if (defined $name)
			{
			# Get parameter value and Strip trailing CRLF.

			my $value = substr($chunk,$pos);
			$value =~ s/\015\012$//;

			if (defined $filename)
				{
				$s->{op}->put($name,$filename);
				$s->{upload}->put($name,$value);
				}
			else
				{
				$s->{op}->put($name,$value);
				}
			}
		}

		}

	return;
	}

return 1;

__END__

# Copyright 2006 Patrick Chkoreff
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
