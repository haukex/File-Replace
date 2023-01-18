#!/usr/bin/env perl
use warnings;
use strict;
use warnings FATAL => qw/ io inplace /;
use File::Temp qw/tempfile/;
use POSIX qw/dup dup2/;
use Test::More;
use Tie::Handle::Argv;

# THIS IS A BOILED DOWN VERSION OF https://github.com/haukex/File-Replace/blob/6ac1544/t/25_tie_handle_argv.t

sub override_stdin {
	my $string = shift;
	my $fh = tempfile();
	print $fh $string;
	seek $fh, 0, 0 or die "seek: $!";
	my $saved_fd0 = dup( 0 ) or die "dup(0): $!";
	dup2( fileno $fh, 0 ) or die "save dup2: $!";
	return $saved_fd0;
}
sub restore_stdin {
	my $saved_fd0 = shift;
	dup2( $saved_fd0, 0 ) or die "restore dup2: $!";
	POSIX::close( $saved_fd0 ) or die "close saved: $!";
}

{ # test regular ARGV
	local (*ARGV, $.);
	my $saved_fd0 = override_stdin("Hello\nWorld");
	
	ok !eof(), 'eof() is false';
	is scalar(<>), "Hello\n";
	is scalar(<>), "World";
	is scalar(<>), undef;
	
	restore_stdin($saved_fd0);
}

{ # test tied ARGV
	local (*ARGV, $.);
	tie *ARGV, 'Tie::Handle::Argv';
	my $saved_fd0 = override_stdin("Hello\nWorld");
	
	ok !eof(), 'eof() is false';
	is scalar(<>), "Hello\n";
	is scalar(<>), "World";
	is scalar(<>), undef;
	
	restore_stdin($saved_fd0);
	untie *ARGV;
}

done_testing;
