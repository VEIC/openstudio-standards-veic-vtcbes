# This class holds methods that apply VT CBES 2020 specific measures where they deviate from 90.1-2016
# to a given model.
# @ref [References::VT_CBES_2020]
class ASHRAE9012016 < ASHRAE901
  register_standard '90.1-2016'
  attr_reader :template

  def initialize
    @template = '90.1-2016'
    load_standards_database
  end

  # Loads the openstudio standards dataset for this standard.
  #
  # @param data_directories [Array<String>] array of file paths that contain standards data
  # @return [Hash] a hash of standards data
  def load_standards_database(data_directories = [])
    # First load the base ASHRAE 90.1-2016 data
    ashrae_2016_dir = File.join(File.dirname(__dir__), 'ashrae_90_1_2016', 'data')
    base_data = super([ashrae_2016_dir] + data_directories)
    
    # Ensure base_data is a hash
    base_data ||= {}
    
    # Then override with VT_CBES_2020 specific files
    vt_cbes_dir = File.join(__dir__, 'data')
    
    # Load VT_CBES_2020 specific space types
    spc_typ_file = File.join(vt_cbes_dir, 'VT_CBES_2020.spc_typ.json')
    if File.exist?(spc_typ_file)
      spc_typ_data = JSON.parse(File.read(spc_typ_file))
      if spc_typ_data && spc_typ_data['space_types']
        base_data['space_types'] = spc_typ_data['space_types']
      end
    end
    
    # Load VT_CBES_2020 specific construction properties
    const_prop_file = File.join(vt_cbes_dir, 'VT_CBES_2020.construction_properties.json')
    if File.exist?(const_prop_file)
      const_prop_data = JSON.parse(File.read(const_prop_file))
      if const_prop_data && const_prop_data['construction_properties']
        base_data['construction_properties'] = const_prop_data['construction_properties']
      end
    end
    
    return base_data
  end
end
