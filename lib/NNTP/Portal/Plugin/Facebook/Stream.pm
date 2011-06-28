package NNTP::Portal::Plugin::Facebook::Stream;

use Moose;
use MooseX::Method::Signatures;

use Mail::Box;
use Mail::Address;

use Text::Autoformat;
use Text::Autoformat qw/autoformat break_wrap/;

use Data::Dumper;
use DDP;

my $dt_parser = DateTime::Format::Strptime->new(
		pattern => "%FT%T%z",
		time_zone => '0',
);

method build_messages(HashRef $stream) {
	my @messages;
	my $data = $stream->{data};
	for my $post (reverse @$data) { # reversed because the data starts with the newest
		next unless $post->{type} =~ /^(status|link|video)$/;
		my @headers;

		push @headers, ( From =>
			$self->get_facebook_address( $post->{from} ) );

		my @to;
		for my $person (@{$post->{to}{data}}) {
			push @to, $self->get_facebook_address( $person );
		}
		push @headers, ( To => \@to );

		push @headers, ( 'Message-ID' => $self->get_facebook_msgid( $post->{id} ) );

		my @comment_act = grep { $_->{name} eq 'Comment' } @{$post->{actions}};
		push @headers, ( 'X-Facebook-Comment-URL' => '<'.$comment_act[0]->{link}.'>' ) if @comment_act;

		# TODO: Path: header

		# TODO: generate proper newsgroups for all categories
		my @ngs;
		push @ngs, $self->get_friend_newsgroup( $post->{from} )->{newsgroup};
		for my $person (@{$post->{to}{data}}) {
			push @ngs, $self->get_friend_newsgroup( $person )->{newsgroup};
		}

		my $time = $post->{created_time};
		my $created_dt = $dt_parser->parse_datetime( $time );

		my @body_para;
		push @body_para,  $post->{message} if defined $post->{message};
		push @body_para, "Name: $post->{name}" if defined $post->{name};
		push @body_para,  "Description:\n> $post->{description}" if defined $post->{description}; # quote description
		push @body_para, "Caption: $post->{caption}" if defined $post->{caption};
		push @body_para, "Source: <$post->{source}>" if defined $post->{source};
		push @body_para, "Link: <$post->{link}>" if defined $post->{link};

		my $body = join "\n\n", @body_para;
		my $body_format = autoformat( $body, { all => 1, break => break_wrap } );
		$body_format =~ s/\n*$//s;	# strip ending newlines
		my $top_msg = NNTP::Message->build( @headers, data => $body_format );

		$top_msg->print; print "\n---\n";

		$top_msg->set_newsgroups( \@ngs );
		$top_msg->set_datetime( $created_dt );

		push @messages, $top_msg;
	}
	return \@messages;
}

method get_friend_newsgroup(HashRef $friend_info) {
	return {
		newsgroup => "com.facebook.user.$friend_info->{id}",
		desc => "Facebook user $friend_info->{name}"
	};
}

method get_facebook_msgid( Str $id ) {
	return "<$id\@facebook.com>";
}

method get_facebook_address(HashRef $fb_info) {
	my $name = $fb_info->{name};
	my $id = $fb_info->{id};
	my $cat = $fb_info->{category} // "";
	return Mail::Address->new( $name, "$id\@facebook.com", $cat );
}

no Moose;
__PACKAGE__->meta->make_immutable;

=head1 NAME

NNTP::Portal::Plugin::Facebook::Stream

=cut
