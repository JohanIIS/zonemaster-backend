use strict;
use warnings;
use utf8;
use 5.14.0;

use JSON::RPC::Dispatch;
use Router::Simple::Declare;
use MyPackage;
use Data::Dumper;
use JSON;
use POSIX;

use Plack::Builder;

builder {
	enable 'Debug',
};

my $router = router {
	connect "foo" => {
		handler => "+MyPackage",
		action  => "process1",
	};
	connect "bar" => {
		handler => "+MyPackage",
		action => "process2"
	};
############## FRONTEND ####################
	connect "version_info" => {
		handler => "+Engine",
		action => "version_info"
	};

	connect "get_ns_ips" => {
		handler => "+Engine",
		action => "get_ns_ips"
	};

	connect "get_data_from_parent_zone" => {
		handler => "+Engine",
		action => "get_data_from_parent_zone"
	};

	connect "validate_domain_syntax" => {
		handler => "+Engine",
		action => "validate_domain_syntax"
	};
	
	connect "start_domain_test" => {
		handler => "+Engine",
		action => "start_domain_test"
	};
	
	connect "test_progress" => {
		handler => "+Engine",
		action => "test_progress"
	};
	
	connect "get_test_results" => {
		handler => "+Engine",
		action => "get_test_results"
	};

	connect "get_test_history" => {
		handler => "+Engine",
		action => "get_test_history"
	};

############ BATCH MODE ####################

	connect "add_api_user" => {
		handler => "+Engine",
		action => "add_api_user"
	};
	
############################################
	connect "api1" => {
		handler => "+Engine",
		action => "api1"
	};
};

my $dispatch = JSON::RPC::Dispatch->new(
	router => $router,
);

sub {
    my $env = shift;
    my $req = Plack::Request->new($env);
    eval {
		my $content = decode_json($req->content);
		say "[".strftime("%F %T", localtime())."][IP:".$env->{REMOTE_ADDR}."][id:".$content->{id}."][method:".$content->{method}."]"
	};
    
    $dispatch->handle_psgi($env, $env->{REMOTE_HOST} );
};