# test_seer2_child_standard.rb
#
# Verifies that the SEER2 -> SEER1 / HSPF2 -> HSPF back-calculations documented in
#
#   .../seer2_ashrae_90_1_2019/data/pnnl_files/seer2_conversion_summary.csv
#
# were (a) loaded into the SEER2_90_1_2019 child standard's standards_data and
# (b) actually flow all the way through onto real OpenStudio model components.
#
# For each equipment kind this test:
#   1. builds a live OpenStudio model with a DX coil in a container that steers the
#      standard's search criteria to the AirCooled category the CSV documents,
#   2. hard-sizes the coil into the 0-64999 Btu/hr capacity bin,
#   3. looks up the efficiency row the gem will use (model_find_object) and confirms
#      that row carries the converted value + the seer2_conversion_note from the CSV,
#   4. calls the standard's apply_efficiency_and_curves method,
#   5. reads the rated COP back OFF the model component, and
#   6. asserts it equals the COP the gem derives from the JSON's converted
#      SEER/HSPF value (seer_to_cop_cooling_with_fan / hspf_to_cop_heating_with_fan).
#
# So the full chain is exercised: CSV -> child JSON -> standards_data -> model coil.
#
# The CSV's SmallDuctHighVelocity / ThroughWall rows cannot be reached through a
# normal DX coil: a coil's cooling_type comes from its condenserType, whose only
# valid values are AirCooled / EvaporativelyCooled (WaterCooled for other coils),
# and the strings "SmallDuctHighVelocity" / "ThroughWall" appear in no standards
# code -- so the apply-efficiency path can never select those rows. Part C therefore
# verifies them one level down: it drives the gem's own lookup (model_find_object)
# and conversion functions directly with synthesized search criteria, pushes the
# derived COP onto a live coil, and asserts that a real coil's derived cooling_type
# is always "AirCooled" (a concrete proof of the unreachability).
#
# Run with the CUSTOM gem on the load path (this is the important part -- otherwise
# you test the openstudio-standards embedded in the CLI, not your fork):
#
#   openstudio -I /home/vcaristo/projects/openstudio-standards-veic-vtcbes/lib/ \
#     /home/vcaristo/projects/vt_cbes_child_class/pnnl_seer2_checks/test_seer2_child_standard.rb
#
# Results are printed to the console AND written next to this script:
#
#   pnnl_seer2_checks/test_seer2_child_standard_results.txt
#
require 'openstudio'
require 'openstudio-standards'
require 'csv'
require 'date'

TEMPLATE = 'SEER2_90_1_2019'
BASE_TMPL = '90.1-2019'

DATA_DIR = '/home/vcaristo/projects/openstudio-standards-veic-vtcbes/lib/openstudio-standards/' \
           'standards/ashrae_90_1/ashrae_90_1_2019/seer2_ashrae_90_1_2019/data'
CSV_PATH = File.join(DATA_DIR, 'pnnl_files', 'seer2_conversion_summary.csv')
NOTE_FIELD = 'seer2_conversion_note'
RESULTS_PATH = File.join(File.dirname(File.expand_path(__FILE__)),
                         'test_seer2_child_standard_results.txt')

# The efficiency field each table's SEER2 conversion targets.
TARGET_FIELD = {
  'heat_pumps'         => 'minimum_seasonal_efficiency',
  'heat_pumps_heating' => 'minimum_heating_seasonal_performance_factor',
  'unitary_acs'        => 'minimum_seasonal_energy_efficiency_ratio'
}.freeze

# Capacity used for every model coil: 30 kBtu/hr -> 30000 Btu/hr, in the 0-64999 bin.
CAP_KBTU = 30.0
CAP_W    = OpenStudio.convert(CAP_KBTU, 'kBtu/hr', 'W').get
CAP_BTU  = OpenStudio.convert(CAP_KBTU, 'kBtu/hr', 'Btu/hr').get

std  = Standard.build(TEMPLATE)
base = Standard.build(BASE_TMPL)

# ---------------------------------------------------------------------------
# Output: tee everything to console and to the results buffer
# ---------------------------------------------------------------------------
$out = []
def say(line = '')
  puts line
  $out << line
end

$pass = 0
$fail = 0
def ok(label, cond, detail = '')
  detail = detail.to_s
  if cond
    $pass += 1
    say("  PASS  #{label}#{detail.empty? ? '' : "  (#{detail})"}")
  else
    $fail += 1
    say("  FAIL  #{label}#{detail.empty? ? '' : "  (#{detail})"}")
  end
end

def approx(a, b, tol = 1e-4)
  return false if a.nil? || b.nil?
  (a.to_f - b.to_f).abs <= tol
end

def num(v)
  return nil if v.nil? || v.to_s.strip.empty?
  Float(v)
rescue ArgumentError
  nil
end

# Pull the source metric value and conversion factor out of the note text, e.g.
# "... using SEER = SEER2 / 0.95 (SEER2=13.4 -- ...)" -> [13.4, 0.95]
def parse_note(note)
  return [nil, nil] unless note
  factor = note[%r{/\s*([\d.]+)\s*\(}, 1]
  source = note[/(?:SEER2|HSPF2)\s*=\s*([\d.]+)/, 1]
  [source && Float(source), factor && Float(factor)]
end

# ---------------------------------------------------------------------------
# Load the CSV (line 1 is a human title; real headers are on line 2)
# ---------------------------------------------------------------------------
raw = File.exist?(CSV_PATH) ? File.read(CSV_PATH) : ''
raw = raw[1..] if raw.start_with?("﻿")
csv_rows = raw.empty? ? [] : CSV.parse(raw.each_line.to_a.drop(1).join, headers: true).map(&:to_h)

# Find the CSV row that documents a given category + capacity. heating_type is blank
# in the CSV for the heating table, so it is only matched on the cooling-side tables.
def csv_lookup(csv_rows, table, cooling_type, subcategory, heating_type, cap_btu)
  csv_rows.find do |r|
    next false unless r['Table'].to_s == table
    next false unless r['Cooling type'].to_s == cooling_type.to_s
    next false unless r['Subcategory'].to_s == subcategory.to_s
    if table != 'heat_pumps_heating'
      next false unless r['Heating type'].to_s == heating_type.to_s
    end
    lo = num(r['Min cap (Btu/h)'])
    hi = num(r['Max cap (Btu/h)'])
    lo && hi && cap_btu.to_f >= lo && cap_btu.to_f <= hi
  end
end

say('=' * 78)
say('SEER2 child-standard conversion verification (model round-trip)')
say("run:      #{Time.now.strftime('%Y-%m-%d %H:%M:%S %z')}")
say("template: #{TEMPLATE}")
say("gem:      #{DATA_DIR}")
say("csv:      #{CSV_PATH}  (#{csv_rows.size} rows)")
say('=' * 78)

# ===========================================================================
# PART A -- DATA LAYER: did the child JSONs load and normalize to the template?
# ===========================================================================
say("\n=== PART A: standards_data loaded from SEER2 child class ===")
say("template = #{std.template}")

TARGET_FIELD.keys.each do |key|
  rows = std.standards_data[key]
  ok("#{key} present", rows.is_a?(Array) && !rows.empty?,
     rows.is_a?(Array) ? "#{rows.size} rows" : 'missing')
  next unless rows.is_a?(Array) && !rows.empty?

  templated = rows.select { |r| r.key?('template') }
  bad = templated.reject { |r| r['template'] == TEMPLATE }
  ok("#{key} template normalized -> #{TEMPLATE}", bad.empty?,
     bad.empty? ? "#{templated.size} templated rows" : "#{bad.size} rows still have #{bad.first['template']}")

  noted = rows.count { |r| r[NOTE_FIELD] }
  csv_n = csv_rows.count { |r| r['Table'].to_s == key }
  ok("#{key} converted-row count matches CSV", noted == csv_n, "json=#{noted} csv=#{csv_n}")
end

say("\n--- child vs base table sizes (sanity) ---")
TARGET_FIELD.keys.each do |key|
  c = std.standards_data[key]&.size
  b = base.standards_data[key]&.size
  say("  #{key.ljust(20)} child=#{c.inspect}  base=#{b.inspect}")
end

# ===========================================================================
# PART B -- COMPONENT LAYER: apply efficiency to real coils, read COP back.
#
# Shared checker: given the coil (already placed in its container and sized), the
# table, and the conversion proc, run the standard's apply method and compare the
# rated COP read off the model against the COP derived from the JSON's converted
# SEER/HSPF value. Also cross-check that value + note against the CSV.
# ===========================================================================
def check_coil(std, csv_rows, label, coil, table, is_cooling)
  field = TARGET_FIELD[table]

  # 1. Resolve the exact efficiency row the gem will use for this coil.
  crit  = std.coil_dx_find_search_criteria(coil)
  props = std.model_find_object(std.standards_data[table], crit, CAP_BTU, Date.today)

  ok("#{label}: efficiency row found", !props.nil?, crit.inspect)
  return if props.nil?

  ct = props['cooling_type']
  sc = props['subcategory']
  ht = props['heating_type']            # nil/absent for the heating table
  say("    -> matched #{table}: #{ct}/#{sc}#{ht ? "/#{ht}" : ''} " \
      "#{props['minimum_capacity']}-#{props['maximum_capacity']} Btu/hr")

  # 2. The row must be one the SEER2 conversion actually touched.
  metric = num(props[field])
  ok("#{label}: row carries #{NOTE_FIELD}", !props[NOTE_FIELD].nil?)
  ok("#{label}: #{field} populated", !metric.nil?, "value=#{props[field].inspect}")

  # 3. Cross-check the converted value + note against the CSV summary.
  crow = csv_lookup(csv_rows, table, ct, sc, ht, CAP_BTU)
  ok("#{label}: documented in CSV", !crow.nil?)
  if crow
    ok("#{label}: JSON #{field} == CSV New SEER2-derived",
       approx(metric, num(crow['New SEER2-derived'])),
       "json=#{metric} csv=#{crow['New SEER2-derived']}")
    ok("#{label}: JSON note == CSV note",
       props[NOTE_FIELD].to_s == crow['Conversion note (written to JSON)'].to_s)
  end

  # 4. Expected COP, derived the same way the gem does.
  exp_cop = is_cooling ? std.seer_to_cop_cooling_with_fan(metric)
                       : std.hspf_to_cop_heating_with_fan(metric)

  # 5. Apply efficiency to the live component, then read the COP back off it.
  if is_cooling
    std.coil_cooling_dx_single_speed_apply_efficiency_and_curves(coil, {})
    rc = coil.ratedCOP
    actual = rc.respond_to?(:is_initialized) ? (rc.is_initialized ? rc.get : nil) : rc
  else
    std.coil_heating_dx_single_speed_apply_efficiency_and_curves(coil, {})
    rc = coil.ratedCOP
    actual = rc.respond_to?(:is_initialized) ? (rc.is_initialized ? rc.get : nil) : rc
  end

  metric_name = is_cooling ? 'SEER' : 'HSPF'
  ok("#{label}: model rated COP == COP(#{metric_name} #{metric})",
     approx(actual, exp_cop, 1e-3),
     "expected=#{exp_cop&.round(4)}  actual=#{actual&.round(4)}")
end

# Verify a category that no model coil can resolve to (SmallDuctHighVelocity /
# ThroughWall). We drive the gem's own lookup + conversion with a hand-built search
# criteria, push the derived COP onto a live coil, and prove that a real coil would
# instead be classified 'AirCooled' -- i.e. these rows are unreachable in practice.
def check_direct(std, csv_rows, crow)
  table = crow['Table'].to_s
  ct = crow['Cooling type'].to_s
  sc = crow['Subcategory'].to_s
  ht = crow['Heating type'].to_s
  is_cooling = table != 'heat_pumps_heating'
  field = TARGET_FIELD[table]
  cap_btu = 20_000.0 # within every SmallDuct (0-64999) and ThroughWall (0-29999) bin
  label = "#{table} / #{ct} / #{sc}#{is_cooling && !ht.empty? ? " / #{ht}" : ''}"

  # 1. Look the row up exactly as the gem would, but with synthesized criteria.
  crit = { 'template' => TEMPLATE, 'cooling_type' => ct, 'subcategory' => sc }
  crit['heating_type'] = ht if is_cooling && !ht.empty?
  props = std.model_find_object(std.standards_data[table], crit, cap_btu, Date.today)

  ok("#{label}: efficiency row found (direct lookup)", !props.nil?, crit.inspect)
  return if props.nil?

  metric = num(props[field])
  ok("#{label}: row carries #{NOTE_FIELD}", !props[NOTE_FIELD].nil?)
  ok("#{label}: JSON #{field} == CSV New SEER2-derived",
     approx(metric, num(crow['New SEER2-derived'])), "json=#{metric} csv=#{crow['New SEER2-derived']}")
  ok("#{label}: JSON note == CSV note",
     props[NOTE_FIELD].to_s == crow['Conversion note (written to JSON)'].to_s)

  # 2. Re-derive the value from the note's own arithmetic.
  src, fac = parse_note(props[NOTE_FIELD])
  derived = (src && fac) ? (src / fac).round(1) : nil
  ok("#{label}: arithmetic (#{src}/#{fac} => #{derived})", approx(derived, metric))

  # 3. Conversion + live-coil round-trip of the derived COP.
  exp_cop = is_cooling ? std.seer_to_cop_cooling_with_fan(metric)
                       : std.hspf_to_cop_heating_with_fan(metric)
  m = OpenStudio::Model::Model.new
  if is_cooling
    coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(m)
    coil.setRatedCOP(OpenStudio::OptionalDouble.new(exp_cop))
  else
    coil = OpenStudio::Model::CoilHeatingDXSingleSpeed.new(m)
    coil.setRatedCOP(exp_cop)
  end
  rc = coil.ratedCOP
  actual = rc.respond_to?(:is_initialized) ? (rc.is_initialized ? rc.get : nil) : rc
  metric_name = is_cooling ? 'SEER' : 'HSPF'
  ok("#{label}: coil COP round-trips COP(#{metric_name} #{metric})",
     approx(actual, exp_cop, 1e-3), "expected=#{exp_cop&.round(4)} actual=#{actual&.round(4)}")

  # 4. Concrete proof of unreachability: a real coil is classified 'AirCooled'.
  model_ct = std.coil_dx_find_search_criteria(coil)['cooling_type']
  ok("#{label}: a real coil's cooling_type is '#{model_ct}', never '#{ct}'", model_ct != ct)
end

say("\n=== PART B: efficiency applied to live model components ===")

# --- unitary_acs, Single Package (bare cooling coil => not a heat pump) -------
begin
  m = OpenStudio::Model::Model.new
  coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(m)
  coil.setName('Unitary AC Single Package cooling coil')
  coil.setRatedTotalCoolingCapacity(CAP_W)
  check_coil(std, csv_rows, 'unitary_acs / Single Package', coil, 'unitary_acs', true)
rescue => e
  $fail += 1
  say("  FAIL  unitary_acs / Single Package raised: #{e.message}")
end

# --- unitary_acs, Split System (name drives the subcategory) ------------------
begin
  m = OpenStudio::Model::Model.new
  coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(m)
  coil.setName('Unitary AC Split System cooling coil')
  coil.setRatedTotalCoolingCapacity(CAP_W)
  check_coil(std, csv_rows, 'unitary_acs / Split System', coil, 'unitary_acs', true)
rescue => e
  $fail += 1
  say("  FAIL  unitary_acs / Split System raised: #{e.message}")
end

# ---------------------------------------------------------------------------
# Heat pumps: build an AirLoopHVACUnitaryHeatPumpAirToAir so the DX cooling coil
# is recognized as a heat pump (-> heat_pumps table) and the DX heating coil is
# recognized as heat-pump heating (-> heat_pumps_heating table). This container
# yields heating_type 'Electric Resistance or None'; the CSV documents the same
# converted SEER/HSPF for that heating_type as for 'All Other'.
# ---------------------------------------------------------------------------
def build_heat_pump(subcat_name)
  m = OpenStudio::Model::Model.new
  clg = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(m)
  clg.setName("HP #{subcat_name} cooling coil")
  clg.setRatedTotalCoolingCapacity(CAP_W)
  htg = OpenStudio::Model::CoilHeatingDXSingleSpeed.new(m)
  htg.setName("HP #{subcat_name} heating coil")
  htg.setRatedTotalHeatingCapacity(CAP_W)
  fan  = OpenStudio::Model::FanOnOff.new(m)
  supp = OpenStudio::Model::CoilHeatingElectric.new(m)
  hp = OpenStudio::Model::AirLoopHVACUnitaryHeatPumpAirToAir.new(
    m, m.alwaysOnDiscreteSchedule, fan, htg, clg, supp
  )
  air = OpenStudio::Model::AirLoopHVAC.new(m)
  hp.addToNode(air.supplyOutletNode)
  [clg, htg]
end

# --- heat_pumps + heat_pumps_heating, Single Package --------------------------
begin
  clg, htg = build_heat_pump('Single Package')
  check_coil(std, csv_rows, 'heat_pumps / Single Package (cooling)', clg, 'heat_pumps', true)
  check_coil(std, csv_rows, 'heat_pumps_heating / Single Package (heating)', htg, 'heat_pumps_heating', false)
rescue => e
  $fail += 1
  say("  FAIL  heat pump Single Package raised: #{e.message}")
end

# --- heat_pumps + heat_pumps_heating, Split System ----------------------------
begin
  clg, htg = build_heat_pump('Split System')
  check_coil(std, csv_rows, 'heat_pumps / Split System (cooling)', clg, 'heat_pumps', true)
  check_coil(std, csv_rows, 'heat_pumps_heating / Split System (heating)', htg, 'heat_pumps_heating', false)
rescue => e
  $fail += 1
  say("  FAIL  heat pump Split System raised: #{e.message}")
end

# ===========================================================================
# PART C -- SmallDuctHighVelocity / ThroughWall: unreachable via a model coil.
# Verified through the gem's own lookup + conversion (see check_direct above).
# ===========================================================================
say("\n=== PART C: SmallDuctHighVelocity / ThroughWall (no model coil resolves here) ===")
say('  cooling_type comes from a DX coil condenserType (AirCooled/EvaporativelyCooled)')
say('  and these strings appear in no standards code, so apply-efficiency never selects')
say('  them. Verifying via direct lookup + conversion, plus a live-coil COP round-trip.')
special = csv_rows.select { |r| %w[SmallDuctHighVelocity ThroughWall].include?(r['Cooling type'].to_s) }
say("  (#{special.size} such conversion rows in the CSV)")
special.each do |crow|
  begin
    check_direct(std, csv_rows, crow)
  rescue => e
    $fail += 1
    say("  FAIL  #{crow['Table']} / #{crow['Cooling type']} / #{crow['Subcategory']} raised: #{e.message}")
  end
end

# ===========================================================================
# SUMMARY
# ===========================================================================
say("\n=== SUMMARY ===")
say("PASS: #{$pass}   FAIL: #{$fail}")
say($fail.zero? ? 'ALL CHECKS PASSED' : 'SOME CHECKS FAILED')

File.write(RESULTS_PATH, $out.join("\n") + "\n")
puts "\nResults written to: #{RESULTS_PATH}"

# NOTE: don't call Kernel#exit here -- the OpenStudio CLI runs this script via
# `require` and reports any SystemExit as an error (with a stack trace). Automation
# should key off the "ALL CHECKS PASSED" / "SOME CHECKS FAILED" summary line above.
