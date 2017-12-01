use strict;
use warnings;
use Test::Needs 'Log::Any';
use Log::Any::Test;

my @levels = qw(debug info warn error fatal);

{package My::Test::App;
  use Mojo::Base 'Mojolicious';
  sub startup {
    my $self = shift;
    $self->plugin('Log::Any');
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
plugin 'Log::Any';
foreach my $level (@levels) {
  get "/$level" => sub {
    my $c = shift;
    $c->app->log->$level('test', 'message');
    $c->render(text => '');
  };
}

use Test::Mojo;
use Test::More;

my $t = Test::Mojo->new;
my $lite_log = Log::Any->get_logger(category => 'Mojolicious::Lite');
foreach my $level (@levels) {
  $lite_log->clear;
  
  $t->get_ok("/$level");
  
  $lite_log->category_contains_ok('Mojolicious::Lite', qr/\[\Q$level\E\] test\nmessage$/m, "$level log message");
}

$t = Test::Mojo->new('My::Test::App');
my $full_log = Log::Any->get_logger(category => 'My::Test::App');
foreach my $level (@levels) {
  $full_log->clear;
  
  $t->get_ok("/$level");
  
  $full_log->category_contains_ok('My::Test::App', qr/\[\Q$level\E\] test\nmessage$/m, "$level log message");
}

done_testing;
