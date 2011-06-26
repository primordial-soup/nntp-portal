package NNTP::Portal::Plugin::Facebook;

=head1 NAME

NNTP::Portal::Plugin::Facebook - plugin for accessing Facebook

=cut

use Moose;
use MooseX::Method::Signatures;

use Facebook::Graph;	# Graph API

use NNTP::Portal::Plugin::Facebook::Stream;

use File::Spec;
use File::Path qw(make_path);
use YAML::XS qw/LoadFile DumpFile/;

#use WWW::Mechanize;	# loaded dynamically

use DDP;

use NNTP::Portal::Config;

use constant {
	App_ID => '169523049775172',
	API_Key => '8d3c97c8658c86853b0c4e3e99a9b98e',
	App_secret => '58af880d7c89ff30401d50f0e6e83fc9',
};

has client => (
	is => 'ro',
	isa => 'Facebook::Graph',
	default => sub {
		Facebook::Graph->new(
			app_id    => App_ID,
			secret    => App_secret,
			postback  => 'https://www.facebook.com/connect/login_success.html',
		);
	}
);

has token => (
	is => 'rw',
	lazy => 1,
	default => sub {
		my $self = shift;
		$self->get_config_access_token();
	}
);

method init {
	my $client = $self->client();
	my $token = $self->token or
		die("Access token not configured! Please run facebook_authorize.\n");
	$client->access_token($token);

	#my $facebook_profile = $client->query
		#->find('zmughal')
		##->include_metadata
		#->request
		#->as_hashref;
}

method end {
}

method get_newsgroups {
	my $client = $self->client;

	my $me = $client->fetch('me');
	my $my_ng = $self->get_my_news_newsgroup($me);
	$self->db->register_newsgroup( $my_ng->{newsgroup} , $my_ng->{desc} , __PACKAGE__);

	my $friends = $client->fetch('me/friends')->{data};
	push @$friends, $me;	# include the user
	my $stream_helper = NNTP::Portal::Plugin::Facebook::Stream->new();
	for my $friend (@$friends) {
		my $ng_info = $stream_helper->get_friend_newsgroup($friend);
		$self->db->register_newsgroup($ng_info->{newsgroup}, $ng_info->{desc},
			__PACKAGE__ );
	}
}

method get_my_news_newsgroup(HashRef $me) {
	return { newsgroup => "com.facebook.user.$me->{id}.news",
		desc => "News feed for $me->{name}" };
}

method get_messages {
	my $client = $self->client;

	my $me = $client->fetch('me');
	my $my_ng = $self->get_my_news_newsgroup($me);

	my $stream = $client->query
		->from('my_news')
		#->limit(25)
		->request->as_hashref;
	#p $stream;

	my $stream_help = NNTP::Portal::Plugin::Facebook::Stream->new();
	for my $paging (0..4) {
		my $messages = $stream_help->build_messages( $stream );
		for my $msg (@$messages) {
			my $ngs = $msg->get_newsgroups;
			push @$ngs, $my_ng->{newsgroup};
			# TODO: add a method to easily add and remove a
			# newsgroup from a L<NNTP::Message>
			$msg->set_newsgroups($ngs);
			$self->{db}->register_message($msg, __PACKAGE__);
		}
		$stream = $client->query
			->request($stream->{paging}{next})
			->as_hashref;
	}
}

method get_authorization (Str $user, Str $password) {
	my $client = $self->client();
	my $perm_uri = $client
		->authorize
		->extend_permissions(qw(read_stream publish_stream offline_access))
		->set_display('wap')
		->uri_as_string;

	Class::MOP::load_class('WWW::Mechanize');
	my $mech = WWW::Mechanize->new();
	$mech->ssl_opts( verify_hostname => 0 );
	$mech->agent_alias('Linux Mozilla');

	my $response = $mech->get($perm_uri);
	$mech->submit_form(
		fields => {
			email => $user,
			pass => $password
		}
	);

	eval {
		$mech->click_button( name => 'grant_clicked' );
	};
	my $code_from_authorize_postback = $mech->uri();
	$code_from_authorize_postback =~
		s,\Qhttps://www.facebook.com/connect/login_success.html?code=\E,,;
	my $token_response_object = $client->request_access_token($code_from_authorize_postback);
	my $token_string = $token_response_object->token;
	my $token_expires_epoch = $token_response_object->expires;

	return { token => $token_string, expires => $token_expires_epoch };
}

method get_config_access_token {
	my $config = NNTP::Portal::Config->instance->config();
	if( exists $config->()->{plugin}{facebook}{access_token} ) {
		return $config->()->{plugin}{facebook}{access_token};
	}
	return undef;
}

method set_config_access_token (Str $token) {
	NNTP::Portal::Config->instance->make_plugin_dir;
	my $fb_config = File::Spec->catfile(
		NNTP::Portal::Config->instance->plugin_dir,
		'facebook.yml');

	my $config_data;
	$config_data = LoadFile( $fb_config ) if( -r $fb_config );

	$config_data->{access_token} = $token;
	DumpFile($fb_config, $config_data);
}


with 'NNTP::Portal::Plugin';

no Moose;
__PACKAGE__->meta->make_immutable;

=head1 SEE ALSO

L<Facebook::Graph>, L<http://developers.facebook.com/docs/reference/api/>

=cut
