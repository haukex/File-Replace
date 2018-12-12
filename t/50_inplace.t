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

subtest 'readline contexts' => sub { # we test scalar everywhere, need to test the others too
	my @tmpfiles = (newtempfn("So"), newtempfn("Many\nTests\nis"), newtempfn("fun\n!!!"));
	{
		my $inpl = inplace( files=>[@tmpfiles] );
		<>;
		<>;
		print "Hi?\n";
		my @got = <>;
		is_deeply \@got, ["Tests\n","is","fun\n","!!!"], 'list ctx' or diag explain \@got;
	}
	is slurp($tmpfiles[0]), "", 'file 1 correct';
	is slurp($tmpfiles[1]), "Hi?\n", 'file 2 correct';
	is slurp($tmpfiles[2]), "", 'file 3 correct';
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

subtest '-i in import list' => sub {
	my @tmpfiles = (newtempfn("XX\nYY\n"), newtempfn("ABC\nDEF\nGHI"));
	local @ARGV = @tmpfiles;
	local $ARGV = "foobar";
	my $oldargvout = \*ARGVOUT;
	my $oldargv = \*ARGV;
	File::Replace->import('-i');
	while (<>) {
		print "$ARGV:$.:".lc;
	}
	is slurp($tmpfiles[0]), "$tmpfiles[0]:1:xx\n$tmpfiles[0]:2:yy\n", 'file 1 correct';
	is slurp($tmpfiles[1]), "$tmpfiles[1]:3:abc\n$tmpfiles[1]:4:def\n$tmpfiles[1]:5:ghi", 'file 2 correct';
	$File::Replace::GlobalInplace = undef;  ## no critic (ProhibitPackageVars)
	is @ARGV, 0, '@ARGV empty';
	is $ARGV, 'foobar', '$ARGV restored';
	is \*ARGVOUT, $oldargvout, '$ARGVOUT restored';
	is \*ARGV, $oldargv, '$ARGV restored';
	# a couple more checks for code coverage
	File::Replace->import('-D');
	is undef, $File::Replace::GlobalInplace, 'debug flag only has no effect';  ## no critic (ProhibitPackageVars)
	like exception {File::Replace->import('-i','-D','-i.bak')},
		qr/\bmore than one -i\b/, 'multiple -i\'s fails'
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

subtest 'cleanup' => sub { # mostly just to make code coverage happy
	my $tmpfile = newtempfn("Yay\nHooray");
	{
		my $inpl = inplace( files=>[$tmpfile] );
		print "<$.>$_" while <>;
		$inpl->cleanup;
		tie *ARGV, 'Tie::Handle::Base';
		$inpl->{old_argv} = undef;
		$inpl->{old_argvout} = undef;
		$inpl->cleanup;
		untie *ARGV;
	}
	is slurp($tmpfile), "<1>Yay\n<2>Hooray", 'file correct';
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
	tie *STDIN, 'Tie::Handle::MockStdin', "Hello\n", "World";
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
	untie *STDIN;
	is_deeply \@out, ["2/-:1: HELLO\n", "2/-:2: WORLD"], 'stdin/out looks ok';
	is slurp($tmpfiles[0]), "$tmpfiles[0]:1: FOO\n$tmpfiles[0]:2: BAR", 'file 1 correct';
	is slurp($tmpfiles[1]), "$tmpfiles[1]:3: QUZ\n$tmpfiles[1]:4: BAZ\n", 'file 2 correct';
};
subtest 'initially empty @ARGV' => sub {
	tie *STDIN, 'Tie::Handle::MockStdin', "Blah\n", "Blahhh";
	my @out;
	local @ARGV = ();
	{
		my $inpl = File::Replace::Inplace->new();
		while (<>) {
			push @out, "+$ARGV:$.:".lc;
		}
	}
	untie *STDIN;
	is_deeply \@out, ["+-:1:blah\n", "+-:2:blahhh"], 'stdin/out looks ok';
};

subtest 'debug' => sub {
	note "Expect some debug output here:";
	my $db = Test::More->builder->output;
	ok( do { my $x=File::Replace::Inplace->new(debug=>$db); 1 }, 'debug w/ handle' );
	local *STDERR = $db;
	ok( do { my $x=File::Replace::Inplace->new(debug=>1); 1 }, 'debug w/o handle' );
};

subtest 'misc failures' => sub {
	like exception { inplace(); 1 },
		qr/\bUseless use of .*->new in void context\b/, 'inplace in void ctx';
	like exception { my $x=inplace('foo') },
		qr/\bnew: bad number of args\b/, 'bad nr of args 1';
	like exception { File::Replace::Inplace::TiedArgv::TIEHANDLE() },
		qr/\bTIEHANDLE: bad number of args\b/, 'bad nr of args 2';
	like exception { File::Replace::Inplace::TiedArgv::TIEHANDLE('x','y') },
		qr/\bTIEHANDLE: bad number of args\b/, 'bad nr of args 3';
	like exception { my $x=inplace(badarg=>1) },
		qr/\bunknown option\b/, 'unknown arg';
	like exception { my $x=inplace(files=>"foo") },
		qr/\bmust be an arrayref\b/, 'bad file arg';
	like exception {
			my $i = inplace();
			open ARGV, '<', newtempfn or die $!;  ## no critic (ProhibitBarewordFileHandles)
			close ARGV;
		}, qr/\bCan't reopen ARGV while tied\b/i, 'reopen ARGV';
};

#TODO: Test that @ARGV containing "-" accesses a file literally named "-" (also document!)

done_testing;
