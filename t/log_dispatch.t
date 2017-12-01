use strict;
use warnings;
use Test::Needs 'Log::Dispatch';

my @levels = qw(debug info warn error fatal);

my (@full_log, @lite_log);

{package My::Test::App;
  use Mojo::Base 'Mojolicious';
  my $log = Log::Dispatch->new(outputs => [['Code', code => sub { my %p = @_; push @full_log, $p{message} }, min_level => 'debug']]);
  sub startup {
    my $self = shift;
    $self->plugin('Log::Any' => {logger => $log});
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
my $log = Log::Dispatch->new(outputs => [['Code', code => sub { my %p = @_; push @lite_log, $p{message} }, min_level => 'info']]);
plugin 'Log::Any' => {logger => $log};
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
  @lite_log = ();
  
  $t->get_ok("/$level");
  
  if ($level eq 'debug') {
    is_deeply \@lite_log, [], 'no log message';
  } else {
    my $msg_level = $level eq 'fatal' ? 'critical' : $level;
    ok +(grep { m/\[\Q$msg_level\E\] test\nmessage$/m } @lite_log), "$level log message"
      or diag dumper \@lite_log;
  }
}

$t = Test::Mojo->new('My::Test::App');
foreach my $level (@levels) {
  @full_log = ();
  
  $t->get_ok("/$level");
  
  my $msg_level = $level eq 'fatal' ? 'critical' : $level;
  ok +(grep { m/\[\Q$msg_level\E\] test\nmessage$/m } @full_log), "$level log message"
    or diag dumper \@full_log;
}

done_testing;
