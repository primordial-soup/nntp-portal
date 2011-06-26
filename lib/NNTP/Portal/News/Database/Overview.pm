package NNTP::Portal::News::Database::Overview;

=head1 NAME

NNTP::Portal::News::Database::Overview - role to support NNTP overview
capability

=cut

use Moose::Role;
use MooseX::Method::Signatures;

=head1 DESCRIPTION

=over 12

=cut

=item C<get_overview_fmt()>

Returns a list of all the fields listed in C<LIST OVERVIEW.FMT>.

=cut
method get_overview_fmt {
	return ( $self->get_overview_fmt_required, $self->get_overview_fmt_extra );
}

=item C<get_overview_fmt_required()>

Returns a list containing the required response to C<LIST OVERVIEW.FMT>

=cut
# see <url:find:rfc3977.txt#line=4495>
method get_overview_fmt_required {
	return wantarray ? @{$self->overview_required} : $self->overview_required;
}

=item C<get_overview_fmt_extra()>

Returns a list of the extra fields supported for C<LIST OVERVIEW.FMT>

=cut
method get_overview_fmt_extra {
	return wantarray ? () : [];
}

=item C<get_overview(Str $msgID, Maybe[Str] $current_newsgroup?)>

Returns a list of all overview data for the C<OVER> command.

The current newsgroup is needed to calculate the article ID.

B<required>

=cut
requires 'get_overview';

=back

=cut

has overview_required => (
	is => 'ro',
	isa => 'ArrayRef',
	default => sub {
		return [
			"Subject:",
			"From:",
			"Date:",
			"Message-ID:",
			"References:",
			":bytes",	# "Bytes:"
			":lines",	# "Lines:"
		];
	}
);

# just in case to prevent VERY bad things from happening
before register_message => sub {
	my ($self, $msg ) = @_;
	$msg->strip_xref;
};

with 'NNTP::Portal::News::Database';

no Moose::Role;
1;
