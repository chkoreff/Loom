package Loom::Sloop::HTTP::Response;
use strict;

=pod

=head1 NAME

Split HTML headers and content; insert content-length and response code

=cut

sub new
	{
	my $class = shift;

	my $s = bless({},$class);
	return $s;
	}

sub format
	{
	my $s = shift;
	my $text = shift;

	my $op = {};
	$op->{input} = $text;
	$s->respond($op);
	return $op->{output};
	}

sub respond
	{
	my $s = shift;
	my $op = shift;

	$op->{headers} = "";
	if ($op->{detail})
		{
		$op->{header_keys} = [];
		$op->{header_val} = {};
		}

	my $header_end_pos = 0;
	my $pos = 0;

	while (1)
		{
		my $index = index($op->{input}, "\012", $pos);
		last if $index < 0;

		my $line = substr($op->{input},$pos,$index-$pos);
		$line =~ s/\015$//;  # strip trailing CR

		$pos = $index + 1;

		if ($line eq "")
			{
			$header_end_pos = $pos;
			last;
			}
		elsif ($line =~ /^([\w\-]+): (.+)/i)
			{
			# Looks like a header.

			if ($op->{detail})
				{
				my $key = $1;
				my $val = $2;

				push @{$op->{header_keys}}, $key
					if !exists $op->{header_val}->{$key};

				$op->{header_val}->{$key} = $val;
				}

			$op->{headers} .= "$line\n";
			$header_end_pos = $pos;
			}
		elsif ($line ne "")
			{
			# We saw a line which does not look like a header, so
			# we must be inside the content now.

			last;
			}
		}

	$op->{content} = $op->{headers} eq ""
		? $op->{input}
		: substr($op->{input},$header_end_pos);

	my $response_code = $op->{response_code};
	$response_code = "200 OK"
		if !defined $response_code || $response_code eq "";

	my $length = length($op->{content});

	$op->{output} = "";
	$op->{output} .= "HTTP/1.1 $response_code\n";
	$op->{output} .= $op->{headers};
	$op->{output} .= "Content-Length: $length\n\n";
	$op->{output} .= $op->{content};

	return;
	}

return 1;

__END__

# Copyright 2009 Patrick Chkoreff
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
