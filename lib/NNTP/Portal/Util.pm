package NNTP::Portal::Util;

use MooseX::Params::Validate;

=head1 NAME

NNTP::Portal::Util - implements various functions useful in other parts of the server

=cut

=head1 DESCRIPTION

=head2 Functions

=over 12

=cut

=item C<open_uri(Str $uri)>

Opens the given URI in a browser based on the platform.

=cut
sub open_uri {
	shift if $_[0] eq __PACKAGE__;
	my ($uri) = pos_validated_list( \@_, { isa => 'Str' });
	Class::MOP::load_class('HTML::Display');
	display( html => qq{ <meta http-equiv="refresh" content="0;url=$uri"> } );
}

=item C<wildmat_str(Str $wildmat)>

Returns a Perl regex as a string that represents a given WILDMAT expression.

=cut
# could be memoized (L<Memoize>)
sub wildmat_str {
	shift if $_[0] eq __PACKAGE__;
	my ($wildmat) = pos_validated_list( \@_, { isa => 'Str' });
	$wildmat =~ s/(?<!\\)\./\\./g;	# Escape '.'
	$wildmat =~ s/(?<!\\)\$/\\\$/g;	# Escape '$'
	$wildmat =~ s/(?<!\\)\?/./g;	# '?' functionality
	$wildmat =~ s/(?<!\\)\*/.*/g;	# '*' functionality
	return "^$wildmat\$";
}

=item C<wildmat_re(Str $wildmat)>

Convenience method that is the same as L</wildmat_str>, but returns a compiled
regular expression.

=cut
sub wildmat_re {
	shift if $_[0] eq __PACKAGE__;
	my $self = __PACKAGE__;
	my ($wildmat) = pos_validated_list( \@_, { isa => 'Str' });
	my $w_str = $self->wildmat_str($wildmat);
	return qr/$w_str/;
}

=back

=cut

1;
