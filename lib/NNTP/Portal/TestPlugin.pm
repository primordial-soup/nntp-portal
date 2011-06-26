package NNTP::Portal::TestPlugin;
use Moose;
use MooseX::Method::Signatures;

use NNTP::Portal::Config;

has plugin => (
	is => 'rw',
	isa => 'Str',
);

method run {
	NNTP::Portal::Config->config();
	Class::MOP::load_class( $self->plugin );
	my $instance = $self->plugin()->new();
	$instance->init();
	$instance->get_messages();
	$instance->end();
}

no Moose;
__PACKAGE__->meta->make_immutable;

=head1 NAME

NNTP::Portal::TestPlugin

=cut
