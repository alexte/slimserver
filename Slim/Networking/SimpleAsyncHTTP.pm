package Slim::Networking::SimpleAsyncHTTP;

# $Id$

# SlimServer Copyright (c) 2003-2005 Sean Adams, Slim Devices Inc.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License, 
# version 2.

# this class provides non-blocking http requests from SlimServer.
# That is, use this class for your http requests to ensure that
# SlimServer does not become unresponsive, or allow music to pause,
# while your code waits for a response

# This class is intended for plugins and other code needing simply to
# process the result of an http request.  If you have more complex
# needs, i.e. handle an http stream, or just interested in headers,
# take a look at HttpAsync.

# more documentation at end of file.

use strict;

use Slim::Networking::AsyncHTTP;
use Slim::Utils::Misc;

sub new {
	my $class = shift;
	my $callback = shift;
	my $errorcb = shift;
	my $params = shift || {};

	my $self = {cb => $callback,
				ecb => $errorcb,
				params => $params};
	return bless $self;
}

sub params {
	my $self = shift;
	my $key = shift;
	my $value = shift;
	
	if ($value) {
		$self->{params}->{$key} = $value;
	} else {
		return $self->{params}->{$key};
	}
}

# performs the http GET
sub get {
	my $self = shift;
	my $url = shift;

	$self->{url} = $url;

	$::d_http_async && msg("SimpleAsyncHTTP: getting $url\n");
	
	# start asynchronous get
	# we'll be called back when its done.
	my ($server, $port, $path, $user, $password) = Slim::Utils::Misc::crackURL($url);
	my $http = Slim::Networking::AsyncHTTP->new(Host => $server,
												PeerPort => $port);
	# TODO: handle basic auth if username, password provided
	$http->write_request_async(GET => $path);
	
	$http->read_response_headers_async(\&headerCB,
									   {ez=>$self,
										socket=>$http});
	$self->{socket} = $http;
}

# TODO: support POST as well as GET

# TODO: check for http redirects, handle them seamlessly for the caller
sub headerCB {
	my $state = shift;
	my $error = shift;
	my ($code, $mess, %h) = @_;
	
	my $self = $state->{ez};
	my $http = $state->{socket};

	$::d_http_async && msg("SimpleAsyncHTTP: status for ". $self->{url} . " is $mess\n");

	if ($error) {
		&{$self->{ecb}}($self);
	} else {
		$self->{code} = $code;
		$self->{mess} = $mess;
		$self->{headers} = \%h;

		# headers read OK, get the body
		$http->read_entity_body_async(\&bodyCB,
									  {ez=>$self,
									   socket=>$http});
	}
}

sub bodyCB {
	my $state = shift;
	my $error = shift;
	my $content = shift; # response body

	my $self = $state->{ez};
	my $http = $state->{socket};

	if ($error) {
		&{$self->{ecb}}($self);
	} else {
		$self->{content} = $content;
		&{$self->{cb}}($self);
	}	
}

sub content {
	my $self = shift;
	return $self->{content};
}

sub url {
	my $self = shift;
	return $self->{url};
}

sub close {
	my $self = shift;
	if ($self->{socket}) {
		$self->{socket}->close();
	}
}

sub DESTROY {
	my $self = shift;

	$::d_http_async && msg("SimpleAsyncHTTP(".$self->url.") destroy called.\n");
	$self->close();
}

1;

__END__

=head NAME

Slim::Networking::SimpleAsyncHTTP - asynchronous non-blocking HTTP client

=head SYNOPSIS

use Slim::Networking::SimpleAsyncHTTP

sub exampleErrorCallback {
    my $http = shift;

    print("Oh no! An error!\n");
}

sub exampleCallback {
    my $http = shift;

    my $content = $ezhttp->content();

	my $data = $ezhttp->params('mydata');

    print("Got the content and my data.\n");
}


my $http = Slim::Networking::SimpleAsyncHTTP->new(\&exampleCallback,
                                                \&exampleErrorCallback,
                                                {mydata => undef});

# sometime after this call, our exampleCallback will be called with the result
$http->get("http://www.slimdevices.com");

# that's all folks.

=head1 DESCRIPTION

This class provides a way within the SlimServer to make an http
request in an asynchronous, non-blocking way.  This is important
because the server will remain responsive and continue streaming audio
while your code waits for the response.

=cut

