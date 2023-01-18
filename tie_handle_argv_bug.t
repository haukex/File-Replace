#!/usr/bin/env perl
use warnings;
use strict;

{ # THIS IS A BOILED DOWN VERSION OF https://github.com/haukex/File-Replace/blob/6ac1544/lib/Tie/Handle/Argv.pm
	package Tie::Handle::Argv;

	sub TIEHANDLE {
		return bless {
			active => 0,
			innerhandle => \do{local*HANDLE;*HANDLE},
		}, shift;
	}
	sub DESTROY { delete shift->{innerhandle} }

	sub _advance {
		my ($self, $peek) = @_;
		if ( $self->{active} ) { close $self->{innerhandle} }
		else {
			die "Unexpected test state" if @ARGV;
			unshift @ARGV, '-';
		}
		if ( !@ARGV ) { # file list is now empty, closing and done
			$self->{active} = 0 unless $peek;
			return 0;
		}
		else {
			$ARGV = shift @ARGV;
			die "Unexpected test state" unless $ARGV eq '-';
			open $self->{innerhandle}, $ARGV or die $!;
			$self->{active} = 1;
			return 1;
		}
	}

	sub READLINE {
		my $self = shift;
		my @out;
		die "Unexpected test state" if wantarray;
		RL_LINE: while (1) {
			while ($self->EOF(1)) { # current file is at EOF, advance
				$self->_advance or last RL_LINE;
			}
			return scalar readline $self->{innerhandle};
		}
	}

	sub EOF {
		my $self = shift;
		if ( @_ && $_[0]==2 ) {  # we were called as "eof()" on tied ARGV
			while ( eof $self->{innerhandle} ) {  # current file is at EOF, peek
				return !!1 unless $self->_advance("peek");  # could not peek => EOF
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
