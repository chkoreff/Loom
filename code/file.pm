package file;
use strict;
use Fcntl qw(:DEFAULT :flock);

# Robust concurrent file operations

# Create a new file object with the given path.  Initially, this object simply
# holds the path for future reference -- no files are opened or created right
# away.  In effect, the object is a reference to an arbitrary file which could
# be a text file, a directory, or not even exist yet.
#
# The $level is an optional level which restricts operations to within a
# specific directory.  Normally this is passed in from the "child" operation.

sub new
	{
	my $path = shift;
	my $level = shift;  # optional restrict level

	$path = path_normalize($path,$level);
	return undef if !defined $path;

	my $file = {};
	$file->{fh} = undef;
	$file->{path} = $path;
	$file->{mode} = "";
	$file->{level} = $level;
	return $file;
	}

# Normalize the path into a standard form for simple and reliable manipulation.

sub path_normalize
	{
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

# Return the full path of this object.

sub full_path
	{
	my $file = shift;

	return $file->{path};
	}

# Return the path of this object relative to its restricted context.

sub local_path
	{
	my $file = shift;
	return "" if !defined $file;

	my @path = split("/",$file->{path});
	my $level = $file->{level};
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
	my $file = shift;

	my @path = split("/",local_path($file));
	return undef if @path == 0;
	return $path[$#path];
	}

# Return the type of this file object.  The result is "f" for a text file,
# "d" for a directory, or "" (null) if the file does not exist.

sub type
	{
	my $file = shift;

	return "" if !defined $file;
	return "f" if -f $file->{path};
	return "d" if -d _;
	return "";
	}

# Return the size in bytes of this file.  This does return a number for a
# directory as well, though that may not be useful.

sub size
	{
	my $file = shift;

	return -s $file->{path};
	}

# Restrict all operations to this directory, never allowing any "child"
# operation to stray outside it.

sub restrict
	{
	my $dir = shift;

	my @path = split("/",$dir->{path});
	$dir->{level} = scalar(@path);
	return $dir;
	}

# Return the child with the given path relative to this directory.

sub child
	{
	my $dir = shift;
	my $path = shift;

	$path = "" if !defined $path;
	die if !defined $dir->{path};
	return new("$dir->{path}/$path",$dir->{level});
	}

# Return the parent of this file, or undef if we're at the top level and thus
# no parent exists.

sub parent
	{
	my $file = shift;

	return child($file,"..");
	}

# Release (close) this file if open.

sub release
	{
	my $file = shift;

	return 0 if $file->{mode} eq "";
	return 0 if !defined $file->{fh};

	close($file->{fh});
	$file->{fh} = undef;
	$file->{mode} = "";

	return 1;
	}

# Create a text file here.  Return true if the file did not exist and was
# successfully created.

sub create_text
	{
	my $file = shift;

	return 0 if $file->{mode} ne "";  # already open
	return 0 if type($file) ne "";    # already exists

	if (!defined $file->{fh} && !sysopen($file->{fh},$file->{path},O_CREAT))
		{
		$file->{fh} = undef;
		return 0;
		}

	$file->{mode} = "R";
	release($file);

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

sub remove_text
	{
	my $file = shift;

	return unlink($file->{path});
	}

# Create a directory here.  Return true if the directory did not exist and was
# successfully created.

sub create_dir
	{
	my $dir = shift;

	return mkdir($dir->{path});
	}

# Return the list of names in this directory, sorted alphabetically.

sub names
	{
	my $dir = shift;

	my $fh;
	opendir($fh,$dir->{path}) or return ();

	my @names;

	while (1)
		{
		my $name = readdir $fh;
		last if !defined $name;
		next if $name eq "." || $name eq "..";
		push @names, $name;
		}

	closedir($fh);

	return sort @names;
	}

# Return the deep list of names in this directory, sorted alphabetically.
# This recursively descends through the directory.

sub deep_names
	{
	my $dir = shift;

	return () if type($dir) ne "d";

	my @result;

	for my $name (names($dir))
		{
		my $child = child($dir,$name);
		if (type($child) eq "d")
			{
			my @list = deep_names($child);
			for my $path (@list)
				{
				push @result, "$name/$path";
				}
			}
		elsif (type($child) eq "f")
			{
			push @result, name($child);
			}
		}

	return @result;
	}

# Remove the directory here.  Return true if the directory did exist and was
# successfully removed.  Note that the directory can only be removed if it is
# empty.

sub remove_dir
	{
	my $dir = shift;

	return rmdir($dir->{path});
	}

# Remove the entire directory tree here.
sub remove_tree
	{
	my $dir = shift;

	return 0 if !defined $dir;
	my $type = type($dir);

	return remove_text($dir) if $type eq "f" || -l $dir->{path};
		# If it's a symlink just unlink it, don't delete the whole tree.

	return 0 if $type ne "d";
	remove_children($dir);
	return remove_dir($dir);
	}

# Remove all the children of this directory.

sub remove_children
	{
	my $dir = shift;

	for my $name (names($dir))
		{
		remove_tree(child($dir,$name));
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
#
# LATER 20130830 This is not a portable way to move files to other directories.
sub rename
	{
	my $file = shift;
	my $path = shift;

	release($file);
	rename $file->{path}, $path;
	}

# Create the enclosing path to this object.  This creates any directories which
# lead to this object.

sub create_path
	{
	my $file = shift;

	my $parent = parent($file);
	return 1 if !defined $parent;

	my $type = type($parent);
	return 1 if $type eq "d";
	return 0 if $type eq "f";

	return 0 if !create_path($parent);
	return create_dir($parent);
	}

# Remove the enclosing path to this object, as far up the tree as possible.
# This removes any empty directories which lead to this object.

sub remove_path
	{
	my $file = shift;

	my $parent = parent($file);
	return 1 if !defined $parent;

	return 0 if !remove_dir($parent);
	return remove_path($parent);
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
	my $file = shift;

	my $fh = $file->{fh};
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

# Open this file for read access with a shared lock.  Returns true if it got
# the lock on a normal attached file.  See is_detached for a discussion of
# attached and detached files.

sub open_read
	{
	my $file = shift;
	my $blocking = shift;  # optional, default 1

	return 1 if $file->{mode} eq "R";
	return 0 if $file->{mode} ne "";

	if (!defined $file->{fh} && !sysopen($file->{fh},$file->{path},O_RDONLY))
		{
		$file->{fh} = undef;
		return 0;
		}

	$blocking = 1 if !defined $blocking;

	my $locked = $blocking
		? flock($file->{fh}, LOCK_SH)
		: flock($file->{fh}, LOCK_SH|LOCK_NB);

	return 0 if !$locked;

	if (is_detached($file))
		{
		release($file);
		return 0;
		}

	$file->{mode} = "R";
	return 1;
	}

# Open this file for write access with an exclusive lock.  Returns true if it
# got the lock on a normal attached file.  See is_detached for a discussion of
# attached and detached files.

sub open_write
	{
	my $file = shift;
	my $blocking = shift;  # optional, default 1

	return 1 if $file->{mode} eq "W";
	return 0 if $file->{mode} ne "";

	if (!defined $file->{fh} && !sysopen($file->{fh},$file->{path},O_RDWR))
		{
		$file->{fh} = undef;
		return 0;
		}

	$blocking = 1 if !defined $blocking;

	my $locked = $blocking
		? flock($file->{fh}, LOCK_EX)
		: flock($file->{fh}, LOCK_EX|LOCK_NB);

	return 0 if !$locked;

	if (is_detached($file))
		{
		release($file);
		return 0;
		}

	$file->{mode} = "W";

	return 1;
	}

# Read the next line from the open file.

sub get_line
	{
	my $file = shift;

	return undef if $file->{mode} eq "";
	return undef if !defined $file->{fh};

	my $fh = $file->{fh};
	my $line = <$fh>;
	return $line;
	}

# Read a specific number of bytes from the open file if possible.

sub get_bytes
	{
	my $file = shift;
	my $num_bytes = shift;

	return undef if !defined $num_bytes;

	return undef if $file->{mode} eq "";
	return undef if !defined $file->{fh};

	my $data;
	my $len = read($file->{fh},$data,$num_bytes);

	return $data;
	}

# Get the entire content of the file.

sub get_content
	{
	my $file = shift;

	open_read($file);

	return undef if $file->{mode} eq "";
	return undef if !defined $file->{fh};

	seek($file->{fh}, 0, 0);

	my $text = "";
	my $pos = 0;
	while (1)
		{
		my $num_read = read($file->{fh},$text,16384,$pos);
		if (!defined $num_read)
			{
			next if $! =~ /^Interrupted/;
			return undef;
			}
		last if $num_read == 0;
		$pos += $num_read;
		}

	return $text;
	}

# Get the entire content of a named file in the given directory.

sub get_by_name
	{
	my $dir = shift;
	my $name = shift;

	my $file = child($dir,$name);
	return "" if !defined $file;

	my $val = get_content($file);
	release($file);

	return "" if !defined $val;
	return $val;
	}

# Write the bytes to the open file at the current position.

sub put_bytes
	{
	my $file = shift;
	my $text = shift;

	return 0 if $file->{mode} ne "W";
	return 0 if !defined $file->{fh};

	my $pos = 0;
	my $len = length($text);
	while (1)
		{
		last if $len == 0;
		my $num_written = syswrite($file->{fh},$text,$len,$pos);
		if (!defined $num_written)
			{
			return 0;
			}
		$len -= $num_written;
		$pos += $num_written;
		}

	return 1;
	}

# Replace the entire content of the file.

sub put_content
	{
	my $file = shift;
	my $text = shift;

	open_write($file);

	return 0 if $file->{mode} ne "W";
	return 0 if !defined $file->{fh};

	seek($file->{fh}, 0, 0);
	truncate($file->{fh}, 0);

	return put_bytes($file,$text);
	}

# Put the entire content of a named file in the given directory.

sub put_by_name
	{
	my $dir = shift;
	my $name = shift;
	my $text = shift;

	return update($dir, {$name,$text}, {});
	}

# Append the text to the open file.

sub append
	{
	my $file = shift;
	my $text = shift;

	return 0 if $file->{mode} ne "W";
	return 0 if !defined $file->{fh};

	seek($file->{fh}, 0, 2);

	return put_bytes($file,$text);
	}

# Atomic parallel update routine.
#
# This routine updates a set of files underneath the given directory $dir.
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

# To force contention and strange conditions to occur more frequently, the
# stress test program must introduce random delays by setting this delay flag.
# Otherwise things run too smoothly!  No other user of this module should set
# this flag.

my $g_test_delay;

sub set_test_delay
	{
	$g_test_delay = shift;
	}

sub update
	{
	my $dir = shift;
	my $new = shift;
	my $old = shift;

	die if !defined $dir;
	die if !defined $new;
	die if !defined $old;

	my @key_list = keys %$new;

	# Guard against opening too many files.
	my $num_files = scalar(@key_list);
	die "Too many files ($num_files)"
		if $num_files > 800;  # Arbitrary maximum.

	my $ok = 1;

	my $file_map = {};  # map from key (name) to file object
	my @file_list;      # list of file objects to update

	for my $key (@key_list)
		{
		my $file = child($dir,$key);
		if (!defined $file)
			{
			# Tried to venture outside of restricted directory scope.
			$ok = 0;
			last;
			}

		# Try to create the file in case it doesn't already exist.  Otherwise
		# we won't be able to lock it.

		create_path($file);
		create_text($file);

		$file_map->{$key} = $file;
		push @file_list, $file;
		}

	if ($ok)
		{
		# Sort files with Schwartzian transform.

		@file_list =
			map { $_->[0] }
			sort { $a->[1] cmp $b->[1] }
			map { [$_, full_path($_) ] }
			@file_list;

		# Lock the files in order.

		for my $file (@file_list)
			{
			next if open_write($file);

			# Some possible errors here:
			#   Inappropriate ioctl for device
			#   Too many open files
			#   No such file or directory

			# LATER I notice that "Inappropriate ioctl for device" is very
			# common in the test_file run.

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

			my $curr_val = get_content($file);
			next if defined $curr_val && $curr_val eq $old_val;

			$ok = 0;   # something didn't match!

			if (defined $curr_val && $curr_val eq "")
				{
				# It's an empty file.  We might have just created it ourself,
				# or perhaps some other process created it and we got the lock
				# on it first.  Either way we go ahead and remove the file.

				remove_text($file);
				remove_path($file);
				}
			}
		}
	else
		{
		# We failed to open all the files for writing.  Clean up any zero-
		# length files we might have created.

		for my $key (@key_list)
			{
			my $file = $file_map->{$key};

			my $size = size($file);
			$size = 0 if !defined $size;

			if ($file->{mode} eq "W" && $size == 0)
				{
				remove_text($file);
				remove_path($file);
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

			# Do a busy loop if a test program has set a delay.
			if (defined $g_test_delay)
				{
				my $delay = int($g_test_delay * rand());
				for (1 .. $delay) {}  # busy loop
				}

			next if !defined $new_val;
				# Don't update if new value is undefined.

			$ok = 0 if !put_content($file,$new_val);
				# Write the new content.

			if ($new_val eq "")
				{
				# Remove the file if it's empty.
				remove_text($file);
				remove_path($file);
				}

			last if !$ok;
			}

		if (!$ok)
			{
			# This should never happen.  The best we can do is dump the old
			# and new values to STDERR so we can attempt a recovery later.
			# The caller should go into maintenance status if it sees the
			# error flag.
			#
			# LATER Call a function which sets global maintenance status so
			# all processes halt.

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
			die;
			}
		}

	# Close any open file handles.  This would happen automatically but we
	# do it explicitly anyway.

	for my $file (@file_list)
		{
		release($file);
		}

	return $ok;
	}

return 1;
