#################
##
## mkappa
## Version: 0.2a
## mkappa computes Mezzich's Kappa for measuring the inter-rater reliability
## for N raters with 1+ codes allowed per segment. For more details, see:
## Mezzich JE et al. Assessment of Agreement Among Several Raters Formulating
## Multiple Diagnoses. J Psych Res 1981 16(29):29-39.
##
## Developer: Jared Shenson
## Email: jared.shenson@gmail.com
## 
## Usage: ruby mkappa.rb rater1.csv rater2.csv [rater3.csv...]
##
## Output: mkappa_r[# of raters]_[timestamp].csv
##
## Notes:
## - Files must be saved as CSV, one column per possible code, one row per segment. 
## - Cell contents must be 0 or 1, indicating absence (0) or presence (1) of given code.
## - A single header row may be included. It will be auto-detected and removed.
## - May use as many raters as desired 
## - Requires gem "Statsample" for calculation of kappa significance
##
#################

# Calculate the proportional agreement between two sets of rater codes
# Input: (Array) a and b are arrays of codes, which are integers
# Output: (Float) proportional agreement of codes given by a and b
def prop_agreement_for_pair(a, b)
    return nil if a.empty? || b.empty?
    
    code_agreements = a & b  # set intersection
    provided_codes = (a + b).uniq # set union -> unique
    
    return code_agreements.count / provided_codes.count.to_f
end

# IMPORT CSV PARSER
require 'csv'

# IMPORT STATSAMPLE GEM
require 'statsample'

# IMPORT MATH LIBRARY
include Math

## Read in rater data
raters = []
codes = []
ARGV.each do |file|

    rater_data = []
    CSV.foreach(file, {:converters => [:numeric]}) do |row|
        
        # Identify header row, if present, and store its contents for output use
        if row[0].is_a?(String) && row[0].match(/[A-Za-z]/)
            codes = row if codes.empty?
            next
        end
        
        # For each code in the row, check if it's marked present
        # If so, add it to the rater's marked codes
        row_data = []
        row.each_with_index do |code, idx|
            row_data << idx if code == 1
        end
        
        # Add row data to rater's data stack
        rater_data << row_data
        
    end
    
    # Add rater data to raters' stack
    raters << rater_data

end

## Compute proportional agreement for each segment
rater_count = raters.count
max_segment_count = raters.map(&:count).max
agreements = []

for i in 0...max_segment_count
    
    valid_pairs = 0
    sum_prop_agreement = 0
    
    for j in 0...rater_count
        for k in (j+1)...rater_count
            
            # for each unique pair (j, k) of n raters, if both raters supplied codes for the segment
            # compute the proportional agreement for the pair and add to the sum
            if !raters[j][i].empty? && !raters[k][i].empty?
                valid_pairs += 1
                sum_prop_agreement += prop_agreement_for_pair(raters[j][i], raters[k][i])
            end
            
        end
    end
    
    agreements << sum_prop_agreement / valid_pairs.to_f
    
end

## Calculate Mezzich's Kappa
rater_valid_counts = raters.map{ |rater| rater.select{|c| !c.empty?}.count }
coding_schemes = rater_valid_counts.reduce(0) { |sum, cnt| sum + cnt }

total_prop_agreement = agreements.reduce(0.0) { |sum, pa| sum + pa }
observed_agreement = total_prop_agreement / max_segment_count # Po
expected_agreement = total_prop_agreement / coding_schemes #Pc

kappa = (observed_agreement - expected_agreement) / (1 - expected_agreement)
std_error = (observed_agreement - expected_agreement) / (Math.sqrt(max_segment_count) * (1 - expected_agreement))

confidence_level = 0.95

t_test = Statsample::Test::T.new(kappa, std_error, max_segment_count - 1)
ci = t_test.ci

## Output Results
# Create output file
timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
output = File.new("mkappa_r#{rater_count}_#{timestamp}.csv", "w")

# Output summary statistics
output.puts "Input files,#{ARGV.join('; ')}"
output.puts "Segments analyzed,#{max_segment_count}"
output.puts "Unique coding schemes,#{coding_schemes}"
output.puts "Total poportional agreement,#{total_prop_agreement}"
output.puts "Observed agreement (Po),#{observed_agreement}"
output.puts "Expected agreement (Pc),#{expected_agreement}"
output.puts ""
output.puts "Mezzich's Kappa,#{kappa}"
output.puts "Standard error,#{std_error}"
t_test_str = "%0.4f" % t_test.t
p_str = "%0.16f" % t_test.probability
ci_str = "%0.3f - %0.3f" % [ci[0],ci[1]]
output.puts "df,#{t_test.df}"
output.puts "t,#{t_test_str}"
output.puts "p,#{p_str}"
output.puts "95% Confidence Interval,#{ci_str}"

# Output segment data
rater_code_str = ""
for i in 1..rater_count
    rater_code_str += "Rater #{i} Codes,"
end

output.puts ""
output.puts "Segment,#{rater_code_str}Proportional Agreement" #header

for i in 0...max_segment_count

    o = "#{i + 1},"
    for j in 0...rater_count
        if raters[j][i].nil? || raters[j][i].empty?
            o += ","
            next
        end
    
        if codes.empty?
            o += "\"#{raters[j][i].map{|code| "c#{code + 1}"}.join(', ')}\","
        else
            o += "\"#{raters[j][i].map{|code| codes[code]}.join(', ')}\","
        end
    end
    
    o += agreements[i].to_s
    
    output.puts o
end

output.close