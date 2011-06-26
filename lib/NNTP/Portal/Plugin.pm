package NNTP::Portal::Plugin;
use Moose::Role;

has db => (
	is => 'rw',
	isa => 'NNTP::Portal::News::Database',
);

requires 'init';
requires 'end';

requires 'get_newsgroups';
requires 'get_messages';

no Moose::Role;
1;
=head1 NAME

NNTP::Portal::Plugin

=cut
