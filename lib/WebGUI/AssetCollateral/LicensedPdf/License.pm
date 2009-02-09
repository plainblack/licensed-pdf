package Automat::Customer;

=head1 LEGAL

 -------------------------------------------------------------------
  WebGUI is Copyright 2001-2009 Plain Black Corporation.
 -------------------------------------------------------------------
  Please read the legal notices (docs/legal.txt) and the license
  (docs/license.txt) that came with this distribution before using
  this software.
 -------------------------------------------------------------------
  http://www.plainblack.com                     info@plainblack.com
 -------------------------------------------------------------------

=cut

use strict;
use base 'WebGUI::Crud';
use Class::InsideOut qw(readonly private id register);
use WebGUI::Exception;
use WebGUI::Inbox;
use WebGUI::User;

private user => my %user;

#-------------------------------------------------------------------
sub crud_definition {
	my ($class, $session) = @_;
	my $definition = $class->SUPER::crud_definition($session);
	$definition->{tableName} = 'LicensedPdfLicense';
	$definition->{tableKey} = 'licenseId';
	$definition->{sequenceKey} = 'licensedPdfId';
	$definition->{properties}{licensedPdfId} = {
			fieldType		=> 'guid',
			defaultValue	=> undef,
		};
	$definition->{properties}{userId} = {
			isQueryKey		=> 1,
			fieldType		=> 'User',
			defaultValue	=> undef,
		};
	$definition->{properties}{transactionId} = {
			isQueryKey		=> 1,
			fieldType		=> 'guid',
			defaultValue	=> undef,
		};
	$definition->{properties}{dateOfPurchase} = {
			fieldType		=> 'DateTime',
			defaultValue	=> undef,
		};
	return $definition;
}

#-------------------------------------------------------------------
sub delete {
	my $self = shift;
	my $nextSite = $self->getSites;
	while (my $site = $nextSite->()) {
		$site->delete;
	}
	my $nextServer = $self->getServers;
	while (my $server = $nextServer->()) {
		$server->delete;
	}
	my $nextDomain = $self->getDomains;
	while (my $domain = $nextDomain->()) {
		$domain->delete;
	}
	my $nextTask = $self->getTasks;
	while (my $task = $nextTask->()) {
		$task->delete;
	}
    Automat::Change->create($self->session, $self, 'deleted customer');
	$self->SUPER::delete(@_);
}

#-------------------------------------------------------------------
sub getDomains {
	my $self = shift;
	return Automat::DomainName->getAllIterator($self, {
        constraints         => [
            {"isDeleted=?"=>0},
            {"customerId=?"=>$self->getId},
        ],
        orderBy             => 'name',
        });
}

#-------------------------------------------------------------------
sub getList {
	my ($class, $session) = @_;
	return $session->db->buildHashRef("select ".$class->crud_getTableKey($session).", name from ".$class->crud_getTableName($session)." order by name");
}

#-------------------------------------------------------------------
sub getName {
	my ($self) = @_;
	return $self->get('name');
}

#-------------------------------------------------------------------
sub getServers {
	my $self = shift;
	return Automat::Server->getAllIterator($self, {sequenceKeyValue=>$self->getId});
}

#-------------------------------------------------------------------
sub getSites {
	my $self = shift;
	return Automat::Site->getAllIterator($self, {sequenceKeyValue=>$self->getId});
}

#-------------------------------------------------------------------
sub getSitesInGeneralPopulation {
	my $self = shift;
	return Automat::Site->getAllIterator($self, {
		constraints			=> [{"isGeneralPopulation=? and isDeleted=0"=>1}],
		sequenceKeyValue	=> $self->getId,
		joinUsing			=> [{automatServer	=> "serverId"}],
		});
}

#-------------------------------------------------------------------
sub getTasks {
	my $self = shift;
	return Automat::Task->getAllIterator($self->session, {constraints=>[{"objectId=?"=>$self->getId}]});
}

#-------------------------------------------------------------------
sub instantiatePlainBlack {
	my ($class, $session) = @_;
	unless (defined $session && $session->isa('WebGUI::Session')) {
        WebGUI::Error::InvalidObject->throw(expected=>'WebGUI::Session', got=>(ref $session), error=>'Need a session.');
    }
	return $class->new($session,'plainblack000000000000');
}

#-------------------------------------------------------------------
sub newByUserId {
	my ($class, $session, $userId) = @_;
	$userId ||= $session->user->userId;
	unless (defined $session && $session->isa('WebGUI::Session')) {
        WebGUI::Error::InvalidObject->throw(expected=>'WebGUI::Session', got=>(ref $session), error=>'Need a session.');
    }
    unless (defined $userId) {
        WebGUI::Error::InvalidParam->throw(error=>'need a userId');
    }
	my $customerId = $session->db->quickScalar("select ".$class->crud_getTableKey($session)." from ".$class->crud_getTableName($session)." where userId=?",[$userId]);
	if ($customerId eq '') {
        WebGUI::Error::ObjectNotFound->throw(error=>'no such '.$class->crud_getTableKey($session), id=>$customerId);
    }
	return $class->new($session, $customerId);
}

#-------------------------------------------------------------------
sub requestDeleteFromServer {
	my $self = shift;

    Automat::Change->create($self->session, $self, 'requested delete customer');
    
    # kill all sites
	my $nextSite = $self->getSites;
	while (my $site = $nextSite->()) {
		$site->requestDeleteFromServer;
	}
    
    # kill all servers
	my $nextServer = $self->getServers;
	while (my $server = $nextServer->()) {
		$server->requestDeleteFromServer;
	}
    
    # kill all domains
	my $nextDomain = $self->getDomains;
	while (my $domain = $nextDomain->()) {
		$domain->requestDeleteFromServer;
	}
    
    # mark deleted
    $self->update({isDeleted=>1});
    
    # add the delete to the queue
	Automat::Task->create($self->session, {objectType=>ref $self, objectId=>$self->getId, action=>"delete"});
}

#-------------------------------------------------------------------
sub update {
    my ($self, $properties) = @_;
    my $id = id $self;
    delete $user{$id} if (exists $properties->{userId});
    Automat::Change->create($self->session, $self, 'updated customer');
    $self->SUPER::update($properties);
}

#-------------------------------------------------------------------
sub user {
	my $self = shift;
	my $id = id $self;
	unless (exists $user{$id}) {
		$user{$id} = WebGUI::User->new($self->session, $self->get('userId'));
	}
	return $user{$id};
}


1;
