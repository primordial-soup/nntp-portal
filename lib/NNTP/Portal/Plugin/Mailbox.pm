package NNTP::Portal::Plugin::Mailbox;
use Moose;

# TODO: open mailbox,
#
# construct with a Mail::Message proxy based on whether message contains a
# Newsgroups: field

#my $mgr    = Mail::Box::Manager->new;
#my $folder = $mgr->open(folder => $news_dir);
#
#for my $msg ($folder->messages) {
#        register_message($msg);
#}
#
#$folder->close(write => 'NEVER');

with 'NNTP::Portal::Plugin';

no Moose;
__PACKAGE__->meta->make_immutable;

=head1 NAME

NNTP::Portal::Plugin::Mailbox

=cut
