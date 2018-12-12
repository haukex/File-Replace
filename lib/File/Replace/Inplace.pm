#!perl
package File::Replace::Inplace;
use warnings;
use strict;
use Carp;
use warnings::register;

# For AUTHOR, COPYRIGHT, AND LICENSE see the bottom of this file

our $VERSION = '0.09';

sub new {  ## no critic (RequireArgUnpacking)
	my $class = shift;
	croak "Useless use of $class->new in void context" unless defined wantarray;
	my $self = {
		old_argv    => *ARGV{IO},
		old_argvout => *ARGVOUT{IO},
		old_argv_s  => $ARGV,
	};
	my %args = @_; # just so we can extract the debug option
	$self->{debug} = \*STDERR if $args{debug} && !ref($args{debug});
	tie *ARGV, 'File::Replace::Inplace::TiedArgv', @_;
	return bless $self, $class;
}

sub cleanup {
	my $self = shift;
	$self->_debug(ref($self).": cleaning up, restoring previous ARGV* variables");
	if ( defined( my $tied = tied(*ARGV) ) )
		{ untie *ARGV if $tied->isa('File::Replace::Inplace::TiedArgv') }
	# want to avoid "Undefined value assigned to typeglob" warnings here
	if (exists $self->{old_argv}) {
		*ARGV = $self->{old_argv} if defined($self->{old_argv});  ## no critic (RequireLocalizedPunctuationVars)
		delete $self->{old_argv};
	}
	if (exists $self->{old_argvout}) {
		*ARGVOUT = $self->{old_argvout} if defined($self->{old_argvout});  ## no critic (RequireLocalizedPunctuationVars)
		delete $self->{old_argvout};
	}
	exists $self->{old_argv_s} and $ARGV = delete $self->{old_argv_s};  ## no critic (RequireLocalizedPunctuationVars)
	delete $self->{debug};
	return 1;
}
sub DESTROY { return shift->cleanup }

sub _debug {  ## no critic (RequireArgUnpacking)
	my $self = shift;
	return 1 unless $self->{debug};
	local ($",$,,$\) = (' ');
	return print {$self->{debug}} @_;
}

{
	## no critic (ProhibitMultiplePackages)
	package # hide from pause
		File::Replace::Inplace::TiedArgv;
	use Carp;
	use warnings::register;
	use File::Replace;
	
	BEGIN {
		require Tie::Handle::Base;
		our @ISA = qw/ Tie::Handle::Base /;  ## no critic (ProhibitExplicitISA)
	}
	
	# this is mostly the same as %NEW_KNOWN_OPTS from File::Replace,
	# except without "in_fh", and with this class's "files" option
	my %TIEHANDLE_KNOWN_OPTS = map {$_=>1} qw/ debug layers create chmod
		perms autocancel autofinish backup files /;
	
	sub TIEHANDLE {  ## no critic (RequireArgUnpacking)
		croak __PACKAGE__."->TIEHANDLE: bad number of args" unless @_ && @_%2;
		my ($class,%args) = @_;
		for (keys %args) { croak "$class->new: unknown option '$_'"
			unless $TIEHANDLE_KNOWN_OPTS{$_} }
		croak "$class->new: option 'files' must be an arrayref"
			if exists $args{files} && ref $args{files} ne 'ARRAY';
		my $self = $class->SUPER::TIEHANDLE();
		$self->{debug} = \*STDERR if $args{debug} && !ref($args{debug});
		$self->{firstline} = 1; # the very first line (for resetting $.)
		$self->{starting} = 1; # for both starting and re-starting the loop over @ARGV
		$self->{argv} = exists $args{files} ? delete $args{files} : \@ARGV;
		$self->{repl_opts} = \%args;
		return $self;
	}
	
	our $_READLINE_RECURSEOK = 1;
	
	sub READLINE {
		my $self = shift;
		if ($self->{firstline}) { $.=0; $self->{firstline}=0 }  ## no critic (RequireLocalizedPunctuationVars)
		if ( $self->EOF ) {
			$self->{prev_linenum} = $.; # save state because closing the filehandle (->finish) resets $.
			if ($self->{repl}) {
				$self->{repl}->finish;
				$self->{repl} = undef;
			}
			# we've reached the end of our @ARGV list, reset state
			if ( !@{$self->{argv}} && !$self->{starting} ) {
				select(STDOUT);  ## no critic (ProhibitOneArgSelect)
				$self->{starting} = 1;
				$self->{firstline} = 1;
				return;
			} # else
			$self->{starting} = 0;
			if (@{$self->{argv}}) {
				$ARGV = shift @{$self->{argv}};  ## no critic (RequireLocalizedPunctuationVars)
				$self->{repl} = File::Replace->new($ARGV, %{$self->{repl_opts}} );
				$self->set_inner_handle($self->{repl}->in_fh);
				*ARGVOUT = $self->{repl}->out_fh;  ## no critic (RequireLocalizedPunctuationVars)
			}
			else { # we were called with an initially empty @ARGV
				$self->_debug(ref($self).": Reading from STDIN, writing to STDOUT");
				$ARGV = '-';  ## no critic (RequireLocalizedPunctuationVars)
				$self->set_inner_handle(*STDIN);
				*ARGVOUT = *STDOUT{IO};  ## no critic (RequireLocalizedPunctuationVars)
			}
			select(ARGVOUT);  ## no critic (ProhibitOneArgSelect)
		}
		if (wantarray) {
			my @rv = $self->SUPER::READLINE(@_);
			$. += delete $self->{prev_linenum} if $self->{prev_linenum};
			# loop over all remaining files by calling ourself again
			if ( $_READLINE_RECURSEOK ) {
				local $_READLINE_RECURSEOK = 0;
				while ( my @more = $self->READLINE(@_) )
					{ push @rv, @more }
			}
			return @rv;
		}
		elsif (defined wantarray) {
			my $rv = $self->SUPER::READLINE(@_);
			$. += delete $self->{prev_linenum} if $self->{prev_linenum};
			return $rv;
		}
		else {
			$self->SUPER::READLINE(@_);
			$. += delete $self->{prev_linenum} if $self->{prev_linenum};
			return;
		}
	}
	
	sub OPEN { croak "Can't reopen ARGV while tied to ".ref($_[0]) }  ## no critic (RequireArgUnpacking)
	
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
	
	*_debug = \&File::Replace::Inplace::_debug;  ## no critic (ProtectPrivateVars)
	
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
Perl's newer double-diamond C<<< <<>> >>> operator.

=item *

Problems like not being able to open a file would only cause a warning with
Perl's C<-i> option, this module is more strict and will C<die> if there
are problems.

=item *

See the documentation of the C<backup> option at L<File::Replace/backup>
for differences there.

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
