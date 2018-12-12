#!/usr/bin/env perl
use warnings;
use strict;

=head1 Synopsis

Tests for the Perl module File::Replace::Inplace.

=head1 Author, Copyright, and License

Copyright (c) 2018 Hauke Daempfling (haukex@zero-g.net)
at the Leibniz Institute of Freshwater Ecology and Inland Fisheries (IGB),
Berlin, Germany, L<http://www.igb-berlin.de/>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see L<http://www.gnu.org/licenses/>.

=cut

use FindBin ();
use lib $FindBin::Bin;
use File_Replace_Testlib;

use Test::More; #TODO Later: tests=>1;

use File::Spec::Functions qw/catdir/;
use IPC::Run3::Shell 0.56 ':FATAL', [ perl => { fail_on_stderr=>1,
	show_cmd=>Test::More->builder->output },
	$^X, '-wMstrict', '-I'.catdir($FindBin::Bin,'..','lib') ];

## no critic (RequireCarping)

BEGIN {
	use_ok 'File::Replace::Inplace';
	use_ok 'File::Replace', 'inplace';
}

subtest 'basic test' => sub {
	my @tmpfiles = (newtempfn("Foo\nBar"), newtempfn("Quz\nBaz\n"));
	local @ARGV = @tmpfiles;
	local $ARGV = "foobar";
	my $oldargvout = \*ARGVOUT;
	my $oldargv = \*ARGV;
	{
		my $inpl = File::Replace::Inplace->new();
		while (<>) {
			print "$ARGV:$.: ".uc;
		}
	}
	is slurp($tmpfiles[0]), "$tmpfiles[0]:1: FOO\n$tmpfiles[0]:2: BAR", 'file 1 correct';
	is slurp($tmpfiles[1]), "$tmpfiles[1]:3: QUZ\n$tmpfiles[1]:4: BAZ\n", 'file 2 correct';
	is @ARGV, 0, '@ARGV empty';
	is $ARGV, 'foobar', '$ARGV restored';
	is \*ARGVOUT, $oldargvout, '$ARGVOUT restored';
	is \*ARGV, $oldargv, '$ARGV restored';
};

subtest 'inplace()' => sub {
	my @tmpfiles = (newtempfn("X\nY\nZ"), newtempfn("AA\nBB\nCC\n"));
	my @files = @tmpfiles;
	local @ARGV = ('foo','bar');
	{
		my $inpl = inplace( files=>\@files );
		print "$ARGV:$.:$_" while <>;
	}
	is_deeply \@ARGV, ['foo','bar'], '@ARGV unaffected';
	is @files, 0, '@files was emptied';
	is slurp($tmpfiles[0]), "$tmpfiles[0]:1:X\n$tmpfiles[0]:2:Y\n$tmpfiles[0]:3:Z", 'file 1 correct';
	is slurp($tmpfiles[1]), "$tmpfiles[1]:4:AA\n$tmpfiles[1]:5:BB\n$tmpfiles[1]:6:CC\n", 'file 2 correct';
};

subtest 'backup' => sub {
	my $tfn = newtempfn("Foo\nBar");
	my $bfn = $tfn.'.bak';
	{
		ok !-e $bfn, 'backup file doesn\'t exist yet';
		my $inpl = File::Replace::Inplace->new( files=>[$tfn], backup=>'.bak' );
		print "$ARGV+$.+$_" while <>;
	}
	is slurp($tfn), "$tfn+1+Foo\n$tfn+2+Bar", 'file edited correctly';
	is slurp($bfn), "Foo\nBar", 'backup file correct';
};

subtest 'cmdline' => sub {
	my @tmpfiles = (newtempfn("One\nTwo\n"), newtempfn("Three\nFour"));
	is perl('-MFile::Replace=-i','-pe','s/[aeiou]/_/gi', @tmpfiles), '', 'no output';
	is slurp($tmpfiles[0]), "_n_\nTw_\n", 'file 1 correct';
	is slurp($tmpfiles[1]), "Thr__\nF__r", 'file 2 correct';
	my @bakfiles = map { "$_.bak" } @tmpfiles;
	ok !-e $bakfiles[0], 'backup 1 doesn\'t exist';
	ok !-e $bakfiles[1], 'backup 2 doesn\'t exist';
	is perl('-MFile::Replace=-i.bak','-nle','print "$ARGV:$.: $_"', @tmpfiles), '', 'no output (2)';
	is slurp($tmpfiles[0]), "$tmpfiles[0]:1: _n_\n$tmpfiles[0]:2: Tw_\n", 'file 1 correct (2)';
	is slurp($tmpfiles[1]), "$tmpfiles[1]:3: Thr__\n$tmpfiles[1]:4: F__r\n", 'file 2 correct (2)';
	is slurp($bakfiles[0]), "_n_\nTw_\n", 'backup file 1 correct';
	is slurp($bakfiles[1]), "Thr__\nF__r", 'backup file 2 correct';
};

subtest 'restart' => sub {
	my $tfn = newtempfn("111\n222\n333\n");
	local @ARGV = ($tfn);
	{
		my $inpl = File::Replace::Inplace->new();
		while (<>) {
			print "X/$.:$_";
		}
		@ARGV = ($tfn);  ## no critic (RequireLocalizedPunctuationVars)
		while (<>) {
			print "Y/$.:$_";
		}
	}
	is slurp($tfn), "Y/1:X/1:111\nY/2:X/2:222\nY/3:X/3:333\n", 'output ok';
};

subtest 'reset $. on eof' => sub {
	my @tmpfiles = (newtempfn("One\nTwo\nThree\n"), newtempfn("Four\nFive\nSix"));
	local @ARGV = @tmpfiles;
	{
		my $inpl = File::Replace::Inplace->new();
		while (<>) {
			print "($.)$_";
		}
		# as documented in eof, this should reset $. per file
		continue { close ARGV if eof }
		@ARGV = ($tmpfiles[0]);  ## no critic (RequireLocalizedPunctuationVars)
		while (<>) {
			print "[$.]$_";
		}
		continue { close ARGV if eof }
	}
	is slurp($tmpfiles[0]), "[1](1)One\n[2](2)Two\n[3](3)Three\n", 'file 1 correct';
	is slurp($tmpfiles[1]), "(1)Four\n(2)Five\n(3)Six", 'file 2 correct';
};

subtest 'restart with emptied @ARGV' => sub {
	my @tmpfiles = (newtempfn("Foo\nBar"), newtempfn("Quz\nBaz\n"));
	if (0) { # this turns out to not really be portable, can probably be removed
		my $stdin = newtempfn("Hello\nWorld");
		open my $oldin, "<&", \*STDIN or die "Can't dup STDIN: $!";  ## no critic (RequireBriefOpen)
		open STDIN, '<', $stdin or die "Can't open STDIN: $!";
		my @out;
		{
			my $inpl = File::Replace::Inplace->new( files=>[@tmpfiles] );
			while (<>) {
				print "$ARGV:$.: ".uc;
			}
			while (<>) {
				push @out, "2/$ARGV:$.: ".uc;
			}
		}
		close STDIN;
		open STDIN, "<&", $oldin or die "Can't restore STDIN: $!";
		is_deeply \@out, ["2/-:1: HELLO\n", "2/-:2: WORLD"], 'stdin/out looks ok';
	}
	else {
		is perl('-MFile::Replace=-i','-e',
			q{ print "$ARGV:$.: ".uc while <>; print STDERR "2/$ARGV:$.: ".uc while <> },
			@tmpfiles, { fail_on_stderr=>0, stdin=>\"Hello\nWorld",
				stderr=>\(my $stderr) } ), '', 'no output';
		#TODO Later: Figure out why $. is broken here on 5.8.x
		my $expect = $] lt '5.010' ? "2/-:0: HELLO\n2/-:0: WORLD" # this is a workaround!
			: "2/-:1: HELLO\n2/-:2: WORLD"; # this is what we would actually expect
		is $stderr, $expect, 'stderr looks ok';
	}
	is slurp($tmpfiles[0]), "$tmpfiles[0]:1: FOO\n$tmpfiles[0]:2: BAR", 'file 1 correct';
	is slurp($tmpfiles[1]), "$tmpfiles[1]:3: QUZ\n$tmpfiles[1]:4: BAZ\n", 'file 2 correct';
};
subtest 'initially empty @ARGV' => sub {
	if (0) { # this turns out to not really be portable, can probably be removed
		my $stdin = newtempfn("Blah\nBlahhh");
		open my $oldin, "<&", \*STDIN or die "Can't dup STDIN: $!";  ## no critic (RequireBriefOpen)
		open STDIN, '<', $stdin or die "Can't open STDIN: $!";
		my @out;
		local @ARGV = ();
		{
			my $inpl = File::Replace::Inplace->new();
			while (<>) {
				push @out, "+$ARGV:$.:".lc;
			}
		}
		close STDIN;
		open STDIN, "<&", $oldin or die "Can't restore STDIN: $!";
		is_deeply \@out, ["+-:1:blah\n", "+-:2:blahhh"], 'stdin/out looks ok';
	}
	else {
		is perl('-MFile::Replace=-i','-e',
			q{ print STDERR "+$ARGV:$.:".lc while <> },
			{ fail_on_stderr=>0, stdin=>\"Blah\nBlahhh",
				stderr=>\(my $stderr) } ), '', 'no output';
		#TODO Later: Figure out why $. is broken here on 5.8.x
		my $expect = $] lt '5.010' ? "+-:0:blah\n+-:0:blahhh" # this is a workaround!
			: "+-:1:blah\n+-:2:blahhh"; # this is what we would actually expect
		is $stderr, $expect, 'stderr looks ok';
	}
};

#TODO: Tests for:
# - @ARGV containing "-" (shouldn't work)

done_testing;
