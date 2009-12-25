package Loom::Sloop::HTTP;
use strict;
use Loom::Context;
use URI::Escape;

# LATER: need to clean up the HTTP parser and make it more "streaming",
# e.g. in the spirit of the Format modules.  Make a Format::HTTP where you
# "put" text in and it hands back tuples as you call "get".  That opens up
# new possibilities for streaming uploads, so we don't have to build a
# representation of the entire HTTP message in memory all at once.

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

sub new
	{
	my $class = shift;

	my $s = bless({},$class);
	$s->start;
	return $s;
	}

# Called when we start to read a new HTTP request.

sub start
	{
	my $s = shift;

	$s->{mode} = "?";  # ? H B
	$s->{line} = "";
	$s->{body} = "";

	$s->{method} = "";
	$s->{uri} = "";
	$s->{proto} = "";
	$s->{file} = "";
	$s->{query} = "";

	$s->{bytes_read} = 0;
	$s->{max_post_size} = 4194304;   # max 2^22 bytes per post (4MB)

	$s->{content_length} = 0;
	$s->{complete} = 0;
	$s->{exiting} = 0;

	$s->{header} = Loom::Context->new;

	# Place where the operational key-value pairs go.
	$s->{op} = Loom::Context->new;

	# Place where the file uploads go, if any.
	$s->{upload} = Loom::Context->new;

	return;
	}

sub parse_data
	{
	my $s = shift;
	my $data = shift;

	my $len = length($data);
	return if $len == 0;

	$s->{bytes_read} += $len;

	if ($s->{bytes_read} > $s->{max_post_size})
		{
		# The post is too big!  Disconnect.

		$s->{exiting} = 1;
		return;
		}

	my $pos = 0;
	my $line = $s->{line};

	while (1)
		{
		last if $s->{mode} eq "B";
		last if $pos >= $len;
		my $ch = substr($data,$pos,1);
		$pos++;

		if ($ch eq "\012")
			{
			if ($line eq "")
				{
				if ($s->{mode} eq "?")
					{
					# Ignore
					}
				elsif ($s->{mode} eq "H")
					{
					# End of headers, switch to Body mode now
					$s->{mode} = "B";
					last;
					}
				}
			else
				{
				if ($s->{mode} eq "?")
					{
					# Start headers
					$s->{mode} = "H";
					if ($line =~ /^(\w+)\s+(\S+)(?:\s+(\S+))?$/)
						{
						$s->{method} = $1;
						$s->{uri} = $2;
						$s->{proto} = $3;

						# split at '?'
						if ($s->{uri} =~ /([^?]*)(?:\?(.*))?/)
							{
							# LATER perhaps = uri_unescape($1)
							# e.g. with a path like /a/%3Cbr%3E%3F%2Fqr

							$s->{file} = $1;
							$s->{query} = $2;
							$s->{query} = "" if !defined $s->{query};
							}
						}
					}
				elsif ($s->{mode} eq "H")
					{
					if ($line =~ /^([\w\-]+): (.+)/i)
						{
						my $key = $1;
						my $val = $2;

						$s->{header}->put($key,$val);

						if ($key eq "Content-Length")
							{
							$s->{content_length} = $val
								if $val =~ /^\d+$/;
							}
						}
					}
				}

			$line = "";
			next;
			}

		$line .= $ch if $ch ne "\015";
		}

	$s->{line} = $line;

	if ($s->{mode} eq "B")
		{
		$s->{body} .= substr($data,$pos);
		if (length($s->{body}) >= $s->{content_length})
			{
			$s->complete;
			}
		}

	return;
	}

# This routine is called when the request is complete.

sub complete
	{
	my $s = shift;

	$s->{complete} = 1;

	my $method = $s->{method};

	if ($method eq "GET")
		{
		$s->parse_urlencoded_body($s->{query});
		}
	elsif ($method eq "POST")
		{
		my $content_type = $s->{header}->get("Content-Type");

		if ($content_type eq "application/x-www-form-urlencoded")
			{
			$s->parse_urlencoded_body($s->{body});
			}
		elsif ($content_type =~
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

	$s->{exiting} = 0;

	my $connection_type = $s->{header}->get("Connection");

	for my $type (split(/\s*,\s*/,$connection_type))
		{
		$type = lc($type);

		if ($type eq "keep-alive")
			{
			$s->{exiting} = 0;
			}
		elsif ($type eq "close")
			{
			$s->{exiting} = 1;
			}
		}

	return;
	}

sub parse_urlencoded_body
	{
	my $s = shift;
	my $body = shift;

	my $op = $s->{op};

	$body =~ tr/+/ /;

	for my $pair ( split( /[&;]/, $body ) )
		{
		my ($name, $value) = split(/=/, $pair);

		next unless defined $name;
		next unless defined $value;

		$name = uri_unescape($name);
		$value = uri_unescape($value);

		$op->put($name,$value);
		}

	return;
	}

# Reference:  ftp://ftp.isi.edu/in-notes/rfc1867.txt

sub parse_multipart_body
	{
	my $s = shift;
	my $boundary = shift;

	my $body = $s->{body};
	my $op = $s->{op};

	$boundary = "--$boundary";
		# actual search string has two extra dashes on the front

	# Search for boundary breaks in the body, breaking the body into chunks.

	my $chunks = [];
	my $pos = 0;

	while (1)
		{
		my $index = index($body, $boundary, $pos);
		last if $index < 0;

		my $chunk = substr($body,$pos,$index-$pos);
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
		# Content-Disposition: form-data; name="filename"; filename="test.txt"
		#
		# With a file upload we set this parameter in the {op} object:
		#
		#   "filename"    => "test.txt"
		#
		# and this parameter in the {upload} object:
		#
		#    "test.txt"   => [... actual file content ...]

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
				$op->put($name,$filename);
				$s->{upload}->put($filename,$value);
				}
			else
				{
				$op->put($name,$value);
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
