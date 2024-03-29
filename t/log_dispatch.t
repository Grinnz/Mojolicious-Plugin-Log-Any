use strict;
use warnings;
use Test::Needs 'Log::Dispatch';

use Mojolicious ();
use Mojo::Log;
use Mojo::Util 'dumper';
use Test::More;

my @levels = qw(debug info warn error fatal);
unshift @levels, 'trace' if eval { Mojolicious->VERSION('9.20'); 1 };

my @log;
my $debug_log = Log::Dispatch->new(outputs => [['Code', code => sub { my %p = @_; push @log, $p{message} }, min_level => 'debug']]);
my $log = Mojo::Log->with_roles('Mojo::Log::Role::AttachLogger')->new
  ->unsubscribe('message')->attach_logger($debug_log);

foreach my $level (@levels) {
  @log = ();
  $log->$level('test', 'message');
  ok +(grep { m/\[\Q$level\E\] test\nmessage$/m } @log), "$level log message"
    or diag dumper \@log;
}

my $info_log = Log::Dispatch->new(outputs => [['Code', code => sub { my %p = @_; push @log, $p{message} }, min_level => 'info']]);
$log->unsubscribe('message')->attach_logger($info_log, {prepend_level => 0});

foreach my $level (@levels) {
  @log = ();
  $log->$level('test', 'message');
  
  if ($level eq 'debug' or $level eq 'trace') {
    is_deeply \@log, [], 'no log message' or diag dumper \@log;
  } else {
    ok +(grep { m/^test\nmessage$/m } @log), "$level log message (no prepend)"
      or diag dumper \@log;
  }
}

done_testing;
