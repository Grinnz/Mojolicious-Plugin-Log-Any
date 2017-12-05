package Mojolicious::Plugin::Log::Any;

use Mojo::Base 'Mojolicious::Plugin';
use Carp 'croak';
use Module::Runtime 'require_module';
use Scalar::Util 'blessed';

our $VERSION = '0.001';

sub register {
  my ($self, $app, $conf) = @_;
  
  my $logger = $conf->{logger} // 'Log::Any';
  
  my $do_log;
  if (blessed $logger) {
    if ($logger->isa('Log::Any::Proxy')) {
      $do_log = sub {
        my ($log, $level, @msg) = @_;
        $logger->$level("[$level] " . join "\n", @msg);
      };
    } elsif ($logger->isa('Log::Dispatch')) {
      $do_log = sub {
        my ($log, $level, @msg) = @_;
        $level = 'critical' if $level eq 'fatal';
        $logger->log(level => $level, message => "[$level] " . join "\n", @msg);
      };
    } elsif ($logger->isa('Log::Dispatchouli')) {
      $do_log = sub {
        my ($log, $level, @msg) = @_;
        my $message = "[$level] " . join "\n", @msg;
        return $logger->log_debug($message) if $level eq 'debug';
        # hacky but we don't want to use log_fatal because it throws an
        # exception, and we can't localize a call to set_muted
        local $logger->{muted} = 0 if $level eq 'fatal' and $logger->get_muted;
        $logger->log($message);
      };
    } else {
      croak "Unsupported logger object class " . ref($logger);
    }
  } elsif ($logger eq 'Log::Any') {
    require Log::Any;
    $logger = Log::Any->get_logger(category => ref($app));
    $do_log = sub {
      my ($log, $level, @msg) = @_;
      $logger->$level("[$level] " . join "\n", @msg);
    };
  } elsif ($logger eq 'Log::Contextual' or "$logger"->isa('Log::Contextual')) {
    require_module "$logger";
    "$logger"->import(':log');
    $do_log = sub {
      my ($log, $level, @msg) = @_;
      $self->can("slog_$level")->("[$level] " . join "\n", @msg);
    };
  } else {
    croak "Unsupported logger class $logger";
  }
  
  $app->log->unsubscribe('message')->on(message => $do_log);
}

1;

=head1 NAME

Mojolicious::Plugin::Log::Any - Use other loggers for Mojolicious applications

=head1 SYNOPSIS

  package MyApp;
  use Mojo::Base 'Mojolicious';
  
  sub startup {
    my $self = shift;
    
    # Log::Any (default)
    use Log::Any::Adapter {category => 'MyApp'}, 'Syslog';
    $self->plugin('Log::Any');
    
    # Log::Contextual
    use Log::Contextual::WarnLogger;
    use Log::Contextual -logger => Log::Contextual::WarnLogger->new({env_prefix => 'MYAPP'});
    $self->plugin('Log::Any' => {logger => 'Log::Contextual});
    
    # Log::Dispatch
    use Log::Dispatch;
    my $log = Log::Dispatch->new(outputs => ['File::Locked',
      min_level => 'warning',
      filename  => '/path/to/file.log',
      mode      => 'append',
      newline   => 1,
      callbacks => sub { my %p = @_; sprintf '[%s] %s', scalar(localtime), $p{message} },
    ]);
    $self->plugin('Log::Any' => {logger => $log});
    
    # Log::Dispatchouli
    use Log::Dispatchouli;
    my $log = Log::Dispatchouli->new({ident => 'MyApp', facility => 'daemon'});
    $self->plugin('Log::Any' => {logger => $log});
  }
  
  # or in a Mojolicious::Lite app
  use Mojolicious::Lite;
  use Log::Any::Adapter {category => 'Mojolicious::Lite'}, File => '/path/to/file.log', log_level => 'info';
  plugin 'Log::Any';

=head1 DESCRIPTION

L<Mojolicious::Plugin::Log::Any> is a L<Mojolicious> plugin that redirects the
application logger to pass its log messages to an external logging framework.
By default, L<Log::Any> is used, but a different framework or object may be
specified.

The default behavior of the L<Mojo::Log> object to filter messages by level,
keep history, prepend a timestamp, and write log messages to a file or STDERR
will be suppressed. It is expected that the logging framework output handler
will be configured to handle these details as necessary. The log level,
however, will be prepended to the message in brackets before passing it on.

=head1 OPTIONS

=head2 logger

  plugin 'Log::Any', {logger => $logger};

Logging framework or object to pass log messages to. The following types are
recognized:

=over

=item Log::Any

Default. The string C<Log::Any> will use a global L<Log::Any> logger, with the
L<Mojolicious> application class name as the category (which is
C<Mojolicious::Lite> for lite applications).

=item Log::Any::Proxy

A L<Log::Any::Proxy> object can be passed directly and will be used for logging
in the standard manner, using the object's existing category.

=item Log::Contextual

The string C<Log::Contextual> will use the global L<Log::Contextual> logger.
Package loggers are not supported. Note that L<Log::Contextual/"with_logger">
may be difficult to use with L<Mojolicious> logging due to the asynchronous
nature of the dispatch cycle.

=item Log::Dispatch

A L<Log::Dispatch> object can be passed to be used for logging. The C<fatal>
log level will be mapped to C<critical>.

=item Log::Dispatchouli

A L<Log::Dispatchouli> object can be passed to be used for logging. The
C<fatal> log level will log messages even if the object is C<muted>, but an
exception will not be thrown as L<Log::Dispatchouli/"log_fatal"> normally does.

=back

=head1 BUGS

Report any issues on the public bugtracker.

=head1 AUTHOR

Dan Book <dbook@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2017 by Dan Book.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=head1 SEE ALSO

L<Mojo::Log>, L<Log::Any>, L<Log::Contextual>, L<Log::Dispatch>,
L<Log::Dispatchouli>
