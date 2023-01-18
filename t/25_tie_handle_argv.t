#!/usr/bin/env perl
use warnings;
use strict;
use warnings FATAL => qw/ io inplace /;
use File::Temp qw/tempfile/;
use POSIX qw/dup dup2/;
use Test::More tests=>2;
use Tie::Handle::Argv;

# THIS IS A BOILED DOWN VERSION OF https://github.com/haukex/File-Replace/blob/6ac1544/t/25_tie_handle_argv.t

my $testsub = sub { plan tests=>2;
	# set up temporary input files
	my @tempfiles;
	my ($fh,$fn) = tempfile(UNLINK=>1);
	print $fh "Fo\nBr";
	close $fh;
	push @tempfiles, $fn;
	($fh,$fn) = tempfile(UNLINK=>1);
	print $fh "Qz\nBz\n";
	close $fh;
	push @tempfiles, $fn;
	# run the tests
	@ARGV = @tempfiles;
	my @states;
	push @states, [[@ARGV], $ARGV, defined(fileno ARGV), $., eof];
	push @states, [[@ARGV], $ARGV, defined(fileno ARGV), $., eof, $_] while <>;
	push @states, [[@ARGV], $ARGV, defined(fileno ARGV), $., eof];
	ok !eof(), 'eof() is false';
	push @states, [[@ARGV], $ARGV, defined(fileno ARGV), $., eof];
	push @states, [[@ARGV], $ARGV, defined(fileno ARGV), $., eof, $_] while <>;
	push @states, [[@ARGV], $ARGV, defined(fileno ARGV), $., eof];
	is_deeply \@states, [
	    #                                defined(fileno ARGV)
		# @ARGV           $ARGV          |    $.     eof  readline
		[[@tempfiles],    undef,         !!0, undef, !!1           ],
		[[$tempfiles[1]], $tempfiles[0], !!1, 1,     !!0, "Fo\n"   ],
		[[$tempfiles[1]], $tempfiles[0], !!1, 2,     !!1, "Br"     ],
		[[],              $tempfiles[1], !!1, 3,     !!0, "Qz\n"   ],
		[[],              $tempfiles[1], !!1, 4,     !!1, "Bz\n"   ],
		[[],              $tempfiles[1], !!0, 4,     !!1           ],
		[[],              '-',           !!1, 0,     !!0           ],
		[[],              '-',           !!1, 1,     !!0, "Hello\n"],
		[[],              '-',           !!1, 2,     !!1, "World"  ],
		[[],              '-',           !!0, 2,     !!1           ],
	], 'states' or diag explain \@states;
};

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

# test that both regular ARGV and our tied base class act the same
{
	local (*ARGV, $.);
	my $saved_fd0 = override_stdin("Hello\nWorld");
	subtest "test with untied ARGV" => $testsub;
	restore_stdin($saved_fd0);
}
{
	local (*ARGV, $.);
	tie *ARGV, 'Tie::Handle::Argv';
	my $saved_fd0 = override_stdin("Hello\nWorld");
	subtest "test with tied ARGV" => $testsub;
	restore_stdin($saved_fd0);
	untie *ARGV;
}
