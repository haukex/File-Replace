#!/usr/bin/env perl
use warnings;
use strict;

=head1 Synopsis

Tests for the Perl module File::Replace::Inplace.

Actually, these are tests for Perl's C<-i> switch, so that I can
compare their results to my tests for the module.

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

use Test::More tests=>10;

use Cwd qw/getcwd/;
use File::Temp qw/tempdir/;

use warnings FATAL => 'inplace';
my $FE = $] lt '5.012' ? !!1 : !!0; # FE="first eof", see http://rt.perl.org/Public/Bug/Display.html?id=133721

subtest 'basic test' => sub {
	local (*ARGV, *ARGVOUT, $.); # so their scope is limited to the test
	my @tf = (newtempfn("Foo\nBar"), newtempfn("Quz\nBaz\n"));
	local @ARGV = @tf;
	my @states;
	{
		local $^I = '';
		# WARNING: eof() modifies $ARGV (and potentially others), so don't do [$ARGV, $., eof, eof()]!!
		# See e.g. https://www.perlmonks.org/?node_id=289044 and https://www.perlmonks.org/?node_id=1076954
		# and https://www.perlmonks.org/?node_id=1164369 and probably more
		is select(), 'main::STDOUT', 'STDOUT is selected initially';
		ok !defined(fileno ARGV), 'ARGV closed initially';
		ok !defined(fileno ARGVOUT), 'ARGVOUT closed initially';
		push @states, [$ARGV, $., eof], eof();
		ok  defined(fileno ARGV), 'ARGV open'; # opened by eof()
		ok  defined(fileno ARGVOUT), 'ARGVOUT open'; # opened by eof()
		while (<>) {
			print "$ARGV:$.: ".uc;
			ok  defined(fileno ARGV), 'ARGV still open';
			ok  defined(fileno ARGVOUT), 'ARGVOUT still open';
			push @states, [$ARGV, $., eof], eof();
		}
		is select(), 'main::STDOUT', 'STDOUT is selected again';
		ok !defined(fileno ARGV), 'ARGV closed again';
		ok !defined(fileno ARGVOUT), 'ARGVOUT closed again';
		push @states, [$ARGV, $., eof]; # another call to eof() would open and try to read STDIN
	}
	is @ARGV, 0, '@ARGV empty';
	is slurp($tf[0]), "$tf[0]:1: FOO\n$tf[0]:2: BAR", 'file 1 contents';
	is slurp($tf[1]), "$tf[1]:3: QUZ\n$tf[1]:4: BAZ\n", 'file 2 contents';
	is_deeply \@states, [
		[undef, undef, $FE], !!0,    [$tf[0], 1, !!0], !!0,
		[$tf[0], 2, !!1], !!0,       [$tf[1], 3, !!0], !!0,
		[$tf[1], 4, !!1], !!1,       [$tf[1], 4, !!1],
	], 'states' or diag explain \@states;
};

subtest 'backup' => sub {
	local (*ARGV, *ARGVOUT, $.);
	my $tfn = newtempfn("Foo\nBar");
	my $bfn = $tfn.'.bak';
	{
		ok !-e $bfn, 'backup file doesn\'t exist yet';
		local ($^I,@ARGV) = ('.bak',$tfn);
		is select(), 'main::STDOUT', 'STDOUT is selected initially';
		is eof, $FE, 'eof before';
		is eof(), !!0, 'eof() before';
		print "$ARGV+$.+$_" while <>;
		is select(), 'main::STDOUT', 'STDOUT is selected again';
		is eof, !!1, 'eof after';
	}
	is $., 2, '$. correct';
	is slurp($tfn), "$tfn+1+Foo\n$tfn+2+Bar", 'file edited correctly';
	is slurp($bfn), "Foo\nBar", 'backup file correct';
};

subtest 'readline contexts' => sub { # we test scalar everywhere, need to test the others too
	local (*ARGV, *ARGVOUT, $.);
	my @tf = (newtempfn("So"), newtempfn("Many\nTests\nis"), newtempfn("fun\n!!!"));
	my @states;
	{
		local ($^I,@ARGV) = ('',@tf);
		is select(), 'main::STDOUT', 'STDOUT is selected initially';
		push @states, [$ARGV, $., eof], eof();
		for (1..2) {
			push @states, [$ARGV, $., eof], eof();
			<>;
			push @states, [$ARGV, $., eof], eof();
		}
		print "Hi?\n";
		my @got = <>;
		is select(), 'main::STDOUT', 'STDOUT is selected again';
		push @states, [$ARGV, $., eof];
		is_deeply \@got, ["Tests\n","is","fun\n","!!!"], 'list ctx' or diag explain \@got;
	}
	is slurp($tf[0]), "", 'file 1 correct';
	is slurp($tf[1]), "Hi?\n", 'file 2 correct';
	is slurp($tf[2]), "", 'file 3 correct';
	is_deeply \@states, [
		[undef, undef, $FE], !!0,    [$tf[0], 0, !!0], !!0,
		[$tf[0], 1, !!1], !!0,       [$tf[1], 1, !!0], !!0,
		[$tf[1], 2, !!0], !!0,       [$tf[2], 6, !!1],
	], 'states' or diag explain \@states;
};

subtest 'restart' => sub {
	local (*ARGV, *ARGVOUT, $.);
	my $tfn = newtempfn("111\n222\n333\n");
	local @ARGV = ($tfn);
	my @states;
	{
		local $^I = '';
		is select(), 'main::STDOUT', 'STDOUT is selected initially';
		push @states, [$ARGV, $., eof], eof();
		while (<>) {
			print "X/$.:$_";
			push @states, [$ARGV, $., eof], eof();
		}
		is select(), 'main::STDOUT', 'STDOUT is selected in between';
		@ARGV = ($tfn);  ## no critic (RequireLocalizedPunctuationVars)
		while (<>) {
			print "Y/$.:$_";
			push @states, [$ARGV, $., eof], eof();
		}
		is select(), 'main::STDOUT', 'STDOUT is selected again';
		push @states, [$ARGV, $., eof];
	}
	is slurp($tfn), "Y/1:X/1:111\nY/2:X/2:222\nY/3:X/3:333\n", 'file correct';
	is_deeply \@states, [
		[undef, undef, $FE], !!0,    [$tfn, 1, !!0], !!0,
		[$tfn, 2, !!0], !!0,         [$tfn, 3, !!1], !!1,
		[$tfn, 1, !!0], !!0,         [$tfn, 2, !!0], !!0,
		[$tfn, 3, !!1], !!1,         [$tfn, 3, !!1],
	], 'states' or diag explain \@states;
};

subtest 'reset $. on eof' => sub {
	local (*ARGV, *ARGVOUT, $.);
	my @tf = (newtempfn("One\nTwo\nThree\n"), newtempfn("Four\nFive\nSix"));
	local @ARGV = @tf;
	my @states;
	{
		local $^I = '';
		is select(), 'main::STDOUT', 'STDOUT is selected initially';
		push @states, [$ARGV, $., eof], eof();
		while (<>) {
			print "($.)$_";
			push @states, [$ARGV, $., eof];
		}
		# as documented in eof, this should reset $. per file
		# apparently, this means we can't use eof() here because it tries to read STDIN,
		# I haven't yet wrapped my head around why that is (TODO Later)
		continue {
			close ARGV if eof;
			push @states, [$ARGV, $., eof];
		}
		@ARGV = ($tf[0]);  ## no critic (RequireLocalizedPunctuationVars)
		while (<>) {
			print "[$.]$_";
			push @states, [$ARGV, $., eof];
		}
		continue {
			close ARGV if eof;
			push @states, [$ARGV, $., eof];
		}
		is select(), 'main::STDOUT', 'STDOUT is selected again';
		push @states, [$ARGV, $., eof];
	}
	is slurp($tf[0]), "[1](1)One\n[2](2)Two\n[3](3)Three\n", 'file 1 correct';
	is slurp($tf[1]), "(1)Four\n(2)Five\n(3)Six", 'file 2 correct';
	is_deeply \@states, [
		[undef, undef, $FE], !!0,
		[$tf[0], 1, !!0],    [$tf[0], 1, !!0],
		[$tf[0], 2, !!0],    [$tf[0], 2, !!0],
		[$tf[0], 3, !!1],    [$tf[0], 0, !!1],
		[$tf[1], 1, !!0],    [$tf[1], 1, !!0],
		[$tf[1], 2, !!0],    [$tf[1], 2, !!0],
		[$tf[1], 3, !!1],    [$tf[1], 0, !!1],
		[$tf[0], 1, !!0],    [$tf[0], 1, !!0],
		[$tf[0], 2, !!0],    [$tf[0], 2, !!0],
		[$tf[0], 3, !!1],    [$tf[0], 0, !!1],
		[$tf[0], 0, !!1],
	], 'states' or diag explain \@states;
};

subtest 'restart with emptied @ARGV' => sub {
	local (*ARGV, *ARGVOUT, $.);
	my @tf = (newtempfn("Foo\nBar"), newtempfn("Quz\nBaz\n"));
	my @out;
	my @states;
	{
		my $stdin = OverrideStdin->new("Hello\nWorld");
		local ($^I, @ARGV) = ('', @tf);
		is select(), 'main::STDOUT', 'STDOUT is selected initially';
		push @states, [$ARGV, $., eof], eof();
		while (<>) {
			print "$ARGV:$.: ".uc;
			push @states, [$ARGV, $., eof], eof();
		}
		is select(), 'main::STDOUT', 'STDOUT is selected in between';
		while (<>) {
			push @out, "2/$ARGV:$.: ".uc;
			push @states, [$ARGV, $., eof], eof();
		}
		is select(), 'main::STDOUT', 'STDOUT is selected again';
		push @states, [$ARGV, $., eof];
	}
	is_deeply \@out, ["2/-:1: HELLO\n", "2/-:2: WORLD"], 'stdin/out looks ok';
	is slurp($tf[0]), "$tf[0]:1: FOO\n$tf[0]:2: BAR", 'file 1 correct';
	is slurp($tf[1]), "$tf[1]:3: QUZ\n$tf[1]:4: BAZ\n", 'file 2 correct';
	is_deeply \@states, [
		[undef, undef, $FE], !!0,    [$tf[0], 1, !!0], !!0,
		[$tf[0], 2, !!1], !!0,       [$tf[1], 3, !!0], !!0,
		[$tf[1], 4, !!1], !!1,       ['-',    1, !!0], !!0,
		['-',    2, !!1], !!1,       ['-',    2, !!1],
	], 'states' or diag explain \@states;
};

subtest 'initially empty @ARGV' => sub {
	local (*ARGV, *ARGVOUT, $.);
	my @out;
	my @states;
	{
		my $stdin = OverrideStdin->new("BlaH\nBlaHHH");
		local $^I = '';
		is select(), 'main::STDOUT', 'STDOUT is selected initially';
		push @states, [$ARGV, $., eof], eof();
		while (<>) {
			push @out, "+$ARGV:$.:".lc;
			push @states, [$ARGV, $., eof], eof();
		}
		is select(), 'main::STDOUT', 'STDOUT is selected again';
		push @states, [$ARGV, $., eof];
	}
	is_deeply \@out, ["+-:1:blah\n", "+-:2:blahhh"], 'stdin/out looks ok';
	is_deeply \@states, [
		[undef, undef, $FE], !!0,    ['-', 1, !!0], !!0,
		['-', 2, !!1], !!1,          ['-', 2, !!1],
	], 'states' or diag explain \@states;
};

subtest 'nonexistent files' => sub {
	my @tf;
	use warnings NONFATAL => 'inplace';
	local $SIG{__WARN__} = sub { $_[0]=~/\bCan't open (?:\Q$tf[0]\E|\Q$tf[1]\E): / or die @_ };
	my %codes = (
		scalar => sub {
			local ($^I,@ARGV) = ('',@tf);
			is_deeply [$ARGV, $., eof], [undef, undef, $FE], 'state 1';
			is eof(), !!0, 'eof() 1';
			is <>, 'Hullo', 'read 1';
			print "World\n";
			is_deeply [$ARGV, $., eof], [$tf[2], 1, !!1], 'state 2';
			is eof(), !!1, 'eof() 2';
			is <>, undef, 'read 2';
			is_deeply [$ARGV, $., eof], [$tf[2], 1, !!1], 'state 3';
		},
		list => sub {
			local ($^I,@ARGV) = ('',@tf);
			is_deeply [$ARGV, $., eof], [undef, undef, $FE], 'state 1';
			is eof(), !!0, 'eof() before';
			is_deeply [<>], ["Hullo"], 'readline return correct';
			is_deeply [$ARGV, $., eof], [$tf[2], 1, !!1], 'state 2';
		},
	);
	plan tests => scalar keys %codes;
	for my $k (sort keys %codes) {
		subtest $k => sub {
			local (*ARGV, *ARGVOUT, $.);
			@tf = (newtempfn, newtempfn, newtempfn("Hullo"));
			ok !-e $tf[0], 'file 1 doesn\'t exist yet';
			ok !-e $tf[1], 'file 2 doesn\'t exist yet';
			ok -e $tf[2], 'file 3 already exists';
			is select(), 'main::STDOUT', 'STDOUT is selected initially';
			$codes{$k}->();
			is select(), 'main::STDOUT', 'STDOUT is selected again';
			ok !-e $tf[0], 'file 1 doesn\'t exist';
			ok !-e $tf[1], 'file 2 doesn\'t exist';
			is slurp($tf[2]), $k eq 'scalar' ? "World\n" : "", 'file 3 contents ok';
		};
	}
};

subtest 'empty files' => sub {
	local (*ARGV, *ARGVOUT, $.);
	my @tf = (newtempfn(""), newtempfn("Hello"), newtempfn(""), newtempfn, newtempfn("World!\nFoo!"));
	local @ARGV = @tf;
	my @states;
	{
		use warnings NONFATAL => 'inplace';
		local $SIG{__WARN__} = sub { $_[0]=~/\bCan't open \Q$tf[3]\E\b/ or die @_ };
		local $^I = '';
		is select(), 'main::STDOUT', 'STDOUT is selected initially';
		push @states, [$ARGV, $., eof], eof();
		while (<>) {
			print "$ARGV($.) ".uc;
			push @states, [$ARGV, $., eof], eof();
		}
		is select(), 'main::STDOUT', 'STDOUT is selected again';
		push @states, [$ARGV, $., eof];
	}
	is @ARGV, 0, '@ARGV empty';
	is slurp($tf[0]), "", 'file 1 contents';
	is slurp($tf[1]), "$tf[1](1) HELLO", 'file 2 contents';
	is slurp($tf[2]), "", 'file 3 contents';
	ok !-e $tf[3], 'file 4 doesn\'t exist';
	is slurp($tf[4]), "$tf[4](2) WORLD!\n$tf[4](3) FOO!", 'file 5 contents';
	is_deeply \@states, [
		[undef, undef, $FE], !!0,    [$tf[1], 1, !!1], !!0,
		[$tf[4], 2, !!0], !!0,       [$tf[4], 3, !!1], !!1,
		[$tf[4], 3, !!1],
	], 'states' or diag explain \@states;
};

subtest 'various file names' => sub {
	plan skip_all => 'need Perl >=5.22 for double-diamond' if $] lt '5.022';
	my $prevdir = getcwd;
	my $tmpdir = tempdir(DIR=>$TEMPDIR,CLEANUP=>1);
	chdir($tmpdir) or die "chdir $tmpdir: $!";
	#TODO: why doesn't this work? spew("-","sttdddiiiinnnnn hello\nxyz\n");
	spew("echo|","piipppeee world\naa bb cc");
	local @ARGV = ("echo|");
	my $code = q{  # need to eval this because otherwise <<>> is a syntax error on older Perls
		local $^I='';
		while (<<>>) {
			chomp;
			print join(",", map {ucfirst} split), "\n";
		}
	; 1 };
	eval $code or die $@||"unknown error";
	#is slurp("-"), "Sttdddiiiinnnnn,Hello\nXyz\n", 'file 1 correct';
	is slurp("echo|"), "Piipppeee,World\nAa,Bb,Cc\n", 'file 2 correct';
	chdir($prevdir) or warn "chdir $prevdir: $!";
};

