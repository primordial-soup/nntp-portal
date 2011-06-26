package NNTP::Portal::News::Database::DBI;

=head1 NAME

NNTP::Portal::News::Database::DBI - role to support DB backends that use C<DBI>

=head1 DESCRIPTION

This role encapsulates the creation of a database handle

=cut

use Moose::Role;
use DBI;
use Carp;

=head2 Attributes

=over 12

=item C<dbi_dsn>

=item C<dbi_user>

=item C<dbi_auth>

=item C<dbi_attr>

=cut
has 'dbi_dsn' => (
	is => 'rw',
	isa => 'Str',
);
has 'dbi_user' => (
	is => 'rw',
	isa => 'Str',
);
has 'dbi_auth' => (
	is => 'rw',
	isa => 'Str',
);
has 'dbi_attr' => (
	is => 'rw',
	isa => 'HashRef',
);

=item C<dbh>

=cut
has dbh => (
	is => 'rw',
	#isa => 'DBI::db',
	lazy => 1,
	builder => '_build_dbh',
);

sub _build_dbh {
	my $self = shift;
	return DBI->connect($self->dbi_dsn, $self->dbi_user, $self->dbi_auth,
		$self->dbi_attr) or croak $DBI::errstr;
}

=back

=cut

with 'NNTP::Portal::News::Database';

no Moose::Role;
1;
