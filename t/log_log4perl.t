use strict;
use warnings;
use Test::Needs 'Log::Log4perl';

Log::Log4perl->init({
  'log4perl.logger.My::Test::App' => 'DEBUG, full_log',
  'log4perl.logger.Mojolicious::Lite' => 'INFO, lite_log',
  'log4perl.appender.full_log' => 'Log::Log4perl::Appender::TestBuffer',
  'log4perl.appender.full_log.name' => 'full_log',
  'log4perl.appender.full_log.layout' => 'Log::Log4perl::Layout::SimpleLayout',
  'log4perl.appender.lite_log' => 'Log::Log4perl::Appender::TestBuffer',
  'log4perl.appender.lite_log.name' => 'lite_log',
  'log4perl.appender.lite_log.layout' => 'Log::Log4perl::Layout::SimpleLayout',
});

my @levels = qw(debug info warn error fatal);

{package My::Test::App;
  use Mojo::Base 'Mojolicious';
  sub startup {
    my $self = shift;
    $self->plugin('Log::Any' => {logger => 'Log::Log4perl'});
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
plugin 'Log::Any' => {logger => 'Log::Log4perl'};
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
my $lite_log = Log::Log4perl::Appender::TestBuffer->by_name('lite_log');
foreach my $level (@levels) {
  $lite_log->clear;
  
  $t->get_ok("/$level");
  
  if ($level eq 'debug') {
    is $lite_log->buffer, '', 'no log message' or diag $lite_log->buffer;
  } else {
    like $lite_log->buffer, qr/\[\Q$level\E\] test\nmessage$/m, "$level log message"
      or diag $lite_log->buffer;
  }
}

$t = Test::Mojo->new('My::Test::App');
my $full_log = Log::Log4perl::Appender::TestBuffer->by_name('full_log');
foreach my $level (@levels) {
  $full_log->clear;
  
  $t->get_ok("/$level");
  
  like $full_log->buffer, qr/\[\Q$level\E\] test\nmessage$/m, "$level log message"
    or diag $full_log->buffer;
}

done_testing;
