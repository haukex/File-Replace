#!perl
package Tie::Handle::Argv;
use warnings;
use strict;

# THIS IS A BOILED DOWN VERSION OF https://github.com/haukex/File-Replace/blob/6ac1544/lib/Tie/Handle/Argv.pm

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

1;
