use strict;
use warnings;
use Mojolicious ();
use Mojo::Log;
use Mojo::Util 'dumper';
use Test::More;

my @levels = qw(debug info warn error fatal);
unshift @levels, 'trace' if eval { Mojolicious->VERSION('9.20'); 1 };

my @log;
my $inner_log = Mojo::Log->new;
$inner_log->unsubscribe('message')->on(message => sub { push @log, "[$_[1]] " . join "\n", @_[2..$#_] });

my $log = Mojo::Log->with_roles('Mojo::Log::Role::AttachLogger')->new
  ->unsubscribe('message')->attach_logger($inner_log);

foreach my $level (@levels) {
  @log = ();
  $log->$level('test', 'message');
  ok +(grep { m/^\[\Q$level\E\] test\nmessage$/m } @log), "$level log message"
    or diag dumper \@log;
}

done_testing;
