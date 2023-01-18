#!/usr/bin/env perl
use warnings;
use strict;
use warnings FATAL => qw/ io inplace /;
use File::Temp qw/tempfile/;
use Test::More tests=>2;
use Tie::Handle::Argv;

# For AUTHOR, COPYRIGHT, AND LICENSE see the bottom of this file

{
	package OverrideStdin;
	# This overrides STDIN with a file, using the same code that
	# IPC::Run3 uses, which seems to work well. Cleanup is performed
	# on object destruction.
	use File::Temp qw/tempfile/;
	use POSIX qw/dup dup2/;
	sub new {
		my ($class, $string) = @_;
		my $fh = tempfile();
		print $fh $string;
		seek $fh, 0, 0 or die "seek: $!";
		my $saved_fd0 = dup( 0 ) or die "dup(0): $!";
		dup2( fileno $fh, 0 ) or die "save dup2: $!";
		return bless \$saved_fd0, $class;
	}
	sub restore {
		my $self = shift;
		my $saved_fd0 = $$self;
		return unless defined $saved_fd0;
		dup2( $saved_fd0, 0 ) or die "restore dup2: $!";
		POSIX::close( $saved_fd0 ) or die "close saved: $!";
		$$self = undef;
	}
	sub DESTROY { return shift->restore }
}

my $testsub = sub { plan tests=>2;
	
	my @tempfiles;
	my ($fh,$fn) = tempfile(UNLINK=>1);
	print $fh "Fo\nBr";
	close $fh;
	push @tempfiles, $fn;
	($fh,$fn) = tempfile(UNLINK=>1);
	print $fh "Qz\nBz\n";
	close $fh;
	push @tempfiles, $fn;
	
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
		# @ARGV           $ARGV          |    $.     eof  $_
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

# test that both regular ARGV and our tied base class act the same
{
	local (*ARGV, $.);
	my $osi = OverrideStdin->new("Hello\nWorld");
	subtest "test with untied ARGV" => $testsub;
	$osi->restore;
}
{
	local (*ARGV, $.);
	tie *ARGV, 'Tie::Handle::Argv';
	my $osi = OverrideStdin->new("Hello\nWorld");
	subtest "test with tied ARGV" => $testsub;
	$osi->restore;
	untie *ARGV;
}

__END__

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
