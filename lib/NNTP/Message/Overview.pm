package NNTP::Message::Overview;
use strict;
use warnings;

=head1 NAME

NNTP::Message::Overview - helper functions to generate output for the C<OVER>
command.

=cut

use Carp;

=head1 DESCRIPTION

Functions that can help the NNTP server implement the C<OVER> capability.

=cut

=head2 Functions

=over 12

=cut

=item C<over_line(Array[Str] fields)>

Returns a line suitable for a single response to C<OVER>

From RFC 3977:

=over 4

   The first 8 fields MUST be the following, in order:

      "0" or article number (see below)
      Subject header content
      From header content
      Date header content
      Message-ID header content
      References header content
      :bytes metadata item
      :lines metadata item

=back

The fields input into this function should already be unfolded.

=cut
sub over_line {
	shift if $_[0] eq __PACKAGE__;
	@_ = @{$_[0]} if ref $_[0] eq 'ARRAY';
	my @fields;
	while (@_) {
		my $field = shift;
		$field = '' unless defined $field;
		$field =~ s/\t/ /g;
		push @fields, $field;
	}
	
	return join "\t", @fields;
}

=item C<get_msg_required>

Returns the 2nd to 8th fields of an overview response (i.e. C<Subject:> to
C<:lines>) as a list.

=cut
sub get_msg_required {
	shift if $_[0] eq __PACKAGE__;
	my $msg = shift;
	croak "Argument is not an NNTP::Message" unless $msg->isa('NNTP::Message');
	return ( $msg->get_subject, $msg->get_from, $msg->get_rfc2822_time,
		$msg->get_messageID, $msg->get_references, $msg->get_bytes );
}

=back

=cut

1;
