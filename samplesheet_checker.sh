#!/usr/bin/env bash
# sudo apt-get install inotify-tools
# sudo apt-get install libnotify-bin

# Get path from command line

# "/home/graeme/Desktop/Test_name_checker/"
directory_to_watch=$1

############### Functions ###############

# Send warning messages
function raise_warning {

# Usage: raise_warning ${warning_message}
warning_message=${1}

# Print warning to command line (Useful for testing)
echo "$warning_message"
# Raise a local warning notification for the user on the workstation
notify-send -u critical "$warning_message"
# Trigger a remote alert in Slack & save warning to local log
# logger -s "$warning_message"
}

############### Run Program ###############


inotifywait -m $directory_to_watch -e create -e moved_to |
    while read -r file; do
        echo "Change detected:" # Useful when debugging to know that script is running correctly

        ## Check the saved sample sheet is named correctly so that metadata can be extracted by the pipeline
    	# bash's limited regex will not cope with the regex I created to match correctly formatted filenames: ^[0-9]{6}_(.*)_[0-9]{4}_(.*)_(?>.*?)SampleSheet\.csv$
    	# To overcome this we can split the filename based on the _ delimiter:
    	IFS='_' read -r -a array <<< "$file"
    	# We then reiterate over the array checking that each component of the file name matches the expected formatting and that the correct number of fields are present:
        if [[ ${array[0]} =~ [0-9]{6} && \
        	${array[2]} =~ [0-9]{4} && \
            ${array[4]} =~ "SampleSheet.csv" && \
            ${#array[@]} == 5 ]]; # Does the file match expected pattern
        then
            echo "$file matches pattern"
        else
            raise_warning "Sample sheet has been saved to workstation with the file name $file, which does not match the expected naming convention"
        fi

        ## Check that the contents of the SampleSheet pass some minimum criteria

        # Check that the SampleSheet has data in it
        lines_expected_in_file=20 # Header takes up 19 lines
        lines_detected_in_file=$(wc -l "$file")
        if [[ ! $lines_detected_in_file > $lines_expected_in_file ]];
        then
        	raise_warning "$file contains only $lines_detected_in_file lines, but expected at least $lines_expected_in_file for valid file"
        fi

        # Check the header headings are correct


        ## Check the data is well formatted
        # Check for trailing and leading spaces within fields

        # Check that sample names are formatted correctly

        # Check that indexes have been supplied correctly


        # sed 's/[ \t]*$//gp' 200515_NB551068_0327_AH5W7YBGXF_SampleSheet.csv
        # sed 's/[ \t]*$//gp' "$file"
        # sed 's/[ \t]*$//gp' "$file" | diff file.conf -
        # sed 's/domain1.com/domain2.com/gp' $file | diff file.conf -
    done