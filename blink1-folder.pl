#!/usr/bin/perl

use strict;
use warnings;

use Time::HiRes qw(usleep);
use POSIX qw(strftime);
use File::Find;

my @folders = (
	"/a/directory/to_watch"
);

my $blink1tool = "./blink1-tool";
my $error_string = "--rgb 400000";

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

set_blink_string("--off");

my @ls_last;

while (1) {
	my @ls;

	foreach my $f (@folders) {
		find({preprocess => sub {
			return grep { -f || (-d && /^[^.]/) } @_;
		}, wanted => sub {
			push @ls, $_ if (-f);
		}}, $f);
	}
	
	@ls_last = @ls if !@ls_last;
	
	foreach my $l (@ls) {
		my $is_found = 0;
		foreach my $l_last (@ls_last) {
			if ($l eq $l_last) {
				$is_found = 1;
				last;
			}
		}
		if (!$is_found) {
			my $bs = get_blink_string();
			set_blink_string("--rgb ff00ff");
			sleep(2);
			set_blink_string("--rgb $bs");
			last;
		}
	}

	@ls_last = @ls;

	sleep(90);
}
