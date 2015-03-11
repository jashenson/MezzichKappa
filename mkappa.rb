#################
##
## mkappa
## Version: 0.1a
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

# IMPORT CSV PARSER
require 'csv'

# IMPORT STATSAMPLE GEM
require 'statsample'

## Read in rater data
raters = []
header_row = []
ARGV.each do |file|

    rater_data = []
    CSV.foreach(file) do |row|
        
        if row[0].match /[A-Za-z]/ # found header row, skip
            header_row = row if header_row.empty?
            next
        end
        
        # For each code in the row, check if it's marked present
        # If so, add it to the rater's marked codes
        row_data = []
        row.each_with_index do |code, idx|

            row_data << idx if code.to_i == 1

        end
        
        # Add row data to rater's data stack
        rater_data << row_data
        
    end
    
    # Add rater data to raters' stack
    raters << rater_data

end

## Verify same number of segments were provided in each file
segment_count = 0
raters.each do |rater|
    if segment_count == 0
        segment_count = rater.count
    else
        throw "Segment counts do not agree. Please check input files." if segment_count != rater.count
    end
end

## Compute proportional overlap for each segment
rater_count = raters.count
unique_coding_schemes = 0
overlap = []
for i in 0...segment_count
    
    code_union = []
    code_agreements = []
    for j in 0...rater_count
        
        code_union += raters[j][i]
        
        if j == 0
            code_agreements = raters[j][i]
            unique_coding_schemes += 1
        else
            code_agreements = code_agreements & raters[j][i] # set intersection
            
            is_unique = true
            for k in 0...j
                if raters[j][i] == raters[k][i]
                    is_unique = false
                    break
                end
            end
            
            unique_coding_schemes += 1 if is_unique
        end
        
    end
    
    code_union.uniq!
    
    overlap << [code_agreements.count, code_union.count, code_agreements.count / code_union.count.to_f]
    
end

## Calculate Mezzich's Kappa
include Math
proportional_agreement_sum = overlap.reduce(0.0) { |sum, segment| sum + segment[2] }
observed_agreement = proportional_agreement_sum / segment_count # Po
expected_agreement = proportional_agreement_sum / unique_coding_schemes

kappa = (observed_agreement - expected_agreement) / (1 - expected_agreement)
std_error = (observed_agreement - expected_agreement) / (Math.sqrt(segment_count) * (1 - expected_agreement))

confidence_level = 0.95

t_test = Statsample::Test::T.new(kappa, std_error, segment_count - 1)
ci = t_test.ci

## Output Results
# Create output file
timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
output = File.new("mkappa_r#{rater_count}_#{timestamp}.csv", "w")

# Output summary statistics
output.puts "Input files,#{ARGV.join('; ')}"
output.puts "Segments analyzed,#{segment_count}"
output.puts "Unique coding schemes,#{unique_coding_schemes}"
output.puts "Proportional agreement,#{proportional_agreement_sum}"
output.puts "Observed agreement,#{observed_agreement}"
output.puts "Expected agreement,#{expected_agreement}"
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
output.puts "Segment,#{rater_code_str}Code Agreements,Total Codes,Proportional Agreement" #header

for i in 0...segment_count

    o = "#{i + 1},"
    for j in 0...rater_count
        if header_row.empty?
            o += "\"#{raters[j][i].map{|code| code + 1}.join(', ')}\","
        else
            o += "\"#{raters[j][i].map{|code| header_row[code]}.join(', ')}\","
        end
    end
    
    o += "#{overlap[i][0]},#{overlap[i][1]},#{overlap[i][2]}"
    
    output.puts o
end

output.close