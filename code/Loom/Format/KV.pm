package Loom::Format::KV;
use strict;
use Loom::Format::Lines;
use Loom::Quote::C;

sub new
	{
	my $class = shift;

	my $s = bless({},$class);
	$s->{mode} = "?";   # modes: ? K V
	$s->{key} = "";
	$s->{quote} = Loom::Quote::C->new;
	$s->{lines} = Loom::Format::Lines->new;
	return $s;
	}

sub put
	{
	my $s = shift;
	$s->{lines}->put(@_);
	return;
	}

sub get
	{
	my $s = shift;

	while (1)
		{
		my $line = $s->{lines}->get;
		return () if !defined $line;
		next if $line =~ /^\s*$/;  # ignore blank lines
		next if $line =~ /^#/;     # ignore comments

		if ($s->{mode} eq "?")
			{
			if ($line eq "(")
				{
				$s->{mode} = "K";
				return ("B");  # begin
				}
			return ("?",$line);  # ignore lines before open paren
			}
		elsif ($s->{mode} eq "K")
			{
			if ($line eq ")")
				{
				$s->{mode} = "?";
				return ("E");  # end
				}

			return ("!","K",$line) if substr($line,0,1) ne ":";

			$s->{key} = $s->{quote}->unquote(substr($line,1));
			$s->{mode} = "V";
			}
		elsif ($s->{mode} eq "V")
			{
			return ("!","V",$line) if substr($line,0,1) ne "=";

			my $key = $s->{key};
			my $val = $s->{quote}->unquote(substr($line,1));

			$s->{mode} = "K";
			$s->{key} = "";

			return ("P",$key,$val);
			}
		else
			{
			die;
			}
		}
	}

sub finish
	{
	my $s = shift;
	return $s->{lines}->finish;
	}

package Loom::Format::KV::Out;
use strict;

sub new
	{
	my $class = shift;

	my $s = bless({},$class);
	$s->{quote} = Loom::Quote::C->new;
	$s->{lines} = Loom::Format::Lines::Out->new;
	return $s;
	}

sub put
	{
	my $s = shift;
	my $verb = shift;

	return () if !defined $verb;

	my $lines = $s->{lines};

	if ($verb eq "P")
		{
		my $key = shift;
		my $val = shift;

		my $q_key = $s->{quote}->quote($key);
		my $q_val = $s->{quote}->quote($val);

		return ($lines->put(":$q_key"), $lines->put("=$q_val"));
		}
	elsif ($verb eq "B")
		{
		return ( $lines->put("(") );
		}
	elsif ($verb eq "E")
		{
		return ( $lines->put(")") );
		}
	elsif ($verb eq "?")
		{
		my $line = shift;
		return ($lines->put($line));
		}

	return ();   # note that we don't format errors ("!" ...)
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
