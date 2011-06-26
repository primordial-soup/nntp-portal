package NNTP::Portal::News::Database;

=head1 NAME

NNTP::Portal::News::Database - role for implementing a DB backend

=cut

use Moose::Role;
use MooseX::Method::Signatures;
use DateTime;

=head1 DESCRIPTION

L<NNTP::Portal::News::Database> defines several that all databases must
provide for the storage of L<NNTP::Message>s.

=cut

=head2 Methods

=head3 Required methods

=over 12

=cut

=item C<init()>

called when the database is first loaded

=cut 
requires 'init';

=item C<end()>

called when the database is being closed

=cut
requires 'end';

=item C<get_message(Str $messageID)>

Returns a L<NNTP::Message> object that corresponds to the c<$messageID>.

=cut
requires 'get_message';

=item C<register_message(NNTP::Message $message, ClassName $plugin)>

Stores a message that can be retrieved later using L</get_message> along with
the plugin that produced it.

=cut
requires 'register_message';

=item C<register_newsgroup(Str $newsgroup, Str $desc, ClassName $plugin)>

Adds a newsgroup to the server along with its description and the plugin that
produced it.

=cut
requires 'register_newsgroup';

=item C<get_new_newsgroups(DateTime $time)>

Returns a list of newsgroups that are newer than a given time

=cut
requires 'get_new_newsgroups';

=item C<get_newsgroups()>

Get a hashref of all newsgroups in the form

=over 4

C<< { $newsgroup_name => $newsgroup_description } >>

=back

=cut
requires 'get_newsgroups';

=item C<get_newsgroup_desc(Str $newsgroup)>

Get description for a given newsgroup

=cut
requires 'get_newsgroup_desc';

=item C<get_newsgroup_stats(Str $newsgroup)>

Returns the count, low water mark, and high water mark of the articles for a
given group.

This returns a hashref in the form:

C<< { high => $high_water_mark, low => $low_water_mark, count => $count } >>

In the case that the given newsgroup is empty, then all of the values will be
zero.

=cut
requires 'get_newsgroup_stats';
around get_newsgroup_stats => sub {
	my $orig = shift;
	my $self = shift;

	my $hr = $self->$orig(@_);
	$hr->{$_} //= 0 for keys %$hr; # replace undef when no messages
	return $hr;
};

=item C<get_max_article_id(Str $newsgroup)>

Returns the maximum article ID for a given newsgroup

=cut
requires 'get_max_article_id';

=item C<get_plugin(Str $type, Str $value);

Returns the plugin associated with either a newsgroup or message.

Types:

=over 6

=item B<< newsgroup => $newsgroup_name >>

C<< $instance->get_plugin( newsgroup => 'comp.lang.c'); >>

=item  B<< message => $messageID >>

C<< $instance->get_plugin( message => '<abcdef1234@example>'); >>

=back

=cut
requires 'get_plugin';

=item C<get_msgid(Str $newsgroup, Str $article_id )>

Returns the C<Message-ID> corresponding to an article number or C<undef> if the
article ID is invalid.

=cut
requires 'get_msgid';

=back

=cut

=head3 Implemented methods

=over 12

=item C<get_next_article_id(Str $newsgroup)>

Returns the next article ID for a new article in a given newsgroup.

=cut
method get_next_article_id(Str $newsgroup) {
	return ($self->get_max_article_id($newsgroup) // 0) + 1;
}

=back

=cut

no Moose::Role;
1;
