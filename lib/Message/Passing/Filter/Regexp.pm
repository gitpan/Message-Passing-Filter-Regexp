package Message::Passing::Filter::Regexp;
use 5.014002;
use strict;
use warnings;
use Moo;
use MooX::Types::MooseLike::Base qw/ ArrayRef Str /;
use namespace::clean -except => 'meta';
use DateTime;
use Message::Passing::Filter::Regexp::Log;

with qw/ Message::Passing::Role::Filter /;
use vars qw( $VERSION );

$VERSION = 0.01;

has format => (
    is => 'ro',
    isa => Str,
    default => sub { ':default' },
);

has regexfile => (
    is => 'ro',
    isa => Str,
    default => sub { '/etc/message-passing/regexfile' },
);

has capture => (
    is => 'ro',
    isa => ArrayRef,
    default => sub { [] }, 
);

has _regex => (
    is => 'ro',
    lazy => 1,
    builder => '_build_regex',
);

sub _build_regex {
    my $self = shift;
    Message::Passing::Filter::Regexp::Log->new(
        format    => $self->format,
        capture   => $self->capture,
        regexfile => $self->regexfile,
    );
};

sub filter {
    my ($self, $message) = @_;
    my $log_line = $message->{'@message'};
    my %data;
    my @fields = $self->_regex->capture;
    my $re = $self->_regex->regexp;
    @data{@fields} = $log_line =~ /$re/;
    $message->{'@fields'} = {
        %data,
    };
    return $message;
}

1;


1;
__END__
=head1 NAME

Message::Passing::Filter::Regexp - Regexp Capture Filter For Message::Passing

=head1 SYNOPSIS

    # regexfile
    [FORMAT]
    :default = %date %status %remotehost %domain %request %originhost %responsetime %upstreamtime %bytes %referer %ua %xff
    :nginxaccesslog = %date %status %remotehost %bytes %responsetime
    [REGEXP]
    %date = (?#=date)\[(?#=ts)\d{2}\/\w{3}\/\d{4}(?::\d{2}){3}(?#!ts) [-+]\d{4}\](?#!date)
    %status = (?#=status)\d+(?#!status)
    %remotehost = (?#=remotehost)\S+(?#!remotehost)
    %domain = (?#=domain).*?(?#!domain)
    %request = (?#=request)-|(?#=method)\w+(?#!method) (?#=url).*?(?#!url) (?#=version)HTTP/\d\.\d(?#!version)(?#!request)
    %originhost = (?#=originhost)-|(?#=oh).*?(?#!oh):\d+(?#!originhost)
    %responsetime = (?#=responsetime)-|.*?(?#!responsetime)
    %upstreamtime = (?#=upstreamtime).*?(?#!upstreamtime)
    %bytes = (?#=bytes)\d+(?#!bytes)
    %referer = (?#=referer)\"(?#=ref).*?(?#!ref)\"(?#!referer)
    %useragent = (?#=useragent)\"(?#=ua).*?(?#!ua)\"(?#!useragent)
    %xforwarderfor = (?#=xforwarderfor)\"(?#=xff).*?(?#!xff)\"(?#!xforwarderfor)

    # message-passing-cli
    use Message::Passing::DSL;
    run_message_server message_chain {
        input file => (
            class => 'FileTail',
            output_to => 'decoder',
        );
        decoder decoder => (
            class => 'JSON',
            output_to => 'logstash',
        );
        filter logstash => (
            class => 'ToLogstash',
            output_to => 'regexp',
        );
        filter regexp => (
            class => 'Regexp',
            format => ':nginxaccesslog',
            capture => [qw( ts status remotehost url oh responsetime upstreamtime bytes )]
            output_to => 'encoder',
        );
        encoder("encoder",
            class => 'JSON',
            output_to => 'stdout',
            output_to => 'es',
        );
        output stdout => (
            class => 'STDOUT',
        );
        output elasticsearch => (
            class => 'ElasticSearch',
            elasticsearch_servers => ['127.0.0.1:9200'],
        );
    };

=head1 DESCRIPTION

This filter passes all incoming messages through with regexp captures.

Note it must be running after Message::Passing::Filter::ToLogstash because it don't process with json format but directly capture C<< $message->{'@message'} >> data lines into C<< %{ $message->{'@fields'} } >>

=head1 ATTRIBUTES

=head2 regexfile

Path of your regexfile. Default is /etc/message-passing/regexfile.

=head2 format

Name of a defined format in your regexfile.

=head2 capture

ArrayRef of regex names which you want to capture and has been defined in your regexfile. note delete the prefix C<%>.

=head1 TODO

Need to keep numberic type for json. C<to_json> will make all element to be "string". That's bad for elasticsearch term_stats API.

=head1 SEE ALSO

Idea steal from <http://logstash.net> Grok filter

Config Format see L<Config::Tiny>

=head1 AUTHOR

chenryn, E<lt>rao.chenlin@gmail.com<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by chenryn

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.2 or,
at your option, any later version of Perl 5 you may have available.


=cut
