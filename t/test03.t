use strict;
use warnings;
use 5.10.1;

use Data::Dumper;
use Test::More;   # see done_testing()
use threads;

use FindBin qw($RealScript $Script $RealBin $Bin);
FindBin::again();
##################################################################
my $PROJECT_NAME = "Zonemaster-Backend/t";

my $SCRITP_DIR = __FILE__;
$SCRITP_DIR = $Bin unless ($SCRITP_DIR =~ /^\//);

#warn "SCRITP_DIR:$SCRITP_DIR\n";
#warn "SCRITP_DIR:$SCRITP_DIR\n";
#warn "RealScript:$RealScript\n";
#warn "Script:$Script\n";
#warn "RealBin:$RealBin\n";
#warn "Bin:$Bin\n";
#warn "__PACKAGE__:".__PACKAGE__;
#warn "__FILE__:".__FILE__;

my ($PROD_DIR) = ($SCRITP_DIR =~ /(.*?\/)$PROJECT_NAME/);
#warn "PROD_DIR:$PROD_DIR\n";

my $PROJECT_BASE_DIR = $PROD_DIR.$PROJECT_NAME."/";
#warn "PROJECT_BASE_DIR:$PROJECT_BASE_DIR\n";
unshift(@INC, $PROJECT_BASE_DIR);
##################################################################

unshift(@INC, $PROD_DIR."Zonemaster-Backend/JobRunner") unless $INC{$PROD_DIR."Zonemaster-Backend/JobRunner"};

# Require Engine.pm test
require_ok( 'Engine' );
#require Engine;

# Create Engine object
my $engine = Engine->new({ db => 'ZonemasterDB::CouchDB'} );
isa_ok($engine, 'Engine');

# create a new memory SQLite database
ok($engine->{db}->create_db());

# add test user
ok(length($engine->add_api_user({username => "zonemaster_test", api_key => "zonemaster_test's api key"})) == 32);

# add a new test to the db
my $frontend_params_1 = {
        client_id => 'Zonemaster CGI/Dancer/node.js', # free string
        client_version => '1.0',                        # free version like string
        
        domain => 'afnic.fr',                         # content of the domain text field
        advanced_options => 1,                          # 0 or 1, is the advanced options checkbox checked
        ipv4 => 1,                                                      # 0 or 1, is the ipv4 checkbox checked
        ipv6 => 1,                                                      # 0 or 1, is the ipv6 checkbox checked
        test_profile => 'test_profile_1',       # the id if the Test profile listbox
        nameservers => [                                        # list of the namaserves up to 32
                { ns => 'ns1.nic.fr', ip => '1.2.3.4'},                   # key values pairs representing nameserver => namesterver_ip
                { ns => 'ns2.nic.fr', ip => '192.134.4.1'},
        ],
        ds_digest_pairs => [                            # list of DS/Digest pairs up to 32
                {'ds1' => 'ds-test1'},                   # key values pairs representing ds => digest
                {'ds2' => 'digest2'},                   
        ],
};
my $test_id_1 = $engine->start_domain_test($frontend_params_1);
ok(length($test_id_1) == 32);

# test test_progress API
ok($engine->test_progress($test_id_1) == 0);

require_ok('Runner');
# The following crashes on perl 5.20.0 for unknown reason;
#threads->create( sub { Runner->new({ db => 'ZonemasterDB::CouchDB'} )->run(2); } )->detach();
my $job_runner_dir = $PROD_DIR."Zonemaster-Backend/JobRunner";
my $command = qq{perl -I$job_runner_dir -MRunner -e "Runner->new( { db => 'ZonemasterDB::CouchDB' } )->run('$test_id_1')"};
system("$command &");

sleep(5);
ok($engine->test_progress($test_id_1) > 0);

foreach my $i (1..12) {
	sleep(5);
	my $progress = $engine->test_progress($test_id_1);
	print STDERR "pregress: $progress\n";
	last if ($progress == 100);
}
ok($engine->test_progress($test_id_1) == 100);
my $test_results_1 = $engine->get_test_results({ id => $test_id_1, language => 'fr-FR' });
ok(defined $test_results_1->{id}, 'test_results_1 contains: id');
ok(defined $test_results_1->{params}, 'test_results_1 contains: params');
ok(defined $test_results_1->{creation_time}, 'test_results_1 contains: creation_time');
ok(defined $test_results_1->{results}, 'test_results_1 contains: results');
ok(scalar(@{$test_results_1->{results}}) > 1, 'test_results_1 contain more than 1 result');

my $frontend_params_2 = {
        client_id => 'Zonemaster CGI/Dancer/node.js', # free string
        client_version => '1.0',                        # free version like string
        
        domain => 'afnic.fr',                         # content of the domain text field
        advanced_options => 1,                          # 0 or 1, is the advanced options checkbox checked
        ipv4 => 1,                                                      # 0 or 1, is the ipv4 checkbox checked
        ipv6 => 1,                                                      # 0 or 1, is the ipv6 checkbox checked
        test_profile => 'test_profile_1',       # the id if the Test profile listbox
        nameservers => [                                        # list of the namaserves up to 32
                { ns => 'ns1.nic.fr', ip => '1.2.3.4'},                   # key values pairs representing nameserver => namesterver_ip
                { ns => 'ns2.nic.fr', ip => '192.134.4.1'},
        ],
        ds_digest_pairs => [                            # list of DS/Digest pairs up to 32
                {'ds1' => 'ds-test2'},                   # key values pairs representing ds => digest
                {'ds2' => 'digest2'},                   
        ],
};
my $test_id_2 = $engine->start_domain_test($frontend_params_2);
ok(length($test_id_2) == 32);

# test test_progress API
ok($engine->test_progress($test_id_2) == 0);

require_ok('Runner');
# The following crashes on perl 5.20.0 for unknown reason;
#threads->create( sub { Runner->new({ db => 'ZonemasterDB::CouchDB'} )->run(2); } )->detach();
$command = qq{perl -I$job_runner_dir -MRunner -e "Runner->new( { db => 'ZonemasterDB::CouchDB' } )->run('$test_id_2')"};
system("$command &");

sleep(5);
ok($engine->test_progress($test_id_2) > 0);

foreach my $i (1..12) {
	sleep(5);
	my $progress = $engine->test_progress($test_id_2);
	print STDERR "pregress: $progress\n";
	last if ($progress == 100);
}
ok($engine->test_progress($test_id_2) == 100);
my $test_results_2 = $engine->get_test_results({ id => $test_id_2, language => 'fr-FR' });
ok(defined $test_results_2->{id}, 'result contains: id');
ok(defined $test_results_2->{params}, 'result contains: params');
ok(defined $test_results_2->{creation_time}, 'result contains: creation_time');
ok(defined $test_results_2->{results}, 'result contains: results');
ok(scalar(@{$test_results_2->{results}}) > 1, 'more than 1 result');


my $frontend_params_3 = {
        client_id => 'Zonemaster CGI/Dancer/node.js', # free string
        client_version => '1.0',                        # free version like string
        
        domain => 'nic.fr',                         # content of the domain text field
        advanced_options => 1,                          # 0 or 1, is the advanced options checkbox checked
        ipv4 => 1,                                                      # 0 or 1, is the ipv4 checkbox checked
        ipv6 => 1,                                                      # 0 or 1, is the ipv6 checkbox checked
        test_profile => 'test_profile_1',       # the id if the Test profile listbox
        nameservers => [                                        # list of the namaserves up to 32
                { ns => 'ns1.nic.fr', ip => '1.2.3.4'},                   # key values pairs representing nameserver => namesterver_ip
                { ns => 'ns2.nic.fr', ip => '192.134.4.1'},
        ],
        ds_digest_pairs => [                            # list of DS/Digest pairs up to 32
                {'ds1' => 'ds-test1'},                   # key values pairs representing ds => digest
                {'ds2' => 'digest2'},                   
        ],
};
my $test_id_3 = $engine->start_domain_test($frontend_params_3);
ok(length($test_id_3) == 32);

# test test_progress API
ok($engine->test_progress($test_id_3) == 0);

require_ok('Runner');
# The following crashes on perl 5.20.0 for unknown reason;
#threads->create( sub { Runner->new({ db => 'ZonemasterDB::CouchDB'} )->run(2); } )->detach();
$command = qq{perl -I$job_runner_dir -MRunner -e "Runner->new( { db => 'ZonemasterDB::CouchDB' } )->run('$test_id_3')"};
system("$command &");

sleep(5);
ok($engine->test_progress($test_id_3) > 0);

foreach my $i (1..12) {
	sleep(5);
	my $progress = $engine->test_progress($test_id_3);
	print STDERR "pregress: $progress\n";
	last if ($progress == 100);
}
ok($engine->test_progress($test_id_3) == 100);
my $test_results_3 = $engine->get_test_results({ id => $test_id_3, language => 'fr-FR' });
ok(defined $test_results_3->{id}, 'result contains: id');
ok(defined $test_results_3->{params}, 'result contains: params');
ok(defined $test_results_3->{creation_time}, 'result contains: creation_time');
ok(defined $test_results_3->{results}, 'result contains: results');
ok(scalar(@{$test_results_3->{results}}) > 1, 'more than 1 result');


my $offset = 0;
my $limit = 10;
my $test_history = $engine->get_test_history( { frontend_params => $frontend_params_1, offset => $offset, limit => $limit } );
print STDERR Dumper($test_history);
ok(scalar(@$test_history) == 2, 'test history contains the right number of results');
ok($test_history->[0]->{id} eq $test_id_1 || $test_history->[1]->{id} eq $test_id_1, 'test history contains results of test_id_1');
ok($test_history->[0]->{id} eq $test_id_2 || $test_history->[1]->{id} eq $test_id_2, 'test history contains results of test_id_2');

done_testing();