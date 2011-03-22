use strict;
use c_quote;

=pod

=head1 NAME

A context is an set of key-value pairs in memory which preserves the order in
which the keys were inserted.  This is handy for building url query strings.

=cut

# Make a new context.
sub op_new
	{
	my $op = {};

	$op->{list} = [];
	$op->{hash} = {};

	op_put($op,@_);
	return $op;
	}

# Get the named value from the context.
sub op_get
	{
	my $op = shift;
	my $key = shift;

	die if !defined $op;
	die if !defined $key;

	my $val = $op->{hash}->{$key};
	$val = "" if !defined $val;
	return $val;
	}

# Put one or more key-value pairs into the context.
sub op_put
	{
	my $op = shift;
	die if !defined $op;

	while (@_)
		{
		my $key = shift;
		my $val = shift;

		if (!defined $val || $val eq "")
			{
			if (defined $op->{hash}->{$key})
				{
				delete $op->{hash}->{$key};
				my $pos = 0;
				for (@{$op->{list}})
					{
					if ($_ eq $key)
						{
						splice @{$op->{list}}, $pos, 1;
						last;
						}
					$pos++;
					}
				}
			}
		else
			{
			if (!defined $op->{hash}->{$key})
				{
				push @{$op->{list}}, $key;
				}

			$op->{hash}->{$key} = "".$val;
				# prepend null to force numbers to be stored as strings
			}
		}

	return;
	}

# Put the key value into the context if it's not already there.
sub op_default
	{
	my $op = shift;
	my $key = shift;
	my $val = shift;

	return if op_get($op,$key) ne "";
	op_put($op,$key,$val);
	}

sub op_names
	{
	my $op = shift;
	die if !defined $op;

	return @{$op->{list}};
	}

sub op_slice
	{
	my $op = shift;
	die if !defined $op;

	my @pairs;

	for my $key (@_)
		{
		push @pairs, $key, op_get($op,$key);
		}

	return @pairs;
	}

sub op_pairs
	{
	my $op = shift;

	return op_slice($op,op_names($op));
	}

# KV format, flat on separate lines with C-quoting

# Read the KV text into the given context.
#
# The text is split into lines using either CR-LF or LF as line boundaries.
# Any leading white space on each line is discarded.  Any line that starts
# with ':' is a key line.  Any line that starts with '=' is a value line.
# Any other line is silently ignored.  This allows arbitrary boilerplate to
# be skipped easily, e.g. if you get KV data back from a web query.

sub op_read_kv
	{
	my $op = shift;
	my $text = shift;

	$text = "" if !defined $text;

	my $key = "";

	for my $line (split(/\r?\n/,$text))
		{
		$line =~ s/^\s+//;   # chop any leading white space
		next if $line eq ""; # skip blank lines

		my $type = substr($line,0,1);
		next if $type ne ":" && $type ne "=";

		my $data = c_unquote(substr($line,1));

		if ($type eq ":")
			{
			$key = $data;
			}
		else
			{
			op_put($op,$key,$data);
			}
		}

	return $op;
	}

# Write the Context in KV text format.

sub op_write_kv
	{
	my $op = shift;

	my $text = "(\n";

	for my $key (op_names($op))
		{
		my $val = op_get($op,$key);
		$text .= ":".c_quote($key)."\n";
		$text .= "=".c_quote($val)."\n";
		}

	$text .= ")\n";
	return $text;
	}

return 1;
