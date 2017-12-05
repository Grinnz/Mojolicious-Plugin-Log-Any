package Mojolicious::Plugin::Log::Any;

use Mojo::Base 'Mojolicious::Plugin';

our $VERSION = '0.001';

sub register {
  my ($self, $app, $conf) = @_;
  
  my $logger = $conf->{logger} // 'Log::Any';
  
  $app->log->with_roles('Mojo::Log::Role::AttachLogger')
    ->attach_logger($logger, ref($app));
}

1;

=head1 NAME

Mojolicious::Plugin::Log::Any - Use other loggers in a Mojolicious application

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
      callbacks => sub { my %p = @_; '[' . localtime() . '] ' . $p{message} },
    ]);
    $self->plugin('Log::Any' => {logger => $log});
    
    # Log::Dispatchouli
    use Log::Dispatchouli;
    my $log = Log::Dispatchouli->new({ident => 'MyApp', facility => 'daemon', to_file => 1});
    $self->plugin('Log::Any' => {logger => $log});
    
    # Log::Log4perl
    use Log::Log4perl;
    Log::Log4perl->init($self->home->child('log.conf'));
    $self->plugin('Log::Any' => {logger => 'Log::Log4perl'});
  }
  
  # or in a Mojolicious::Lite app
  use Mojolicious::Lite;
  use Log::Any::Adapter {category => 'Mojolicious::Lite'}, File => app->home->child('myapp.log'), log_level => 'info';
  plugin 'Log::Any';

=head1 DESCRIPTION

L<Mojolicious::Plugin::Log::Any> is a L<Mojolicious> plugin that redirects the
application logger to pass its log messages to an external logging framework
using L<Mojo::Log::Role::AttachLogger/"attach_logger">. By default, L<Log::Any>
is used, but a different framework or object may be specified. The category
for L<Log::Any> or L<Log::Log4perl> is set to the application class name, which
is C<Mojolicious::Lite> for lite applications.

The default behavior of the L<Mojo::Log> object to filter messages by level,
keep history, prepend a timestamp, and write log messages to a file or STDERR
will be suppressed. It is expected that the logging framework output handler
will be configured to handle these details as necessary. The log level,
however, will be prepended to the message in brackets before passing it on.

=head1 OPTIONS

=head2 logger

  plugin 'Log::Any', {logger => $logger};

Logging framework or object to pass log messages to, of a type recognized by
L<Mojo::Log::Role::AttachLogger/"attach_logger">. Defaults to C<Log::Any>.

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
