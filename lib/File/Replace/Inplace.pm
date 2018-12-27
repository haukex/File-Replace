#!perl
package File::Replace::Inplace;
use warnings;
use strict;
use Carp;

# For AUTHOR, COPYRIGHT, AND LICENSE see the bottom of this file

our $VERSION = '0.09';

our @CARP_NOT = qw/ File::Replace /;

sub new {  ## no critic (RequireArgUnpacking)
	my $class = shift;
	croak "Useless use of $class->new in void context" unless defined wantarray;
	croak "$class->new: bad number of args" if @_%2;
	my %args = @_; # just so we can extract the debug option
	my $self = {};
	$self->{debug} = \*STDERR if $args{debug} && !ref($args{debug});
	tie *ARGV, 'File::Replace::Inplace::TiedArgv', @_;
	bless $self, $class;
	$self->_debug("$class->new: tied ARGV\n");
	return $self;
}
*_debug = \&File::Replace::_debug;
sub cleanup {
	my $self = shift;
	if ( defined( my $tied = tied(*ARGV) ) ) {
		if ( $tied->isa('File::Replace::Inplace::TiedArgv') ) {
			$self->_debug(ref($self)."->cleanup: untieing ARGV\n");
			untie *ARGV;
		}
	;}
	delete $self->{debug};
	return 1;
}
sub DESTROY { return shift->cleanup }

{
	## no critic (ProhibitMultiplePackages)
	package # hide from pause
		File::Replace::Inplace::TiedArgv;
	use Carp;
	use File::Replace;
	
	BEGIN {
		require Tie::Handle::Argv;
		our @ISA = qw/ Tie::Handle::Argv /;  ## no critic (ProhibitExplicitISA)
	}
	
	# this is mostly the same as %NEW_KNOWN_OPTS from File::Replace,
	# except without "in_fh" (note "debug" is also passed to the superclass)
	my %TIEHANDLE_KNOWN_OPTS = map {$_=>1} qw/ debug layers create chmod
		perms autocancel autofinish backup /;
	
	sub TIEHANDLE {  ## no critic (RequireArgUnpacking)
		croak __PACKAGE__."->TIEHANDLE: bad number of args" unless @_ && @_%2;
		my ($class,%args) = @_;
		for (keys %args) { croak "$class->new: unknown option '$_'"
			unless $TIEHANDLE_KNOWN_OPTS{$_} }
		my $self = $class->SUPER::TIEHANDLE( debug => $args{debug} );
		$self->{repl_opts} = \%args;
		return $self;
	}
	
	sub OPEN {
		my $self = shift;
		croak "bad number of arguments to open" if @_<1||@_>2;
		my ($mode,$filename) = Tie::Handle::Base::open_parse(@_);
		$mode =~ /^\s*<\s*(:\w.*)?$/ or croak "unuspported mode '$mode'";
		my %opts;
		$opts{layers} = $1 if $1;
		if ($filename eq '-') {
			$self->_debug(ref($self).": Reading from STDIN, writing to STDOUT");
			$self->set_inner_handle(*STDIN);
			binmode STDIN, $opts{layers} if $opts{layers};
			*ARGVOUT = *STDOUT{IO};  ## no critic (RequireLocalizedPunctuationVars)
		}
		else {
			$self->{repl} = File::Replace->new($filename, %{$self->{repl_opts}}, %opts );
			$self->set_inner_handle($self->{repl}->in_fh);
			*ARGVOUT = $self->{repl}->out_fh;  ## no critic (RequireLocalizedPunctuationVars)
		}
		select(ARGVOUT);  ## no critic (ProhibitOneArgSelect)
	}
	
	sub inner_close {
		my $self = shift;
		if ( $self->{repl} ) {
			$self->{repl}->finish;
			$self->{repl} = undef;
		}
		return 1;
	}
	
	sub sequence_end {
		my $self = shift;
		select(STDOUT);  ## no critic (ProhibitOneArgSelect)
	}
	
	sub UNTIE {
		my $self = shift;
		delete $self->{$_} for grep {!/^_/} keys %$self;
		return $self->SUPER::UNTIE(@_);
	}
	
	sub DESTROY {
		my $self = shift;
		# File::Replace destructor will warn on unclosed file
		delete $self->{$_} for grep {!/^_/} keys %$self;
		return $self->SUPER::DESTROY(@_);
	}
	
}

1;
__END__

=head1 Name

Tie::Handle::Inplace - Emulation of Perl's C<-i> switch via L<File::Replace|File::Replace>

=head1 Synopsis

 TODO Doc: Synopsis

=head1 Description

TODO Doc: Description

This documentation describes version 0.09 of this module.
B<This is a development version.>

=head2 Differences to Perl's C<-i>

=over

=item *

Files are always opened with the three-argument C<open>, meaning that things
like piped C<open>s won't work. In that way, this module works more like
Perl's newer double-diamond C<<< <<>> >>> operator. This means, for example,
that if C<@ARGV> contains C<"<foo">, then instead of C<STDIN>, a file literally
named F<< <foo >> will be opened, instead of a file F<foo>.

=for comment
TODO: test the above statement

=item *

Problems like not being able to open a file would normally only cause a warning
when using Perl's C<-i> option, in this module it depends on the setting of
the C<create> option, see L<File::Replace/create>.

=item *

See the documentation of the C<backup> option at L<File::Replace/backup>
for differences to Perl's C<-i>.

=back

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
