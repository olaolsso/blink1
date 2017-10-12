#!/usr/bin/perl

use strict;
use warnings;

use Mail::IMAPClient;
use Time::HiRes qw(usleep);
use POSIX qw(strftime);

my $imap_server = "imap.gmail.com";
my $imap_port = 993;
my $imap_ssl = 1;
my $imap_user = "yourusername";
my $imap_password = "yourpassword";

my $blink1tool = "blink1-tool";
my $error_string = "--rgb 400000";

my @actions = (
	{
		"pattern" => "^from:.*do-not-reply\@stackexchange\.com",
		"action" => "--rgb 004040"
	},
	{
		"pattern" => "^(to|cc|bcc):.*yourusername\@gmail\.com",
		"action" => "--rgb 000040"
	},
	{
		"pattern" => ".*",
		"action" => "--off"
	}
);

sub dprint {
	my ($string) = @_;
	my $time = strftime("%F %T", localtime(time()));
	print("$time $0: $string\n");
}

sub get_blink_string {
	my $r = qx($blink1tool --rgbread);
	$r =~ /(0x..,0x..,0x..)$/ or die;
	return $1;
}

sub set_blink_string {
	my ($string) = @_;
	system("$blink1tool --quiet --millis 0 --nogamma $string") == 0 or die;
}

sub set_blink_error {
	set_blink_string($error_string);
}

set_blink_error();

my $imap;
my @unseen_last;

while (1) {
	# disconnect
	if ($imap && $imap->IsConnected()) {
		$imap->logout();
	}
	undef $imap;

	# connect
	my $c_connection_attempts = 0;
	until ($imap) {
		dprint("connecting");
		$imap = Mail::IMAPClient->new(
			Server => $imap_server,
			Port => $imap_port,
			SSL => $imap_ssl,
			Keepalive => 1,
			Reconnectretry => 10,
			User => $imap_user,
			Password => $imap_password) or warn;

		$c_connection_attempts++;
		if ($c_connection_attempts > 1) {
			set_blink_error();
			sleep(60);
		}
		if ($c_connection_attempts > 10) {
			sleep(20*60);
		}
	}
	$imap->select("INBOX") or warn and next;
	dprint("connected");

	# count unread
	while (1) {
		dprint("loop");

		my @unseen = $imap->unseen();

		# set colour according to unseen message classes
		if ($unseen[0]) {
			dprint("oh! something");
			my @headers = $imap->fetch(join(",", @unseen), "RFC822.HEADER") or warn and last;
			my $headers = join("", @headers);
			$headers =~ s/\r\n[ \t]/ /sg; # unfold folded header fields to single-line fields

			foreach my $a (@actions) {
				if ($headers =~ /$a->{"pattern"}/mi) {
					dprint("oh! a " + $a->{"pattern"});
					set_blink_string($a->{"action"});
					last;
				}
			}
		} else {
			dprint("nothing :-(");
			set_blink_string("--off");
		}

		# flash once for new unseen messages
		foreach my $u (@unseen) {
			my $is_in_last = 0;
			foreach my $ul (@unseen_last) {
				if ($u == $ul) {
					$is_in_last = 1;
					last;
				}
			}
			if (!$is_in_last) {
				my $bs = get_blink_string();
				set_blink_string("--rgb ffffff");
				usleep(100*1000);
				set_blink_string("--rgb $bs");
				last;
			}
		}
		@unseen_last = @unseen;

		# can't ask imap server for unseen count between idle and done calls,
		# thus race condition is possible. instead, idle_data must time out
		# periodically to verify unseen count.

		# wait for new activity
		my $idle_tag = $imap->idle() or warn and last;
		$imap->idle_data(660) or warn and last;
		$imap->done($idle_tag) or warn and last;
	}
}
