package WebGUI::Asset::Sku::LicensedPdf;

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
use Tie::IxHash;
use base 'WebGUI::Asset::Sku';
use WebGUI::Group;
use WebGUI::Inbox;
use WebGUI::Storage;
use WebGUI::Utility;


=head1 NAME

Package WebGUI::Asset::Sku::LicensedPdf

=head1 DESCRIPTION

Generates a license stamp at the top of a PDF.

=head1 SYNOPSIS

use WebGUI::Asset::Sku::LicensedPdf;


=head1 METHODS

These methods are available from this class:

=cut



# create table LicensedPdf ( assetId char(22) binary not null, revisionDate bigint not null, originalPdf char(22) binary, primary key (assetId, revisionDate));
# create table LicensedPdfLicensee (licenseeId char(22) binary not null primary key, assetId char(22) binary not null, dateOfPurchase datetime not null, userId char(22) binary not null, transactionId char(22) binary not null);

#-------------------------------------------------------------------

=head2 definition ( session, definition )

defines asset properties for Licensed PDF instances.  You absolutely need 
this method in your new Assets. 

=head3 session

=head3 definition

A hash reference passed in from a subclass definition.

=cut

sub definition {
	my $class = shift;
	my $session = shift;
	my $definition = shift;
	my %properties;
	tie %properties, 'Tie::IxHash';
	%properties = (
		originalPdf => {
			tab         => "properties",
			fieldType   => "file",
			defaultValue=> undef,
			label       => "Original PDF",
			hoverHelp   => "This PDF will be used to generate the licensed PDF file.",
			},
		purchasedGroup => {
			tab         => "security",
			fieldType   => "hidden",
            noFormPost  => 1,
			defaultValue=> undef,
			label       => "Group That Purchased The PDF",
			hoverHelp   => "A group that the user is in after they purchase the PDF.",
			},
	);
	push(@{$definition}, {
		assetName           => "Licensed PDF",
		icon                => 'LicensedPdf.gif',
		autoGenerateForms   => 1,
		tableName           => 'LicensedPdf',
		className           => 'WebGUI::Asset::Sku::LicensedPdf',
		properties          => \%properties
	});
	return $class->SUPER::definition($session, $definition);
}


#-------------------------------------------------------------------

sub duplicate {
    my $self = shift;
    my $newAsset = $self->SUPER::duplicate(@_);
    my $newStorage = $self->getStorageLocation->copy;
    $newAsset->update({originalPdf=>$newStorage->getId});
    return $newAsset;
}


#-------------------------------------------------------------------

=head2 getPrice ()

Returns the value of the price field formatted as currency.

=cut

sub getPrice {
    my $self = shift;
    return sprintf "%.2f", $self->get('price');
}


#-------------------------------------------------------------------

sub getPurchasedGroup {
    my $self = shift;
    unless (exists $self->{_purchasedGroup}) {
        $self->setPurchasedGroup;
    }
    return $self->{_purchasedGroup};
}


#-------------------------------------------------------------------

sub getStorageLocation {
    my $self = shift;
    unless (exists $self->{_storageLocation}) {
        $self->setStorageLocation;
    }
    return $self->{_storageLocation};
}

#-------------------------------------------------------------------

=head2 getWeight ()

Returns the value of the price field formatted as currency.

=cut

sub getWeight {
    return 0;
}



#-------------------------------------------------------------------

=head2 indexContent ( )

Indexing the content of the attachment. See WebGUI::Asset::indexContent() for additonal details. 

=cut

sub indexContent {
    my $self = shift;
    my $indexer = $self->SUPER::indexContent;
    my $storage = $self->getStorageLocation;
    $indexer->addFile($storage->getPath($storage->getFiles->[0]));
}



#-------------------------------------------------------------------

=head2 onCompletePurchase

Adds the user to the purchased group. Sends the purchase notification.

=cut

sub onCompletePurchase {
    my ($self, $item) = @_;
    my $userId = $item->transaction->get('userId');
    $self->getPurchasedGroup->addUsers([$userId]);
    WebGUI::Inbox->new($self->session)->addMessage({
        status  => 'unread',
        userId  => $userId,
        subject => 'Download Ready',
        message => q|The PDF you purchased called "|.$self->getTitle.q|" is ready for you to download. You may download it anytime in the next month. <a href="|.$self->getUrl("func=download").q|">Download your PDF now.</a>|,
        });
    return $self->SUPER::onCompletePurchase($item);
}

#-------------------------------------------------------------------

=head2 onRefund ( item )

Removes the user from the purchased group.

=cut

sub onRefund {
    my ($self, $item) = @_;
    $self->getPurchasedGroup->deleteUsers([$item->transaction->get('userId')]);
    return $self->SUPER::onRefund($item);
}

#-------------------------------------------------------------------

sub purge {
    my $self = shift;
    $self->getStorageLocation->delete;
    return $self->SUPER::purge;
}

#-------------------------------------------------------------------

=head2 setSize ( fileSize )

Set the size of this asset by including all the files in its storage
location. C<fileSize> is an integer of additional bytes to include in
the asset size.

=cut

sub setSize {
    my $self        = shift;
    my $fileSize    = shift || 0;
    my $storage     = $self->getStorageLocation;
    if (defined $storage) {
        foreach my $file (@{$storage->getFiles}) {
            $fileSize += $storage->getFileSize($file);
        }
    }
    return $self->SUPER::setSize($fileSize);
}


#-------------------------------------------------------------------

sub setPurchasedGroup {
    my $self    = shift;
    if ($self->get("purchasedGroup") eq "") {
        my $group = WebGUI::Group->new($self->session, "new");
        $group->name("Purchased Group for Licensed PDF ".$self->getId);
        $group->deleteGroups([3]);
        $group->showInForms(0);
        $group->isEditable(0);
        $group->expireOffset(60*60*24*30);
        $self->{_purchasedGroup} = $group;
        $self->update({purchasedGroup=>$group->getId});
    }
    else {
        $self->{_purchasedGroup} = WebGUI::Group->new($self->session,$self->get("purchasedGroup"));
    }
}

#-------------------------------------------------------------------

sub setStorageLocation {
    my $self    = shift;
    if ($self->get("originalPdf") eq "") {
        $self->{_storageLocation} = WebGUI::Storage->create($self->session);
        $self->update({originalPdf=>$self->{_storageLocation}->getId});
    }
    else {
        $self->{_storageLocation} = WebGUI::Storage->get($self->session,$self->get("originalPdf"));
    }
}

#-------------------------------------------------------------------

=head2 update

We override the update method from WebGUI::Asset in order to handle file system privileges.

=cut

sub update {
    my $self = shift;
    my %before = (
        owner => $self->get("ownerUserId"),
        view => $self->get("groupIdView"),
        edit => $self->get("groupIdEdit"),
        originalPdf => $self->get('originalPdf'),
    );
    $self->SUPER::update(@_);
    ##update may have entered a new originalPdf.  Reset the cached one just in case.
    if ($self->get("originalPdf") ne $before{originalPdf}) {
        $self->setStorageLocation;
    }
    if ($self->get("ownerUserId") ne $before{owner} || $self->get("groupIdEdit") ne $before{edit} || $self->get("groupIdView") ne $before{view}) {
        $self->getStorageLocation->setPrivileges($self->get("ownerUserId"),$self->get("groupIdView"),$self->get("groupIdEdit"));
    }
}

#-------------------------------------------------------------------

=head2 view ( )

method called by the container www_view method. 

=cut

sub view {
	my $self = shift;
	return $self->getToolbar;
}


#-------------------------------------------------------------------

=head2 www_buy ()

Adds the book to the cart.

=cut

sub www_buy {
    my $self = shift;
    return $self->session->privilege->noAccess() unless ($self->canView);
    $self->addToCart;
    return $self->getParent->www_view;
}

#-------------------------------------------------------------------

sub www_download {
    my $self = shift;
}

#-------------------------------------------------------------------

=head2 www_edit ( )

Web facing method which is the default edit page.  Unless the method needs
special handling or formatting, it does not need to be included in
the module.

=cut

sub www_edit {
   my $self = shift;
   my $session = $self->session;
   return $session->privilege->insufficient() unless $self->canEdit;
   return $session->privilege->locked() unless $self->canEditIfLocked;
   return $self->getAdminConsole->render($self->getEditForm->print, 'Licensed PDF');
}

1;
