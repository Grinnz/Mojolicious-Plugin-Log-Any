use strict;
use warnings;
use Test::Needs 'Log::Dispatchouli';

my @levels = qw(debug info warn error fatal);

my ($full_log, $lite_log) = (Log::Dispatchouli->new_tester({debug => 1}), Log::Dispatchouli->new_tester);

{package My::Test::App;
  use Mojo::Base 'Mojolicious';
  sub startup {
    my $self = shift;
    $self->plugin('Log::Any' => {logger => $full_log});
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
plugin 'Log::Any' => {logger => $lite_log};
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
  $lite_log->clear_events;
  
  $t->get_ok("/$level");
  
  if ($level eq 'debug') {
    is_deeply $lite_log->events, [], 'no log message';
  } else {
    ok +(grep { $_->{message} =~ m/\[\Q$level\E\] test\nmessage$/m } @{$lite_log->events}), "$level log message"
      or diag dumper $lite_log->events;
  }
}

$t = Test::Mojo->new('My::Test::App');
foreach my $level (@levels) {
  $full_log->clear_events;
  
  $t->get_ok("/$level");
  
  ok +(grep { $_->{message} =~ m/\[\Q$level\E\] test\nmessage$/m } @{$full_log->events}), "$level log message"
    or diag dumper $full_log->events;
}

done_testing;
