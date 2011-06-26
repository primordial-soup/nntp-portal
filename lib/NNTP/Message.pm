package NNTP::Message;

=head1 NAME

NNTP::Message - represents a Netnews message

=cut

=head1 DESCRIPTION

C<NNTP::Message> is a representation of a Netnews messages. It is an extension
L<Mail::Message> that adds fields that are specific to NNTP and methods to
easily extract these.

=cut

use Moose;
use MooseX::Method::Signatures;
use MooseX::Types::DateTime;

use DateTime;
use DateTime::Format::Mail;

use Carp;

extends 'Mail::Message';

# make clone become the subclass
override clone => sub {
	my $cloned = super();
	return __PACKAGE__->meta->rebless_instance( $cloned );
};

sub build_from_message {
	my $msg = shift;
	croak "Not a Mail::Message" unless $msg->isa('Mail::Message');
	return __PACKAGE__->meta->rebless_instance( $msg );
}

method strip_xref {
	$self->head->delete('xref');	# remove Xref, this will be calculated using the xref table
}

method set_newsgroups(ArrayRef[Str] $newsgroups) {
	my $ng_str = join ",", @$newsgroups;
	$self->head->delete( 'Newsgroups' );
	$self->head->add( Newsgroups => $ng_str );
}

method get_newsgroups {
	# comma separated
	my $group_hdr = $self->study('newsgroups')->unfoldedBody;
	my @groups = split /,/ , $group_hdr;
	# just in case
	for my $group (@groups) {
		$group =~ s/^\s+//;
		$group =~ s/\s+$//;
	}
	return \@groups;
}

method get_messageID {
	return '<'.$self->messageId.'>';
}

method get_subject {
	return $self->study('subject')->unfoldedBody;
}

method get_from {
	return $self->study('from')->unfoldedBody;
}

method get_references {
	my $ref = $self->study('references')->unfoldedBody;
	$ref =~ s/\t/ /g;
	return $ref;
}

method set_datetime(DateTime $dt) {
	$self->head->delete('Date');
	$self->head->add( Date => DateTime::Format::Mail->format_datetime( $dt ) );
}

method get_datetime {
	return DateTime->from_epoch( epoch => $self->timestamp );
}

method get_rfc2822_time {
	return DateTime::Format::Mail->format_datetime( $self->get_datetime );
}

method get_xref {
	my $xref = $self->study('xref');
	return {} unless defined $xref;
	$xref = $xref->unfoldedBody;
	$xref =~ s/^\S+ //;
	my %xref_kv = map { split ':' } split /\s+/, $xref;
	return \%xref_kv;
}

method set_xref(Str $servername, HashRef $xref) {
	my $xref_str = join ' ', map { join ":", ($_ , $xref->{$_} ) } keys %$xref;
	$self->head->delete('Xref');
	$self->head->add("Xref: $servername $xref_str");
}

method get_bytes {
	$self->size;
}

method get_lines {
	return $self->nrLines;
}

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

=head1 SEE ALSO

L<Mail::Message>,

RFC 5536: Netnews Article Format L<http://tools.ietf.org/html/rfc5536> 

=cut
