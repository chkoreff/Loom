package Loom::File;
use strict;
use Fcntl qw(:DEFAULT :flock);

=pod

=head1 NAME

Loom::File - Robust concurrent file operations

=cut

# Create a new file object with the given path.  Initially, this object simply
# holds the path for future reference -- no files are opened or created right
# away.  In effect, the object is a reference to an arbitrary file which could
# be a text file, a directory, or not even exist yet.
#
# The $level is an optional level which restricts operations to within a
# specific directory.  Normally this is passed in from the "child" operation.

sub new
	{
	my $class = shift;
	my $path = shift;
	my $level = shift;  # optional restrict level

	$path = $class->normalize_path($path,$level);
	return undef if !defined $path;

	my $s = bless({},$class);
	$s->{fh} = undef;
	$s->{path} = $path;
	$s->{mode} = "";
	$s->{error} = "";
	$s->{level} = $level;
	return $s;
	}

# Return the full path of this object.

sub full_path
	{
	my $s = shift;

	return $s->{path};
	}

# Return the path of this object relative to its restricted context.

sub local_path
	{
	my $s = shift;

	my @path = split("/",$s->{path});
	my $level = $s->{level};
	$level = 1 if !defined $level || $level < 1;

	for (1 .. $level)
		{
		shift @path;
		}

	return join("/",@path);
	}

# Return the name of this object without any preceding path.

sub name
	{
	my $s = shift;

	my @path = split("/",$s->local_path);
	return undef if @path == 0;
	return $path[$#path];
	}

# Return the type of this file object.  The result is "f" for a text file,
# "d" for a directory, or "" (null) if the file does not exist.

sub type
	{
	my $s = shift;

	return "f" if -f $s->{path};
	return "d" if -d _;
	return "";
	}

# Return the size in bytes of this file.  This does return a number for a
# directory as well, though that may not be useful.

sub size
	{
	my $s = shift;

	return -s $s->{path};
	}

# Restrict all operations to this directory, never allowing any "child"
# operation to stray outside it.

sub restrict
	{
	my $s = shift;

	my @path = split("/",$s->{path});
	$s->{level} = scalar(@path);
	return $s;
	}

# Return the child with the given path relative to this file.

sub child
	{
	my $s = shift;
	my $path = shift;

	$path = "" if !defined $path;
	return ref($s)->new("$s->{path}/$path",$s->{level});
	}

# Return the parent of this file, or undef if we're at the top level and thus
# no parent exists.

sub parent
	{
	my $s = shift;

	return $s->child("..");
	}

# Create a text file here.  Return true if the file did not exist and was
# successfully created.

sub create_file
	{
	my $s = shift;

	return 0 if $s->{mode} ne "";  # already open
	return 0 if $s->type ne "";    # already exists

	if (!defined $s->{fh} && !sysopen($s->{fh},$s->{path},O_CREAT))
		{
		$s->{fh} = undef;
		$s->{error} = $!;
		return 0;
		}

	$s->{mode} = "R";
	$s->release;

	return 1;
	}

# Remove the text file here.  Return true if the file did exist and was
# successfully removed.
#
# Note that we do NOT release (close) the file here.  That's because sometimes
# you need to leave a file opened and locked even after you unlink it.  For
# example, the "update" routine demands that all files remain locked until the
# very end, even if it does deletions along the way.  That maintains the
# proper gating function which is critical in a concurrent environment.  If
# files were released when deleted, our stress test would fail, revealing
# data integrity errors.

sub remove_file
	{
	my $s = shift;

	return unlink($s->{path});
	}

# Create a directory here.  Return true if the directory did not exist and was
# successfully created.

sub create_dir
	{
	my $s = shift;

	return mkdir($s->{path});
	}

# Remove the directory here.  Return true if the directory did exist and was
# successfully removed.  Note that the directory can only be removed if it is
# empty.

sub remove_dir
	{
	my $s = shift;

	return rmdir($s->{path});
	}

# Remove the entire directory tree here.

sub remove_tree
	{
	my $s = shift;

	my $type = $s->type;

	return 0 if $type eq "";
	return $s->remove_file if $type eq "f";

	$s->remove_children;
	return $s->remove_dir;
	}

# Remove all the children of this directory.

sub remove_children
	{
	my $s = shift;

	for my $name ($s->names)
		{
		$s->child($name)->remove_tree;
		}

	return;
	}

# Rename the underlying file system object (file or directory) to which this
# Perl object refers.  This can be used to move the underlying file system
# object to another directory.  Note that this operation does not change
# the path of the Perl object itself.  After the rename, the Perl object still
# contains the old path, which now refers to a non-existent file system object.
#
# Note that this rename will clobber any existing destination.

sub rename
	{
	my $s = shift;
	my $path = shift;

	$s->release;
	rename $s->{path}, $path;
	}

# Create the enclosing path to this object.  This creates any directories which
# lead to this object.

sub create_path
	{
	my $s = shift;

	my $parent = $s->parent;
	return 1 if !defined $parent;

	my $type = $parent->type;
	return 1 if $type eq "d";
	return 0 if $type eq "f";

	return 0 if !$parent->create_path;
	return $parent->create_dir;
	}

# Remove the enclosing path to this object, as far up the tree as possible.
# This removes any empty directories which lead to this object.

sub remove_path
	{
	my $s = shift;

	my $parent = $s->parent;
	return 1 if !defined $parent;

	return 0 if !$parent->remove_dir;
	return $parent->remove_path;
	}

# Open this file for read access with a shared lock.  Returns true if it
# got the lock on a normal attached file.  See is_detached below for a
# discussion of attached and detached files.

sub read
	{
	my $s = shift;
	my $blocking = shift;  # optional, default 1

	return 1 if $s->{mode} eq "R";
	return 0 if $s->{mode} ne "";

	if (!defined $s->{fh} && !sysopen($s->{fh},$s->{path},O_RDONLY))
		{
		$s->{fh} = undef;
		$s->{error} = $!;
		return 0;
		}

	$blocking = 1 if !defined $blocking;

	my $locked = $blocking
		? flock($s->{fh}, LOCK_SH)
		: flock($s->{fh}, LOCK_SH|LOCK_NB);

	return 0 if !$locked;

	if ($s->is_detached)
		{
		$s->release;
		return 0;
		}

	$s->{mode} = "R";
	$s->{error} = "";
	return 1;
	}

# Open this file for write access with an exclusive lock.  Returns true if it
# got the lock on a normal attached file.  See is_detached below for a
# discussion of attached and detached files.

sub write
	{
	my $s = shift;
	my $blocking = shift;  # optional, default 1

	return 1 if $s->{mode} eq "W";
	return 0 if $s->{mode} ne "";

	if (!defined $s->{fh} && !sysopen($s->{fh},$s->{path},O_RDWR))
		{
		$s->{fh} = undef;
		$s->{error} = $!;
		return 0;
		}

	$blocking = 1 if !defined $blocking;

	my $locked = $blocking
		? flock($s->{fh}, LOCK_EX)
		: flock($s->{fh}, LOCK_EX|LOCK_NB);

	return 0 if !$locked;

	if ($s->is_detached)
		{
		$s->release;
		return 0;
		}

	$s->{mode} = "W";
	$s->{error} = "";

	return 1;
	}

# Return true if the file is open but "detached", meaning that it has been
# unlinked from its parent directory and is now a free-floating file.  Such a
# thing can be useful as an anonymous temporary file which disappears when the
# process ends.  However, when you're using the file system as a database,
# where the presence or absence of a file means something, detached files are
# a recipe for subtle data integrity errors
#
# This routine is called by "read" and "write", which open a file and then
# attempt to obtain a shared or exclusive lock.  Between the time the file is
# opened and the lock is obtained, another process could unlink (delete) the
# file, causing it to become detached from its parent directory.  In that case
# the read or write routine will release the file and return false, meaning
# that it failed to obtain a lock on a normal attached file.
#
# Note that the "update" routine depends on this behavior.  With the detach
# check in place, our stress test is rock solid.  But if the detach check is
# omitted, the stress test will reveal data integrity problems.

sub is_detached
	{
	my $s = shift;

	my $fh = $s->{fh};
	return 0 if !defined $fh;

	my @stat = stat $fh;
	my $nlink = $stat[3];  # number of hard links to this file

	return 0 if $nlink > 0;
		# The file has at least one hard link to it, meaning that it's still
		# linked into at least one parent directory.  It is not detached.

	# There are no hard links to this file -- not even from a parent
	# directory.  It's a detached file!

	return 1;
	}

# Release (close) this file if open.

sub release
	{
	my $s = shift;

	return 0 if $s->{mode} eq "";
	return 0 if !defined $s->{fh};

	close($s->{fh});
	$s->{fh} = undef;
	$s->{mode} = "";

	return 1;
	}

# Called automatically when a file object goes out of scope.

sub DESTROY
	{
	my $s = shift;
	$s->release;
	}

# Read the next line from the open file.

sub line
	{
	my $s = shift;

	return undef if $s->{mode} eq "";
	return undef if !defined $s->{fh};

	my $fh = $s->{fh};
	my $line = <$fh>;
	return $line;
	}

# Read a specific number of bytes from the open file if possible.

sub get_bytes
	{
	my $s = shift;
	my $num_bytes = shift;

	return undef if !defined $num_bytes;

	return undef if $s->{mode} eq "";
	return undef if !defined $s->{fh};

	my $data;
	my $len = sysread($s->{fh},$data,$num_bytes);

	return $data;
	}

# Get the entire content of the file.

sub get
	{
	my $s = shift;

	$s->read;

	return undef if $s->{mode} eq "";
	return undef if !defined $s->{fh};

	seek($s->{fh}, 0, 0);

	my $text = "";
	my $pos = 0;
	while (1)
		{
		my $num_read = sysread($s->{fh},$text,16384,$pos);
		if (!defined $num_read)
			{
			next if $! =~ /^Interrupted/;
			$s->{error} = $!;
			return undef;
			}
		last if $num_read == 0;
		$pos += $num_read;
		}

	return $text;
	}

# Replace the entire content of the open file.

sub put
	{
	my $s = shift;
	my $text = shift;

	$s->write;

	return 0 if $s->{mode} ne "W";
	return 0 if !defined $s->{fh};

	seek($s->{fh}, 0, 0);
	truncate($s->{fh}, 0);

	return $s->put_bytes($text);
	}

# Append the text to the open file.

sub append
	{
	my $s = shift;
	my $text = shift;

	return 0 if $s->{mode} ne "W";
	return 0 if !defined $s->{fh};

	seek($s->{fh}, 0, 2);

	return $s->put_bytes($text);
	}

# Write the bytes to the open file at the current position.

sub put_bytes
	{
	my $s = shift;
	my $text = shift;

	return 0 if $s->{mode} ne "W";
	return 0 if !defined $s->{fh};

	my $pos = 0;
	my $len = length($text);
	while (1)
		{
		last if $len == 0;
		my $num_written = syswrite($s->{fh},$text,$len,$pos);
		if (!defined $num_written)
			{
			$s->{error} = $!;
			return 0;
			}
		$len -= $num_written;
		$pos += $num_written;
		}

	return 1;
	}

# Atomic parallel update routine.
#
# This routine updates a set of files underneath the given directory $s.
# You pass in two hash tables, $new and $old.  Each table is a map from key
# (file name) to a corresponding value.
#
# The routine first locks any files mentioned in the $new table, in ASCII
# order to prevent deadlock.  Any files which do not exist are created
# automatically.
#
# After locking all the files, the routine then examines the current values of
# all those files, comparing them against the values specified in the $old
# table.  If all the values match, then the routine will proceed to change all
# the files to the values specified in the $new table.  But if any value does
# not match, the routine will not do any updates at all.
#
# The routine will delete any file whose value is set to null ("").  It will
# also automatically delete any directories which become empty.  So you can
# think of the update routine as automatically creating and deleting any
# directory structure needed to support the keys (file names) which are
# mentioned in the $new table.
#
# As an extra security precaution, we recommend that you call "restrict" on the
# directory handle before calling "update".  That will prevent any keys from
# using ".." to reach up and modify files outside the directory.  Calling
# restrict will make the directory into a securely sealed off "sandbox".
#
# This routine has been highly tested under extreme processor loads and
# adverse timing conditions to maximize contention.  Many code branches are
# very difficult to reach under ordinary conditions, but by inserting random
# delays (see below) I was able to test every branch repeatably.
#
# See the "test_file" program for an extreme stress test.
#
# Note that the update routine calls only normal module routines.  It does not
# do any privileged operations.
#
# LATER possibly optimize to readonly (shared lock) when new_val eq old_val,
# or when new_val is undefined.  That might be useful for enforcing a
# functional dependency without attempting a write, and could gain some
# extra efficiency.  I would have to engineer a rigorous test suite for this
# though.

sub update
	{
	my $s = shift;
	my $new = shift;
	my $old = shift;

	my $ok = 1;

	my @key_list = keys %$new;

	my $file_map = {};  # map from key (name) to file object
	my @file_list;      # list of file objects to update

	for my $key (@key_list)
		{
		my $file = $s->child($key);
		if (!defined $file)
			{
			# Tried to venture outside of restricted directory scope.
			$ok = 0;
			last;
			}

		# Try to create the file in case it doesn't already exist.  Otherwise
		# we wouldn't be able to lock it.

		$file->create_path;
		$file->create_file;

		$file_map->{$key} = $file;
		push @file_list, $file;
		}

	if ($ok)
		{
		# Sort files with Schwartzian transform.

		@file_list =
			map { $_->[0] }
			sort { $a->[1] cmp $b->[1] }
			map { [$_, $_->full_path ] }
			@file_list;

		# Lock the files in order.

		for my $file (@file_list)
			{
			next if $file->write;

			$ok = 0;
			last;
			}
		}

	if ($ok)
		{
		# We now have exclusive locks on all files.  Now check any specified
		# old values to make sure they still hold.

		for my $key (@key_list)
			{
			my $file = $file_map->{$key};

			my $old_val = $old->{$key};
			next if !defined $old_val;

			my $curr_val = $file->get;
			next if defined $curr_val && $curr_val eq $old_val;

			$ok = 0;   # something didn't match!

			if (defined $curr_val && $curr_val eq "")
				{
				# It's an empty file.  We might have just created it ourself,
				# or perhaps some other process created it and we got the lock
				# on it first.  Either way we go ahead and remove the file.

				$file->remove_file;
				$file->remove_path;
				}
			}
		}

	if ($ok)
		{
		# Now that everything is locked and all the old values have been
		# verified, run through and do all the updates.

		for my $key (@key_list)
			{
			my $file = $file_map->{$key};
			my $new_val = $new->{$key};

			# To force contention and strange conditions to occur more
			# frequently, the stress test program must introduce random delays
			# by setting the {delay} flag.  Otherwise things run too smoothly!
			# No other user of this module should set this flag.

			if (defined $s->{delay})
				{
				my $delay = int($s->{delay} * rand());
				for (1 .. $delay) {}  # busy loop
				}

			next if !defined $new_val;
				# Don't update if new value is undefined.

			$ok = 0 if !$file->put($new_val);
				# Write the new content.

			if ($new_val eq "")
				{
				# Remove the file if it's empty.
				$file->remove_file;
				$file->remove_path;
				}

			last if !$ok;
			}

		if (!$ok)
			{
			# This should never happen.  The best we can do is dump the old
			# and new values to STDERR so we can attempt a recovery later.
			# The caller should go into maintenance status if it sees the
			# error flag.

			$s->{error} = $!;

			print STDERR "$$ Update failed.  "
				."Possible data consistency problem.\n";

			for my $key (@key_list)
				{
				my $new_val = $new->{$key};
				my $old_val = $old->{$key};

				my $len_key = length($key);
				my $len_new_val = length($new_val);
				my $len_old_val = length($old_val);

				print STDERR "$$ [$len_key] key $key\n";
				print STDERR "$$ [$len_new_val] new $new_val\n";
				print STDERR "$$ [$len_old_val] old $old_val\n";
				}
			}
		}

	# Close any open file handles.  This would happen automatically but we
	# do it explicitly anyway.

	for my $file (@file_list)
		{
		$file->release;
		}

	return $ok;
	}

# Return the list of names in this directory, sorted alphabetically.

sub names
	{
	my $s = shift;

	my $fh;
	opendir($fh,$s->{path}) or return ();

	my @names;

	while (1)
		{
		my $file = readdir $fh;
		last if !defined $file;
		next if $file eq "." || $file eq "..";
		push @names, $file;
		}

	closedir($fh);

	return sort @names;
	}

# Return the deep list of names in this directory, sorted alphabetically.
# This recursively descends through the directory.

sub deep_names
	{
	my $s = shift;

	return () if $s->type ne "d";

	my @result;

	for my $name ($s->names)
		{
		my $child = $s->child($name);
		if ($child->type eq "d")
			{
			my @list = $child->deep_names;
			for my $path (@list)
				{
				push @result, "$name/$path";
				}
			}
		elsif ($child->type eq "f")
			{
			push @result, $child->name;
			}
		}

	return @result;
	}

# Normalize the path into a standard form for simple and reliable manipulation.

sub normalize_path
	{
	my $class = shift;
	my $path = shift;
	my $level = shift;  # optional restrict level

	return undef if !defined $path;

	$level = 1 if !defined $level || $level < 1;

	# Convert a relative path into an explicit one starting with "./".
	$path = "./$path" if $path !~ /^\//;

	# Normalize the path.
	my @path;
	for my $leg (split("/",$path))
		{
		if (@path == 0)
			{
			# Keep the first leg, which will be "." for a relative path or
			# "" for an absolute path.
			push @path, $leg;
			next;
			}

		next if $leg eq "";   # ignore null legs
		next if $leg eq ".";  # ignore "." along the way

		if ($leg eq "..")
			{
			# If we see a "..", just pop off the last leg we pushed, unless
			# it would take us outside the restricted level.

			return undef if @path <= $level;

			pop @path;
			next;
			}

		push @path, $leg;
		}

	$path = join("/",@path);
	$path = "/" if $path eq "";

	return $path;
	}

return 1;

__END__

# Copyright 2008 Patrick Chkoreff
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
