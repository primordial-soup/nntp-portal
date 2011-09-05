package NNTP::Portal::Plugin::Facebook::Stream;

use Moose;
use MooseX::Method::Signatures;

use Mail::Box;
use Mail::Address;

use Lingua::Sentence;

use Data::Dumper;
use DDP;

my $dt_parser = DateTime::Format::Strptime->new(
		pattern => "%FT%T%z",
		time_zone => '0',
);

my $splitter = Lingua::Sentence->new('en');

method build_messages(HashRef $stream) {
	my @messages;
	my $data = $stream->{data};
	for my $post (reverse @$data) { # reversed because the data starts with the newest
		next unless $post->{type} =~ /^(status|link|video)$/;
		my @headers;

		my $subject_gen = 0;

		push @headers, ( From =>
			$self->get_facebook_address( $post->{from} ) );

		my @to;
		my @ngs;
		# TODO: generate proper newsgroups for all categories
		push @ngs, $self->get_friend_newsgroup( $post->{from} )->{newsgroup};
		for my $person (@{$post->{to}{data}}) {
			next unless defined $person;
			push @to, $self->get_facebook_address( $person );
			push @ngs, $self->get_friend_newsgroup( $person )->{newsgroup};
		}
		push @headers, ( To => \@to );

		push @headers, ( 'Message-ID' => $self->get_facebook_msgid( $post->{id} ) );

		my @comment_act = grep { $_->{name} eq 'Comment' } @{$post->{actions}};
		push @headers, ( 'X-Facebook-Comment-URL' => '<'.$comment_act[0]->{link}.'>' ) if @comment_act;

		push @headers, ( 'X-Facebook-Type' => $post->{type} ); # TODO: different type if it is a comment

		if( defined $post->{application} ) {
			push @headers, ( 'X-Facebook-Application-Name' => $post->{application}{name} );
			push @headers, ( 'X-Facebook-Application-URL' =>
				"http://www.facebook.com/apps/application.php?id=$post->{application}{id}" );
			if( $post->{application}{name} eq 'Questions' ) {
				( my  $qid = $post->{id} ) =~ s/.*_//;
				push @headers, ( 'X-Facebook-Question-URL' => "http://www.facebook.com/home.php?sk=question&id=$qid" );
			}
		}

		my $subject_string = "\u$post->{type}: ";
		if( defined $post->{name} && length $post->{name} > 0 ) {
			$subject_string .= $post->{name};
		} elsif( defined $post->{caption} && length $post->{caption} > 0 ) {
			$subject_string .= $post->{caption};
		} elsif( defined $post->{message} && length $post->{message} > 0 ) {
			my @sentences = $splitter->split_array($post->{message});
			my @subject;
			my $subject_length = 0;
			while(@sentences && $subject_length < 120) {
				my $next_sent = shift @sentences;
				$subject_length += length $next_sent;
				push @subject, $next_sent;
			}
			$subject_string .= join ' ', @subject;
		}
		push @headers, ( Subject => $subject_string );

		# TODO: Path: header

		my $time = $post->{created_time};
		my $created_dt = $dt_parser->parse_datetime( $time );

		my @body_para;
		push @body_para,  $post->{message} if defined $post->{message};
		push @body_para, "Name: $post->{name}" if defined $post->{name};
		push @body_para,  "Description:\n> $post->{description}" if defined $post->{description}; # quote description
		push @body_para, "Caption: $post->{caption}" if defined $post->{caption};
		push @body_para, "Source: <$post->{source}>" if defined $post->{source};
		push @body_para, "Link: <$post->{link}>" if defined $post->{link};

		for my $prop (@{ $post->{properties} }) {
			my @prop_build;
			push @prop_build, "$prop->{name}:"  if defined $prop->{name};
			push @prop_build, $prop->{text}     if defined $prop->{text};
			push @prop_build, "<$prop->{href}>" if defined $prop->{href};
			push @body_para, (join ' ', @prop_build);
		}

		my $body = join "\n\n", @body_para;
		$body =~ s/\n*$//s;	# strip ending newlines
		my $top_msg = NNTP::Message->build( @headers, data => $body );

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
