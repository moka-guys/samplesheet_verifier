#!/usr/bin/env bash

# Required packages:
# sudo apt-get install inotify-tools
# sudo apt-get install libnotify-bin

# Get path from command line

# "/home/graeme/Desktop/Test_name_checker/"

# TODO Make libnotify optional as nobody will be observing the workstation during sequencing run

while getopts ":r:s:" opt; do
    case ${opt} in
    r ) # process option h
        runfolder_to_watch=$OPTARG
        echo $runfolder_to_watch
      ;;
    s ) # process option s
        samplesheet_folder=$OPTARG
        echo $samplesheet_folder
      ;;
    \? ) echo "Usage: samplesheet_checker.sh [-r] [-s] [-l]"
         echo "-r Folder holding the Runfolder directories"
         echo "-s Folder holding the SampleSheets for each run"
         echo "bash samplesheet_checker.sh -r /home/mokaguys/runfolders -s /home/mokaguys/runfolders/samplesheets"
      ;;
  esac
done
shift $((OPTIND -1))

# TODO Add testing flag to allow continuous integration testing

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

# TODO: Consider placing filter to only run main tests on csv files - should through a limited if non-CSV file detected
# ()

inotifywait -d "$runfolder_to_watch" -e create -e moved_to |
    while IFS= read -r file; do
        echo "Change detected:" # Useful when debugging to know that script is running
        # Parse filename
        filepath=$(echo "$file" | awk -F " " '{print $1}')
        file_name=$(echo "$file" | awk -F " " '{print $NF}')
        absolute_file_path="$filepath$file_name"

        ## Check the saved sample sheet is named correctly so that metadata can be extracted by the pipeline
    	# bash's limited regex will not cope with the regex I created to match correctly formatted filenames: ^[0-9]{6}_(.*)_[0-9]{4}_(.*)_(?>.*?)SampleSheet\.csv$
    	# To overcome this we can split the filename based on the _ delimiter:
    	IFS='_' read -r -a array <<< "$file_name"

    	# We then reiterate over the array checking that each component of the file name matches the expected formatting and that the correct number of fields are present:
        if [[ ${array[0]} =~ [0-9]{6} && \
        	${array[2]} =~ [0-9]{4} && \
            ${array[4]} == "SampleSheet.csv" && \
            ${#array[@]} == "5" ]]; # Does the file match expected pattern
        then
            echo "$file_name matches pattern"
        else
            raise_warning "SAMPLESHEET ERROR: Sample sheet has been saved to workstation with the file name $file_name, which does not match the expected naming convention"
        fi

        ## Check that the contents of the SampleSheet pass some minimum criteria

        # Check that the file is not empty:
        if [[ ! -s $absolute_file_path ]];
        then
            raise_warning "$file_name, is an empty file";
        else
            echo "$file_name contains data";
            # Run further checks on the formatting of the data
            # Check that the SampleSheet has data in it
            lines_expected_in_file=20 # Header takes up 19 lines
            lines_detected_in_file=$(wc -l "$absolute_file_path")
            if [[ ! $lines_detected_in_file > $lines_expected_in_file ]];
            then
                raise_warning "SAMPLESHEET ERROR: $file_name contains only $lines_detected_in_file lines, but expected at least $lines_expected_in_file for valid file";

                # Check the header headings are correct
                # Extract first column into array
                else
                mapfile -t first_col_array < <(cut -d ',' -f1 "$absolute_file_path" | head -n 19)
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
                        echo "Row names in headers for $file_name are correct"
                    else
                        raise_warning "SAMPLESHEET ERROR: $file_name has incorrect heading titles in header"
                    fi

                    # Check read lengths have been entered correctly (length 100-999): TODO Can probably improve this test
                    if [[ ${first_col_array[12]} =~ [0-9]{3}] && ${first_col_array[13]} =~ [0-9]{3}] ]];
                    then
                        echo "Read lengths are within expected values"
                    else
                        raise_warning "SAMPLESHEET ERROR: $file_name has no, or incorrect, read lengths recorded"
                    fi

                    # Check that the row headings are correct:
                    row_names=$("$absolute_file_path" head -n 19 | tail -n 1)
                    echo row_names
                    if [[ $row_names == "Sample_ID,Sample_Name,Sample_Plate,Sample_Well,I7_Index_ID,index,I5_Index_ID,index2,Sample_Project,Description" ]];
                    then
                        echo "Spreadsheet row names are correct"
                    else
                        raise_warning "SAMPLESHEET ERROR: $file_name has incorrect row names"
                    fi;
                # Check that sample names are formatted correctly (read in lines and compare to regex)
                data_correct=1 # Set as true - used to raise single warning no matter how many lines in the file fail

                    # TODO Add log file to write this info to so that correcting broken sample sheets is easier
                    while IFS= read -r  line; do
                        sample_name_pattern="^[A-Z, 0-9]*_[0-9]{2}_[0-9]*_[A-Z]{2}_[MFU]_[A-Z,0-9]*_Pan[0-9]*,"
                        if [[ $(echo "$line" | cut -d ',' -f1) =~ $sample_name_pattern ]]; then echo "$line has incorrect sample name in col 1" && data_correct=0; fi
                        if [[ $(echo "$line" | cut -d ',' -f2) =~ $sample_name_pattern ]]; then echo "$line has incorrect sample name in col 2" && data_correct=0; fi
                        # Check that indexes look like DNA sequences:
                        if [[ $(echo "$line" | cut -d ',' -f6) =~ ^[AGCT]*$ ]]; then echo "$line has invalid Index in col 6" && data_correct=0; fi
                        if [[ $(echo "$line" | cut -d ',' -f8) =~ ^[AGCT]*$ ]]; then echo "$line has invalid Index in col 8" && data_correct=0; fi
                    done  < "$absolute_file_path"
                if [[ "$data_correct" == 0 ]]; then raise_warning "SAMPLESHEET ERROR: $file_name has errors in data, see log for details"; fi
            fi
        fi
    done
