=head1 LICENSE

Copyright [2009-2014] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::ViewConfig::Transcript::PopulationImage;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig);

# EG: replaced the calls to self->add_form_element with a cut down version of the function 
# for metazoan site it meant the speed up of ~100s in display of the config panel


sub form {
  my $self       = shift;
  my $variations = $self->species_defs->databases->{'DATABASE_VARIATION'};
  my %options    = EnsEMBL::Web::Constants::VARIATION_OPTIONS;
  my %validation = %{$options{'variation'}};
  my %class      = %{$options{'class'}};
  my %type       = %{$options{'type'}};

  # Add Individual selection
  $self->add_fieldset('Selected samples');

  my @strains = (@{$variations->{'DEFAULT_STRAINS'}}, @{$variations->{'DISPLAY_STRAINS'}});
  my %seen;

  foreach (sort @strains) {
    if (!exists $seen{$_}) {
## EG - avoid slow method 'add_form_element'
      my $element = {
    	  type  => 'CheckBox',
    	  label => $_,
    	  name  => "opt_pop_$_",
    	  value => 'on',
    	  raw   => 1
      };

      $element->{'selected'} = $self->get($element->{'name'}) eq $element->{'value'} ? 1 : 0 ;
      $self->get_form->add_element(%$element); 
      $self->{'labels'}{$element->{'name'}} ||= $element->{'label'};
##
      $seen{$_} = 1;
    }
  }

  # Add source selection
  $self->add_fieldset('Variation source');
  
  foreach (sort keys %{$self->hub->table_info('variation', 'source')->{'counts'}}) {
    my $name = 'opt_' . lc $_;
    $name    =~ s/\s+/_/g;
    
    $self->add_form_element({
      type  => 'CheckBox', 
      label => $_,
      name  => $name,
      value => 'on',
      raw   => 1
    });
  }
  
  # Add class selection
  $self->add_fieldset('Variation class');
  
  foreach (keys %class) {
    $self->add_form_element({
      type  => 'CheckBox',
      label => $class{$_}[1],
      name  => lc $_,
      value => 'on',
      raw   => 1
    });
  }
  
  # Add type selection
  $self->add_fieldset('Consequence type');
  
  foreach (keys %type) {
    $self->add_form_element({
      type  => 'CheckBox',
      label => $type{$_}[1],
      name  => lc $_,
      value => 'on',
      raw   => 1
    });
  }

  # Add selection
  $self->add_fieldset('Consequence options');
  
  $self->add_form_element({
    type   => 'DropDown',
    select =>, 'select',
    label  => 'Type of consequences to display',
    name   => 'consequence_format',
    values => [
      { value => 'label',   caption => 'Sequence Ontology terms' },
      { value => 'display', caption => 'Old Ensembl terms'       },
    ]
  });  
  
  # Add context selection
  $self->add_fieldset('Intron Context');

  $self->add_form_element({
    type   => 'DropDown',
    select => 'select',
    name   => 'context',
    label  => 'Intron Context',
    values => [
      { value => '20',   caption => '20bp'         },
      { value => '50',   caption => '50bp'         },
      { value => '100',  caption => '100bp'        },
      { value => '200',  caption => '200bp'        },
      { value => '500',  caption => '500bp'        },
      { value => '1000', caption => '1000bp'       },
      { value => '2000', caption => '2000bp'       },
      { value => '5000', caption => '5000bp'       },
      { value => 'FULL', caption => 'Full Introns' }
    ]
  });

}

1;
