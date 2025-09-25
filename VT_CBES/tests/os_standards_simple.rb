require 'openstudio'
require 'openstudio-standards'

template = 'VT_CBES_2020'
building_type = 'SecondarySchool'
space_type = 'Classroom'
std = Standard.build(template)
space_type_data = std.standards_data['space_types']
selected_space_type = space_type_data.select{ |s| (s['building_type'] == building_type) && (s['space_type'] == space_type)}[0]
puts "selected space type has an LPD of #{selected_space_type['lighting_per_area']} W/ft^2"
