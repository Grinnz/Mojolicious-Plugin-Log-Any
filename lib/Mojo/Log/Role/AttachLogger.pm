package Mojo::Log::Role::AttachLogger;

use Role::Tiny;
use Carp 'croak';
use Module::Runtime 'require_module';
use Scalar::Util 'blessed';

our $VERSION = '0.001';

our @CARP_NOT = 'Mojolicious::Plugin::Log::Any';

requires qw(on unsubscribe);

sub attach_logger {
  my ($self, $logger, $category) = @_;
  $category //= 'Mojo::Log';
  
  my $do_log;
  if (blessed $logger) {
    if ($logger->isa('Log::Any::Proxy')) {
      $do_log = sub {
        my (undef, $level, @msg) = @_;
        my $formatted = "[$level] " . join "\n", @msg;
        $logger->$level($formatted);
      };
    } elsif ($logger->isa('Log::Dispatch')) {
      $do_log = sub {
        my (undef, $level, @msg) = @_;
        my $formatted = "[$level] " . join "\n", @msg;
        $level = 'critical' if $level eq 'fatal';
        $logger->log(level => $level, message => $formatted);
      };
    } elsif ($logger->isa('Log::Dispatchouli') or $logger->isa('Log::Dispatchouli::Proxy')) {
      $do_log = sub {
        my (undef, $level, @msg) = @_;
        my $formatted = "[$level] " . join "\n", @msg;
        return $logger->log_debug($formatted) if $level eq 'debug';
        # hacky but we don't want to use log_fatal because it throws an
        # exception, we want to allow real exceptions to propagate, and we
        # can't localize a call to set_muted
        local $logger->{muted} = 0 if $level eq 'fatal' and $logger->get_muted;
        $logger->log($formatted);
      };
    } elsif ($logger->isa('Mojo::Log')) {
      $do_log = sub {
        my (undef, $level, @msg) = @_;
        $logger->$level(@msg);
      };
    } else {
      croak "Unsupported logger object class " . ref($logger);
    }
  } elsif ($logger eq 'Log::Any') {
    require Log::Any;
    $logger = Log::Any->get_logger(category => $category);
    $do_log = sub {
      my (undef, $level, @msg) = @_;
      my $formatted = "[$level] " . join "\n", @msg;
      $logger->$level($formatted);
    };
  } elsif ($logger eq 'Log::Log4perl') {
    require Log::Log4perl;
    $logger = Log::Log4perl->get_logger($category);
    $do_log = sub {
      my (undef, $level, @msg) = @_;
      my $formatted = "[$level] " . join "\n", @msg;
      $logger->$level($formatted);
    };
  } elsif ($logger eq 'Log::Contextual' or "$logger"->isa('Log::Contextual')) {
    require_module "$logger";
    "$logger"->import(':log');
    $do_log = sub {
      my (undef, $level, @msg) = @_;
      my $formatted = "[$level] " . join "\n", @msg;
      __PACKAGE__->can("slog_$level")->($formatted);
    };
  } else {
    croak "Unsupported logger class $logger";
  }
  
  $self->unsubscribe('message')->on(message => $do_log);
  
  return $self;
}

1;

=head1 NAME

Mojo::Log::Role::AttachLogger - Use other loggers for Mojo::Log

=head1 SYNOPSIS

  use Mojo::Log;
  my $log = Mojo::Log->with_roles('+AttachLogger')->new;
  
  # Log::Any (default)
  use Log::Any::Adapter {category => 'Mojo::Log'}, 'Syslog';
  $log->attach_logger;
  
  # Log::Contextual
  use Log::Contextual::WarnLogger;
  use Log::Contextual -logger => Log::Contextual::WarnLogger->new({env_prefix => 'MYAPP'});
  $log->attach_logger('Log::Contextual');
  
  # Log::Dispatch
  use Log::Dispatch;
  my $logger = Log::Dispatch->new(outputs => ['File::Locked',
    min_level => 'warning',
    filename  => '/path/to/file.log',
    mode      => 'append',
    newline   => 1,
    callbacks => sub { my %p = @_; '[' . localtime() . '] ' . $p{message} },
  ]);
  $log->attach_logger($logger);
  
  # Log::Dispatchouli
  use Log::Dispatchouli;
  my $logger = Log::Dispatchouli->new({ident => 'MyApp', facility => 'daemon', to_file => 1});
  $log->attach_logger($logger);
  
  # Log::Log4perl
  use Log::Log4perl;
  Log::Log4perl->init('/path/to/log.conf');
  $log->attach_logger('Log::Log4perl');
  
=head1 DESCRIPTION

L<Mojo::Log::Role::AttachLogger> is a <Role::Tiny> role for L<Mojo::Log> that
redirects log messages to an external logging framework. By default,
L<Log::Any> is used, but a different framework or object may be specified.

The default behavior of the L<Mojo::Log> object to filter messages by level,
keep history, prepend a timestamp, and write log messages to a file or STDERR
will be suppressed. It is expected that the logging framework output handler
will be configured to handle these details as necessary. The log level,
however, will be prepended to the message in brackets before passing it on
(except when passing to another L<Mojo::Log> object which normally does this).

L<Mojolicious::Plugin::Log::Any> can be used to apply this role and attach a
logger to a L<Mojolicious> application logger.

=head1 METHODS

L<Mojo::Log::Role::AttachLogger> composes the following methods.

=head2 attach_logger

  $log = $log->attach_logger($logger, $category);

Suppresses the default logging behavior and passes log messages to the given
logging framework or object, with an optional category (defaults to
C<Mojo::Log>). The following types are recognized:

=over

=item Log::Any

Default. The string C<Log::Any> will use a global L<Log::Any> logger with the
specified category.

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

=item Log::Log4perl

The string C<Log::Log4perl> will use a global L<Log::Log4perl> logger with the
specified category.

=item Mojo::Log

Another L<Mojo::Log> object can be passed to be used for logging.

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
L<Log::Dispatchouli>, L<Log::Log4perl>