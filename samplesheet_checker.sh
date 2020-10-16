#!/usr/bin/env bash

# Required packages:
# sudo apt-get install inotify-tools
# sudo apt-get install libnotify-bin

# Get path from command line

# "/home/graeme/Desktop/Test_name_checker/"
directory_to_watch=$1
warning_message_array=() # Initiate empty array

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

# Send warning messages
function set_warning_message {

# Usage: raise_warning ${warning_message}
warning_message_array=${1}
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
        # Extract first column to array
        mapfile -t first_col_array < <(cut -d ',' -f1 "$file" | head -n 19)
        # Check headings are correct:
        if [[ ${first_col_array[0]} == "[Header]" && \
        ${first_col_array[1]} == "IEMFileVersion" && \
        ${first_col_array[2]} == "Investigator Name" && \
        ${first_col_array[3]} == "Experiment Name" && \
        ${first_col_array[4]} == "Date" && \
        ${first_col_array[5]} == "Workflow" && \
        ${first_col_array[6]} == "Application" && \
        ${first_col_array[7]} == "Assay" && \
        ${first_col_array[8]} == "Description" && \
        ${first_col_array[9]} == "Chemistry" && \
        ${first_col_array[11]} == "[Reads]" && \
        ${first_col_array[15]} == "[Settings]" && \
        ${first_col_array[17]} == "[Data]" && \
        ${first_col_array[18]} == "Sample_ID" ]];
        then
            echo "Row names in headers for $file are correct"
        else
            raise_warning "$file has incorrect heading titles in header"
        fi

        # Check read lengths have been entered correctly (length 300-999):
        if [[ ${first_col_array[12]} =~ [0-9]{3}] || ${first_col_array[13]} =~ [0-9]{3}] ]];
        then
            echo "Read lengths are within plausible values"
        else
            raise_warning "$file has no or incorrect read lengths recorded"
        fi

        # Check that the row headings are correct:
        row_names=$("$file" | head -n 19 | tail -n 1)
        if [[ $row_names == "Sample_ID,Sample_Name,Sample_Plate,Sample_Well,I7_Index_ID,index,I5_Index_ID,index2,Sample_Project,Description" ]];
        then
            echo "Spreadsheet row names are correct"
        else
            raise_warning "$file has incorrect row names"
        fi
        # Check that sample names are formatted correctly


        # Check that indexes have been input correctly

    done