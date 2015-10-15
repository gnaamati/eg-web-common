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

package EnsEMBL::Web::Component::Gene::ComparaOrthologs;

use strict;

use previous qw(buttons);
our %button_set = %EnsEMBL::Web::Component::Gene::ComparaOrthologs::button_set;

sub is_archaea {
  my ($self,$species) = @_;
  unless(exists($self->{'_archaea'})){
    # munge archaea in pan-compara
    my $dbc = $self->hub->database('compara_pan_ensembl');
    my $archaea = {};
    my $results = $dbc->db_handle->selectall_arrayref(qq{select g.name from ncbi_taxa_node a join ncbi_taxa_name an using (taxon_id) join ncbi_taxa_node c on (c.left_index>a.left_index and c.right_index<a.right_index) join genome_db g on (g.taxon_id=c.taxon_id) where an.name='Archaea' and an.name_class='scientific name';});
    $self->{'_archaea'}->{$_->[0]} = 1 for @$results;
  }
  return exists($self->{'_archaea'}->{$species});
}


sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $object       = $self->object;
  my $species_defs = $hub->species_defs;
  my $cdb          = shift || $hub->param('cdb') || 'compara';
  my $availability = $object->availability;
  my $is_ncrna     = ($object->Obj->biotype =~ /RNA/);
  
  my @orthologues = (
    $object->get_homology_matches('ENSEMBL_ORTHOLOGUES', undef, undef, $cdb), 
  );

  my %orthologue_list;
  my %skipped;

  my $mlss_adaptor = $hub->get_adaptor('get_MethodLinkSpeciesSetAdaptor', $cdb);
  my %not_seen = map {$_->name => 1} @{$mlss_adaptor->fetch_all_by_method_link_type('PROTEIN_TREES')->[0]->species_set_obj->genome_dbs};
  delete $not_seen{$hub->species};
  ##The following line is a quick fix for Bacterial division. Remove this line when ENSEMBL-4137 is fixed. After removing  
  ##the following line, remove this whole method if it is same as Ensembl-webcode version.
  delete $not_seen{lc($hub->species)};
  
  foreach my $homology_type (@orthologues) {
    foreach (keys %$homology_type) {
      (my $species = $_) =~ tr/ /_/;
      $orthologue_list{$species} = {%{$orthologue_list{$species}||{}}, %{$homology_type->{$_}}};
      $skipped{$species}        += keys %{$homology_type->{$_}} if $hub->param('species_' . lc $species) eq 'off';
      delete $not_seen{$species};
      ##The following line is a quick fix for Bacterial division. Remove this line when ENSEMBL-4137 is fixed. After removing  
      ##the following line, remove this whole method if it is same as Ensembl-webcode version.
      delete $not_seen{lc($species)};
    }
  }
  
  return '<p>No orthologues have been identified for this gene</p>' unless keys %orthologue_list;
  
  my %orthologue_map = qw(SEED BRH PIP RHS);
  my $alignview      = 0;
 
  my ($html, $columns, @rows);

  ##--------------------------- SUMMARY TABLE ----------------------------------------

  my ($species_sets, $sets_by_species, $set_order) = $self->_species_sets(\%orthologue_list, \%skipped, \%orthologue_map);

  if ($species_sets) {
    $html .= qq{
      <h3>Summary of orthologues of this gene</h3>
      <p class="space-below">Click on 'Show details' to display the orthologues for one or more groups of species. Alternatively, click on 'Configure this page' to choose a custom list of species.</p>
    };
 
    $columns = [
      { key => 'set',       title => 'Species set',    align => 'left',    width => '26%' },
      { key => 'show',      title => 'Show details',   align => 'center',  width => '10%' },
      { key => '1:1',       title => 'With 1:1 orthologues',       align => 'center',  width => '16%', help => 'Number of species with 1:1 orthologues<em>'.$self->get_glossary_entry('1-to-1 orthologues').'</em>' },
      { key => '1:many',    title => 'With 1:many orthologues',    align => 'center',  width => '16%', help => 'Number of species with 1:many orthologues<em>'.$self->get_glossary_entry('1-to-many orthologues').'</em>' },
      { key => 'many:many', title => 'With many:many orthologues', align => 'center',  width => '16%', help => 'Number of species with many:many orthologues<em>'.$self->get_glossary_entry('Many-to-many orthologues').'</em>' },
      { key => 'none',      title => 'Without orthologues',        align => 'center',  width => '16%', help => 'Number of species without orthologues' },
    ];

    foreach my $set (@$set_order) {
      my $set_info = $species_sets->{$set};
      
      my $none_title = $set_info->{'none'} ? sprintf('<a href="#list_no_ortho">%d</a>', $set_info->{'none'}) : 0;
      push @rows, {
        'set'       => "<strong>$set_info->{'title'}</strong> (<i>$set_info->{'all'} species</i>)<br />$set_info->{'desc'}",
        'show'      => qq{<input type="checkbox" class="table_filter" title="Check to show these species in table below" name="orthologues" value="$set" />},
        '1:1'       => $set_info->{'1-to-1'}       || 0,
        '1:many'    => $set_info->{'1-to-many'}    || 0,
        'many:many' => $set_info->{'Many-to-many'} || 0,
        'none'      => $none_title,
      };
    }
    
    $html .= $self->new_table($columns, \@rows)->render;
  }

  ##----------------------------- FULL TABLE -----------------------------------------

  $html .= '<h3>Selected orthologues</h3>' if $species_sets;

  my $column_name = $self->html_format ? 'Compare' : 'Description';
  
  $columns = [
    { key => 'Species',    align => 'left', width => '10%', sort => 'html'                                                },
    { key => 'Type',       align => 'left', width => '5%',  sort => 'string'                                              },
    { key => 'dN/dS',      align => 'left', width => '5%',  sort => 'numeric'                                             },
    { key => 'identifier', align => 'left', width => '15%', sort => 'html', title => $self->html_format ? 'Ensembl identifier &amp; gene name' : 'Ensembl identifier'},    
    { key => $column_name, align => 'left', width => '10%', sort => 'none'                                                },
    { key => 'Location',   align => 'left', width => '20%', sort => 'position_html'                                       },
    { key => 'Target %id', align => 'left', width => '5%',  sort => 'numeric', label => 'Target %id', title => $self->get_glossary_entry('Target % id')    },
    { key => 'Query %id',  align => 'left', width => '5%',  sort => 'numeric', label => 'Query %id',  title => $self->get_glossary_entry('Query %id')      },
  ];
  
  push @$columns, { key => 'Gene name(Xref)',  align => 'left', width => '15%', sort => 'html', title => 'Gene name(Xref)'} if(!$self->html_format);
  
  @rows = ();
  
  foreach my $species (sort { ($a =~ /^<.*?>(.+)/ ? $1 : $a) cmp ($b =~ /^<.*?>(.+)/ ? $1 : $b) } keys %orthologue_list) {
    next if $skipped{$species};
    
    foreach my $stable_id (sort keys %{$orthologue_list{$species}}) {
      my $orthologue = $orthologue_list{$species}{$stable_id};
      my ($target, $query);
      
      # (Column 2) Add in Orthologue description
      my $orthologue_desc = $orthologue_map{$orthologue->{'homology_desc'}} || $orthologue->{'homology_desc'};
      
      # (Column 3) Add in the dN/dS ratio
      my $orthologue_dnds_ratio = $orthologue->{'homology_dnds_ratio'} || 'n/a';
         
      # (Column 4) Sort out 
      # (1) the link to the other species
      # (2) information about %ids
      # (3) links to multi-contigview and align view
      (my $spp = $orthologue->{'spp'}) =~ tr/ /_/;
      my $link_url = $hub->url({
        species => $spp,
        action  => 'Summary',
        g       => $stable_id,
        __clear => 1
      });

      # Check the target species are on the same portal - otherwise the multispecies link does not make sense
      my $target_links = ($link_url =~ /^\// 
        && $cdb eq 'compara'
        && $availability->{'has_pairwise_alignments'}
      ) ? sprintf(
        '<ul class="compact"><li class="first"><a href="%s" class="notext">Region Comparison</a></li>',
        $hub->url({
          type   => 'Location',
          action => 'Multi',
          g1     => $stable_id,
          s1     => $spp,
          r      => undef,
          config => 'opt_join_genes_bottom=on',
        })
      ) : '';
      
      if ($orthologue_desc ne 'DWGA') {
        ($target, $query) = ($orthologue->{'target_perc_id'}, $orthologue->{'query_perc_id'});
       
        my $align_url = $hub->url({
            action   => 'Compara_Ortholog',
            function => 'Alignment' . ($cdb =~ /pan/ ? '_pan_compara' : ''),
            hom_id   => $orthologue->{'dbID'},
            g1       => $stable_id,
          });
        
        if ($is_ncrna) {
          $target_links .= sprintf '<li><a href="%s" class="notext">Alignment</a></li>', $align_url;
        } else {
          $target_links .= sprintf '<li><a href="%s" class="notext">Alignment (protein)</a></li>', $align_url;
          $target_links .= sprintf '<li><a href="%s" class="notext">Alignment (cDNA)</a></li>', $align_url.';seq=cDNA';
        }
        
        $alignview = 1;
      }
      
      $target_links .= sprintf(
        '<li><a href="%s" class="notext">Gene Tree (image)</a></li></ul>',
        $hub->url({
          type   => 'Gene',
          action => 'Compara_Tree' . ($cdb =~ /pan/ ? '/pan_compara' : ''),
          g1     => $stable_id,
          anc    => $orthologue->{'gene_tree_node_id'},
          r      => undef
        })
      );
      
      # (Column 5) External ref and description
      my $description = encode_entities($orthologue->{'description'});
         $description = 'No description' if $description eq 'NULL';
         
      if ($description =~ s/\[\w+:([-\/\w]+)\;\w+:(\w+)\]//g) {
        my ($edb, $acc) = ($1, $2);
        $description   .= sprintf '[Source: %s; acc: %s]', $edb, $hub->get_ExtURL_link($acc, $edb, $acc) if $acc;
      }
      
      my @external = (qq{<span class="small">$description</span>});
      
      if ($orthologue->{'display_id'}) {
        if ($orthologue->{'display_id'} eq 'Novel Ensembl prediction' && $description eq 'No description') {
          @external = ('<span class="small">-</span>');
        } else {
          unshift @external, $orthologue->{'display_id'};
        }
      }

      my $id_info = qq{<p class="space-below"><a href="$link_url">$stable_id</a></p>} . join '<br />', @external;

      ## (Column 6) Location - split into elements to reduce horizonal space
      my $location_link = $hub->url({
        species => $spp,
        type    => 'Location',
        action  => 'View',
        r       => $orthologue->{'location'},
        g       => $stable_id,
        __clear => 1
      });
      
      my $table_details = {
        'Species'    => join('<br />(', split /\s*\(/, $species_defs->species_label($species)),
        'Type'       => $self->glossary_helptip(ucfirst $orthologue_desc, ucfirst "$orthologue_desc orthologues"),
        'dN/dS'      => $orthologue_dnds_ratio,
        'identifier' => $self->html_format ? $id_info : $stable_id,
        'Location'   => qq{<a href="$location_link">$orthologue->{'location'}</a>},
        $column_name => $self->html_format ? qq{<span class="small">$target_links</span>} : $description,
        'Target %id' => $target,
        'Query %id'  => $query,
        'options'    => { class => join(' ', @{$sets_by_species->{$species} || []}) }
      };      
      $table_details->{'Gene name(Xref)'}=$orthologue->{'display_id'} if(!$self->html_format);
      
      push @rows, $table_details;
    }
  }
  
  my $table = $self->new_table($columns, \@rows, { data_table => 1, sorting => [ 'Species asc', 'Type asc' ], id => 'orthologues' });
  
  if ($alignview && keys %orthologue_list) {
    $button_set{'view'} = 1;
  }
  
  $html .= $table->render;
  
  if (scalar keys %skipped) {
    my $count;
    $count += $_ for values %skipped;
    
    $html .= '<br />' . $self->_info(
      'Orthologues hidden by configuration',
      sprintf(
        '<p>%d orthologues not shown in the table above from the following species. Use the "<strong>Configure this page</strong>" on the left to show them.<ul><li>%s</li></ul></p>',
        $count,
        join "</li>\n<li>", sort map {$species_defs->species_label($_)." ($skipped{$_})"} keys %skipped
      )
    );
  }  

  if (%not_seen) {
    $html .= '<br /><a name="list_no_ortho"/>' . $self->_info(
      'Species without orthologues',
      sprintf(
        '<p>%d species are not shown in the table above because they don\'t have any orthologue with %s.<ul><li>%s</li></ul></p>',
        scalar(keys %not_seen),
        $self->object->Obj->stable_id,
        join "</li>\n<li>", sort map {$species_defs->species_label($_)} keys %not_seen,
      )
    );
  }

  return $html;
}

sub _species_sets {
## Group species into sets - separate method so it can be pluggable easily
  my ($self, $orthologue_list, $skipped) = @_;

  my $species_defs  = $self->hub->species_defs;

  my $set_order = [];
  my $is_pan = $self->hub->function eq 'pan_compara';
  if($is_pan){
    $set_order = [qw(all ensembl metazoa plants fungi protists bacteria archaea)];
  }
  
  my $species_sets = {
    'ensembl'     => {'title' => 'Vertebrates', 'desc' => '', 'species' => [], 'all' => 0},
    'metazoa'     => {'title' => 'Metazoa',     'desc' => '', 'species' => [], 'all' => 0},
    'plants'      => {'title' => 'Plants',      'desc' => '', 'species' => [], 'all' => 0},
    'fungi'       => {'title' => 'Fungi',       'desc' => '', 'species' => [], 'all' => 0},
    'protists'    => {'title' => 'Protists',    'desc' => '', 'species' => [], 'all' => 0},
    'bacteria'    => {'title' => 'Bacteria',    'desc' => '', 'species' => [], 'all' => 0},
    'archaea'     => {'title' => 'Archaea',     'desc' => '', 'species' => [], 'all' => 0},
    'all'         => {'title' => 'All',         'desc' => '', 'species' => [], 'all' => 0},
  };
  my $categories      = {};
  my $sets_by_species = {};
  my $spsites         = $species_defs->ENSEMBL_SPECIES_SITE();

  foreach my $species (keys %$orthologue_list) {
    next if $skipped->{$species};
    
    my $group = $spsites->{lc($species)};

    if($group eq 'bacteria'){
    
      $group = 'archaea' if $self->is_archaea(lc $species);
    
    } elsif (!$is_pan){ 
    
      # not the pan compara page - generate groups
      $group = $species_defs->get_config($species, 'SPECIES_GROUP') || $spsites->{lc($species)} || 'Undefined';
      
      if(!exists $species_sets->{$group}){
        $species_sets->{$group} = {'title' => ucfirst $group, 'species' => [], 'all' => 0};
        push @$set_order, $group;
      }
    }

    push @{$species_sets->{'all'}{'species'}}, $species;
    my $sets = ['all'];

    my $orthologues = $orthologue_list->{$species} || {};

    foreach my $stable_id (keys %$orthologues) {
      my $orth_info = $orthologue_list->{$species}->{$stable_id};
      my $orth_desc = ucfirst($orth_info->{'homology_desc'});

      $species_sets->{'all'}->{$orth_desc}++;
      $species_sets->{'all'}->{'all'}++;
      $species_sets->{$group}->{$orth_desc}++;
      $species_sets->{$group}->{'all'}++;
      
      $categories->{$orth_desc} = {key => $orth_desc, title => $orth_desc} unless exists $categories->{$orth_desc};
    }
    push @{$species_sets->{$group}{'species'}}, $species;
    push (@$sets, $group) if exists $species_sets->{$group};
    $sets_by_species->{$species} = $sets;
  }

  if(!$is_pan) {
    my @unorder = @$set_order;
    @$set_order = sort(@unorder);
    unshift(@$set_order, 'all');
  }

  return ($species_sets, $sets_by_species, $set_order, $categories);
}

sub in_archaea {
  my ($self, $species)=@_;
  
}

sub buttons {
  my $self       = shift;
  my $hub        = $self->hub;
  my $cdb        = $hub->param('cdb') || 'compara';
  my @buttons    = $self->PREV::buttons(@_);

  if ($button_set{'view'}) {
    
    push @buttons, {
      url => $hub->url({
        action   => 'Compara_Ortholog', 
        function => 'PepSequence'.($cdb =~ /pan/ ? '_pan_compara' : ''), 
        _format  => 'Text'
      }),
      caption => 'Download protein sequences',
      class   => 'export',
      modal   => 0
    };

    push @buttons, {
      url => $hub->url({
        action   => 'Compara_Ortholog', 
        function => 'PepSequence'.($cdb =~ /pan/ ? '_pan_compara' : ''), 
        _format  => 'Text',
        seq      => 'cds'
      }),
      caption => 'Download DNA sequences',
      class   => 'export',
      modal   => 0
    };

  }

  return @buttons;
}

1;
