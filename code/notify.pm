use strict;
use file;
use sloop_top;

my $g_notify_path;

sub notify_path
	{
	if (!defined $g_notify_path)
		{
		$g_notify_path = sloop_top_path()."/data/run";
		}

	return $g_notify_path;
	}

# LATER:  not yet used, and may not want to use sendmail anyway.

sub send_email
	{
	my $from = shift;
	my $to = shift;
	my $subject = shift;
	my $message = shift;

	my $fh;

	my $str = <<EOM;
To: $to
From: $from
Subject: $subject
MIME-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Transfer-Encoding: 7bit

$message
EOM

	if (open($fh, "|/usr/sbin/sendmail -t"))
		{
		print $fh $str;
		close($fh);
		}
	else
		{
		print STDERR "sendmail $!\n";
		}
	}

sub email_notify
	{
	my $subject = shift;
	my $msg = shift;

	my $from = loom_config("notify_from");
	my $to = loom_config("notify_to");

	send_email($from, $to, $subject, $msg);
	}

sub in_maintenance_mode
	{
	my $path = notify_path();
	return -e "$path/maintenance.flag" ? 1 : 0;
	}

sub enter_maintenance_mode
	{
	my $msg = shift;
	$msg = "" if !defined $msg;

	my $path = notify_path();

	my $fh;
	if (open($fh,">$path/maintenance.flag"))
		{
		print $fh $msg;
		close($fh);
		}
	}

sub exit_maintenance_mode
	{
	my $path = notify_path();
	unlink "$path/maintenance.flag";
	}

# LATER not yet used, might want to call it from file_update in case of panic

sub fatal_error
	{
	my $msg = shift;
	my $level = shift;  # optional

	$level = 0 if !defined $level;

	my @caller = caller($level);
	my $filename = $caller[1];
	my $lineno = $caller[2];

	my $system_name = loom_config("system_name");
	my $subject = "$system_name system error";

	email_notify($subject, $msg);

	my $where = "called at $filename line $lineno";

	enter_maintenance_mode("$msg\n$where\n");

	die "$msg $where\n";

	exit(1);  # just in case
	}

return 1;
