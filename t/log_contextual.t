use strict;
use warnings;
use Test::Needs 'Log::Contextual';
use Log::Contextual::SimpleLogger;

my @levels = qw(debug info warn error fatal);

my @log;
use Log::Contextual -logger => Log::Contextual::SimpleLogger->new({coderef => sub { push @log, @_ }, levels_upto => 'debug'});

{package My::Test::App;
  use Mojo::Base 'Mojolicious';
  sub startup {
    my $self = shift;
    $self->plugin('Log::Any' => {logger => 'Log::Contextual'});
    foreach my $level (@levels) {
      $self->routes->get("/$level" => sub {
        my $c = shift;
        $c->app->log->$level('test', 'message');
        $c->render(text => '');
      });
    }
  };
}

use Mojolicious::Lite;
plugin 'Log::Any' => {logger => 'Log::Contextual'};
foreach my $level (@levels) {
  get "/$level" => sub {
    my $c = shift;
    $c->app->log->$level('test', 'message');
    $c->render(text => '');
  };
}

use Mojo::Util 'dumper';
use Test::Mojo;
use Test::More;

my $t = Test::Mojo->new;
foreach my $level (@levels) {
  @log = ();
  
  $t->get_ok("/$level");
  
  ok +(grep { m/\[\Q$level\E\] test\nmessage$/m } @log), "$level log message"
    or diag dumper \@log;
}

$t = Test::Mojo->new('My::Test::App');
foreach my $level (@levels) {
  @log = ();
  
  $t->get_ok("/$level");
  
  ok +(grep { m/\[\Q$level\E\] test\nmessage$/m } @log), "$level log message"
    or diag dumper \@log;
}

done_testing;
