use strict;
use context;
use sloop_io;
use URI::Escape;

# HTTP Parser
#
# This module incrementally parses an HTTP request, even if the request is
# spread across multiple text chunks coming in sporadically on a socket.
#
# Reference
# ftp://ftp.isi.edu/in-notes/rfc2616.txt
#
# excerpt ~@
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

my $g_buffer;
my $g_bytes_read;
my $g_offset;

my $g_max_size;
my $g_max_line;

my $g_path;
my $g_header;
my $g_op;
my $g_upload;
my $g_content_type;
my $g_content_length;
my $g_connection;
my $g_method;
my $g_uri;
my $g_proto;
my $g_query;

# The following methods should be called after read_message.

# Return the path string.
sub http_path
	{
	return $g_path;
	}

# Split the path on slashes returning a list of path legs.  Apply URI escape
# rules to each leg.  Ignore null legs.
#
# This allows the use of bizarre paths, allowing the encoding of somewhat
# arbitrary data.  For an example see page_test.

sub http_split_path
	{
	my $path = shift;

	my @path;
	for my $leg (split("/",$path))
		{
		next if $leg eq "";
		push @path, uri_unescape($leg);
		}

	return @path;
	}

# Return the key-value map of the query and post parameters.
sub http_op
	{
	return $g_op;
	}

sub http_slice
	{
	return op_slice($g_op,@_);
	}

sub http_names
	{
	return op_names($g_op);
	}

sub http_get
	{
	my $key = shift;
	return op_get($g_op,$key);
	}

sub http_put
	{
	my $key = shift;
	my $val = shift;

	op_put($g_op,$key,$val);
	return;
	}

# Return the value of a named HTTP header.
sub http_header
	{
	my $name = shift;
	return op_get($g_header,$name);
	}

# Return the content of a named uploaded file.
sub http_upload
	{
	my $name = shift;
	return op_get($g_upload,$name);
	}

# Clear the input buffer.
sub http_clear
	{
	$g_buffer = "";
	return;
	}

sub http_parse_urlencoded_body
	{
	my $body = shift;

	$body =~ tr/+/ /;

	for my $pair ( split( /[&;]/, $body ) )
		{
		my ($name, $value) = split(/=/, $pair);

		next unless defined $name;
		next unless defined $value;

		$name = uri_unescape($name);
		$value = uri_unescape($value);

		op_put($g_op,$name,$value);
		}

	return;
	}

# Reference:  ftp://ftp.isi.edu/in-notes/rfc1867.txt

sub http_parse_multipart_body
	{
	my $boundary = shift;

	$boundary = "--$boundary";
		# actual search string has two extra dashes on the front

	# Search for boundary breaks in the body, breaking the body into chunks.

	my $chunks = [];
	my $pos = $g_offset;

	while (1)
		{
		my $index = index($g_buffer, $boundary, $pos);
		last if $index < 0;

		my $chunk = substr($g_buffer,$pos,$index-$pos);
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
				op_put($g_op,$name,$filename);
				op_put($g_upload,$name,$value);
				}
			else
				{
				op_put($g_op,$name,$value);
				}
			}
		}

		}

	return;
	}

sub http_receive
	{
	my $max_read = shift;

	$max_read = $g_max_size - $g_bytes_read
		if $g_bytes_read + $max_read > $g_max_size;

	if ($max_read <= 0)
		{
		sloop_disconnect();
		return 0;
		}

	my $num_read = sloop_receive($g_buffer,$max_read);
	$g_bytes_read += $num_read;

	return $num_read;
	}

sub http_read_line
	{
	while (1)
		{
		return if sloop_exiting();

		my $index = index($g_buffer,"\012",$g_offset);
		if ($index < 0)
			{
			my $len_line = length($g_buffer) - $g_offset;

			if ($len_line > $g_max_line)
				{
				sloop_disconnect();
				return;
				}

			http_receive(128);
			}
		else
			{
			my $len_line = $index - $g_offset;

			my $line = substr($g_buffer, $g_offset, $len_line);
			$line =~ s/\015$//;  # strip trailing CR

			$g_offset = $index + 1;  # skip over this line

			return $line;
			}
		}
	}

# Read an HTTP header line, returning a status code:
#   0 : Saw a header line.
#   1 : Saw a blank line which indicates end of headers.
#   2 : Saw a poorly formed line or reached end of input.

sub http_read_header
	{
	my $line = http_read_line();

	if (!defined $line)
		{
		return 2;
		}
	elsif ($line eq "")
		{
		# Blank line ends headers.
		return 1;
		}
	elsif ($line =~ /^([\w\-]+): (.+)/i)
		{
		# We have a header line.
		my $key = $1;
		my $val = $2;

		op_put($g_header,$key,$val);

		if ($key eq "Content-Length")
			{
			$val = 0 unless $val =~ /^\d+$/;
			$g_content_length = $val;
			}
		elsif ($key eq "Content-Type")
			{
			$g_content_type = $val;
			}
		elsif ($key eq "Connection")
			{
			$g_connection = $val;
			}

		return 0;
		}
	else
		{
		# Disconnect on unrecognized line.
		sloop_disconnect();
		return 2;
		}
	}

# Read some more content, and return 0 when we're done reading all of it.
sub http_read_content
	{
	my $curr_length = length($g_buffer) - $g_offset;
	my $remain = $g_content_length - $curr_length;

	return 0 if $remain <= 0;

	my $max_read = 1048576;  # read at most 2^20 bytes (1 MiB) per round
	$remain = $max_read if $remain > $max_read;

	http_receive($remain);

	return 1;
	}

# Read a complete HTTP message and return true if successful.  Note that if you
# don't call http_clear before this, it will re-parse the last message we read
# into the buffer.   This is actually useful behavior which we use to replay a
# request upon database commit failure.

sub http_read_message
	{
	$g_offset = 0;   # Reset offset to beginning of buffer.

	$g_max_size = 2097152;  # max 2^21 bytes (2 MiB) per complete message
	$g_max_line = 4096;     # max 4096 bytes per line

	# LATER:  This currently limits the ability to upload very large files.
	# Later we can handle the upload function specially, switching to a
	# streaming mode which keeps reading and writing as long as you have
	# sufficient usage tokens.

	$g_method = "";
	$g_uri = "";
	$g_proto = "";
	$g_path = "";
	$g_query = "";

	$g_bytes_read = 0;

	$g_content_length = 0;
	$g_content_type = "";
	$g_connection = "";

	$g_header = op_new();    # headers go here
	$g_op = op_new();        # params go here
	$g_upload = op_new();    # uploads go here

	{
	# Read the request line, which should look something like:
	# GET /path?color=red HTTP/1.1

	my $line = http_read_line();
	return if !defined $line;

	if ($line =~ /^(\w+)\s+(\S+)(?:\s+(\S+))?$/)
		{
		# Looks good.

		$g_method = $1;
		$g_uri = $2;
		$g_proto = $3;
		$g_path = "";
		$g_query = "";

		# split at '?'
		if ($g_uri =~ /([^?]*)(?:\?(.*))?/)
			{
			$g_path = $1;
			$g_query = $2;
			$g_query = "" if !defined $g_query;

			if ($g_method eq "GET")
				{
				http_parse_urlencoded_body($g_query);
				}
			}
		}
	else
		{
		# Disconnect on unrecognized line.  The spec does suggest forgiving
		# leading blank lines, but then I'd have to implement a counter
		# limiting *how many* to forgive.  So I've decided not to tolerate
		# sloppy browsers until I see a compelling case.

		sloop_disconnect();
		return;
		}
	}

	{
	# Read the header lines, terminated with a blank line.

	my $count = 0;

	while (1)
		{
		last if ++$count > 64;  # Impose limit to avoid looping forever.

		my $status = http_read_header();

		return if $status == 2;
		last if $status == 1;
		}
	}

	{
	# Read the subsequent content, whose length was specified in the
	# Content-Length header.

	while (1)
		{
		return if sloop_exiting();
		last if !http_read_content();
		}
	}

	{
	# Request is complete.

	if ($g_method eq "POST")
		{
		if ($g_content_type eq "application/x-www-form-urlencoded")
			{
			http_parse_urlencoded_body(substr($g_buffer,$g_offset));
			}
		elsif ($g_content_type =~
			/^multipart\/form-data; boundary=\"?([^\";,]+)\"?/)
			{
			my $boundary = $1;
			http_parse_multipart_body($boundary);
			}
		}

	# Remain connected (Keep-Alive) by default, but check the connection
	# type(s) to see if we should close the socket.  Note that sometimes on
	# the initial message you'll see "Connection: Keep-Alive" but on
	# subsequent ones just "Connection: TE".  Those subsequent "TE" messages
	# will stay connected by default here.

	for my $type (split(/\s*,\s*/,$g_connection))
		{
		$type = lc($type);

		if ($type eq "close")
			{
			# Disconnect if the connection type is "close".
			sloop_disconnect();
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

return 1;
