#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Function to calculate percentage
calculate_percentage() {
    if [ "$2" -eq 0 ]; then
        echo "0.00"
    else
        echo "scale=2; $1 * 100 / $2" | bc
    fi
}

# Read the JSON file
json_file="test-results/coverage/coverage-summary.json"

if [ ! -f "$json_file" ]; then
    echo "Error: $json_file not found!"
    exit 1
fi

json_content=$(cat "$json_file")

if [ -z "$json_content" ]; then
    echo "Error: $json_file is empty!"
    exit 1
fi

# Print the table header
printf "%-40s %-10s %-10s %-10s %-10s %-10s\n" "Class Name" "Lines" "Covered" "Skipped" "Coverage %" "Status"
printf "%-40s %-10s %-10s %-10s %-10s %-10s\n" "----------" "-----" "-------" "-------" "----------" "------"

# Initialize variables for checking coverage
all_classes_pass=true
failed_classes=""
total_lines=0
total_covered=0
total_skipped=0

# Process each class and accumulate totals
while IFS= read -r line; do
    class=$(echo "$line" | cut -d' ' -f1)
    total=$(echo "$line" | cut -d' ' -f2)
    covered=$(echo "$line" | cut -d' ' -f3)
    skipped=$(echo "$line" | cut -d' ' -f4)
    percentage=$(echo "$line" | cut -d' ' -f5 | sed 's/%//')
    
    # Calculate status
    if (( $(echo "$percentage < 85" | bc -l) )); then
        status="FAIL"
        all_classes_pass=false
        failed_classes="$failed_classes$class (${percentage}%)\n"
    else
        status="PASS"
    fi
    
    printf "%-40s %-10s %-10s %-10s %-10s %-10s\n" "$class" "$total" "$covered" "$skipped" "$percentage%" "$status"
    
    # Accumulate totals
    total_lines=$((total_lines + total))
    total_covered=$((total_covered + covered))
    total_skipped=$((total_skipped + skipped))
done < <(echo "$json_content" | jq -r 'to_entries[] | select(.key != "total") | .key as $class | .value.lines | "\($class) \(.total) \(.covered) \(.skipped) \(.pct)"')

# Calculate overall coverage
overall_coverage=$(calculate_percentage $total_covered $total_lines)

# Print overall coverage
printf "%-40s %-10s %-10s %-10s %-10s %-10s\n" "TOTAL" "$total_lines" "$total_covered" "$total_skipped" "${overall_coverage}%" "-"

echo -e "\nOverall Coverage: ${overall_coverage}%"

# Check if overall coverage is less than 85%
if (( $(echo "$overall_coverage < 85" | bc -l) )); then
    echo "Build failed: Overall coverage (${overall_coverage}%) is below the 85% threshold."
    exit 1
fi

# Check if any class failed the coverage threshold
if [ "$all_classes_pass" = false ]; then
    echo -e "\nThe following classes have less than 85% coverage:"
    echo -e "$failed_classes"
    echo "Build failed due to insufficient test coverage in some classes."
    exit 1
else
    echo "All classes and overall coverage pass the 85% threshold. Build successful."
    exit 0
fi