package WebGUI::AssetCollateral::LicensedPdf::License;

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



1;
