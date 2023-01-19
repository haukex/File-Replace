#!/usr/bin/env perl
use warnings;
use strict;

# Code for https://github.com/Perl/perl5/issues/20207

{
	# THIS IS A BOILED DOWN VERSION OF https://github.com/haukex/File-Replace/blob/6ac1544/lib/Tie/Handle/Argv.pm
	# This class is designed to mimic the behavior of the real ARGV,
	# and extensive testing shows that it does work in Perls 5.16 and up.
	# The following code has been extensively reduced to only the code
	# necessary to reproduce the test failures that started showing up
	# in Perl 5.37.4.
	package Tie::Handle::Argv;
	
	sub TIEHANDLE {
		return bless { active => 0,
				innerhandle => \do{local*HANDLE;*HANDLE},
			}, shift;
	}
	sub DESTROY { delete shift->{innerhandle} }
	
	sub _advance {
		my ($self, $peek) = @_;
		if ( $self->{active} ) {
			close $self->{innerhandle};
			$self->{active} = 0 unless $peek;
			return 0;
		}
		else {
			die "Unexpected test state" if @ARGV;
			$ARGV = '-';
			open $self->{innerhandle}, $ARGV or die $!;
			$self->{active} = 1;
			return 1;
		}
	}
	
	sub READLINE {
		my $self = shift;
		my @out;
		die "Unexpected test state" if wantarray;
		while ($self->EOF(1)) { # current file is at EOF, advance
			if ( not $self->_advance ) { return }
		}
		return scalar readline $self->{innerhandle};
	}
	
	sub EOF {
		my $self = shift;
		if ( @_ && $_[0]==2 ) {  # we were called as "eof()" on tied ARGV
			while ( eof $self->{innerhandle} ) {  # current file is at EOF, peek
				if ( not $self->_advance("peek") ) { return !!1 }  # could not peek => EOF
			}
			return !!0;  # not at EOF
		}
		return eof $self->{innerhandle};
	}
}

# THIS IS A BOILED DOWN VERSION OF https://github.com/haukex/File-Replace/blob/6ac1544/t/25_tie_handle_argv.t
use warnings FATAL => qw/ io inplace /;
use File::Temp qw/tempfile/;
use POSIX qw/dup dup2/;
use Test::More;

# using an overridden STDIN appears important to reproduce failure
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
	STDIN->clearerr;
}

{ # test regular ARGV to confirm its behavior matches the tied ARGV
	local (*ARGV, $.);
	my $saved_fd0 = override_stdin("Hello");
	
	ok !eof(), 'eof() is false';
	is scalar(<>), "Hello";
	is scalar(<>), undef;
	
	restore_stdin($saved_fd0);
}

{ # test tied ARGV
	local (*ARGV, $.);
	tie *ARGV, 'Tie::Handle::Argv';
	my $saved_fd0 = override_stdin("Hello");
	
	ok !eof(), 'eof() is false';
	is scalar(<>), "Hello";
	is scalar(<>), undef;
	
	restore_stdin($saved_fd0);
	untie *ARGV;
}

done_testing;
