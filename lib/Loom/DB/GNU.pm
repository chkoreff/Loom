package Loom::DB::GNU;
use strict;
use GDBM_File;
use Fcntl qw(:flock);

sub new
	{
	my $class = shift;
	my $filename = shift;

	my $s = bless({},$class);

	$s->{name} = $filename;
	$s->{handle} = undef;
	$s->{hash} = undef;
	$s->{fh_lockfile} = undef;

	return $s;
	}

sub get
	{
	my $s = shift;
	my $key = shift;

	die if !defined $key || ref($key) ne "";

	$s->need_db;

	my $val;
	$val = $s->{handle}->FETCH($key) if defined $s->{handle};
	$val = '' unless defined $val;
	return $val;
	}

# Writing a null value deletes the key.

sub put
	{
	my $s = shift;
	my $key = shift;
	my $val = shift;

	die if !defined $key || ref($key) ne "";
	die if !defined $val || ref($val) ne "";

	$s->need_db;

	if (defined $s->{handle})
		{
		$val = '' unless defined $val;
		if ($val ne '')
			{
			$s->{handle}->STORE($key, $val);
			}
		else
			{
			$s->{handle}->DELETE($key);
			}
		}

	return $val;
	}

# GDBM_File has a built-in feature which ensures that only one process can
# write to the database.  If a second process tries to open the database,
# the "tie" routine will return an undefined handle immediately.  That's
# good, because at least there is no risk of strange concurrent update
# problems.
#
# However, that behavior is not quite good enough for this module.  We don't
# want the caller to have to check the database handle to see if it was
# opened successfully, and then engage in some sort of busy wait or locking
# mechanism of its own.  Instead, we provide blocking semantics right here
# in this module to make things easy for the caller.  The "flock" call below
# will block until the process acquires an exclusive handle on the .lock file,
# and only then will we try to open the database.

sub need_db
	{
	my $s = shift;

	return if defined $s->{handle};
	return if !defined $s->{name};

	$s->{hash} = {};

	open($s->{fh_lockfile}, ">$s->{name}.lock") or die $!;
	flock($s->{fh_lockfile}, LOCK_EX) or die $!;

	$s->{handle} = tie
		%{$s->{hash}},
		'GDBM_File',
		$s->{name},
		&GDBM_WRCREAT,
		0640
		or die $!;
	}

# The first_key and next_key routines are useful for maintenance scripts that
# sweep through an entire database.  Typically it is not good practice to rely
# on this kind of iteration for ordinary application purposes.

sub first_key
	{
	my $s = shift;

	$s->need_db;

	my $key;

	if (defined $s->{handle})
		{
		$key = $s->{handle}->FIRSTKEY;
		}

	return $key;
	}

sub next_key
	{
	my $s = shift;
	my $after = shift;

	die if !defined $after || ref($after) ne "";

	$s->need_db;

	my $key;

	if (defined $s->{handle})
		{
		$key = $s->{handle}->NEXTKEY($after);
		}

	return $key;
	}

# Flushes any cached buffers to disk.
sub sync
	{
	my $s = shift;

	return if !defined $s->{handle};
	$s->{handle}->sync;
	}

sub stream
	{
	my $s = shift;
	my $out = shift;

	die if !defined $out;

	$s->need_db;

	my $handle = $s->{handle};

	my $key = $handle->FIRSTKEY;

	while (defined $key)
		{
		my $val = $handle->FETCH($key);
		$out->put($key, $val);
		$key = $handle->NEXTKEY($key);
		}

	return $out;
	}

sub finish
	{
	my $s = shift;

	return if !defined $s->{handle};

	$s->{handle} = undef;
	untie %{$s->{hash}};
	$s->{hash} = undef;

	close($s->{fh_lockfile});
	}

*DESTROY = *finish;

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
