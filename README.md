# samplesheet_verifier

This script is designed to run on a linux system and monitors a directory for changes.  If a Illumina Runfolder is saved to the directory the script checkes for a matching Illumina Runsheet parsing the file name and contents - upon finding any issues with the format which will cause problems with our pipeline it:
* Notifys the local user that there is an issue with the SampleSheet which will delay the run, giving them a chance to rectify the issues (Optional).
* Gives early warning to the Bioinformatics team via the moka-alerts slack channel.
* Writes the Error Message to the systemlog so that such errors are tracked, allowing appropriate training to directed to lab staff as needed.
This script should be reviewed and expanded every time their is an issue with a sample sheet which reachs the pipeline.  By taking a "No broken windows" approach we can use this script as part of a process to help prevent delays due to incorrect samplesheets.

## Requirements
* bash environment
* inotify-tools
* libnotify-bin (Optional)

## How does samplesheet_verifier work
###  Inputs
* A directory where Illumina Runfolders are saved
* A directory where Illumina formatted SampleSheets are saved

### Usage

bash samplesheet_checker.sh -r /home/mokaguys/runfolders -s /home/mokaguys/runfolders/samplesheets

(This script runs as a daemon in the background and the command would typically be set to run periodically by a chron job.) TODO: Check how to terminate inotify before restarting

### 

This script runs as a daemon in the background, monitoring a directory for Illumina Runfolders.  When a new runfolder is detected it looks in the SampleSheet folder for a matching samplesheet.  It parses the file name and contents and uses a regex to compare against expected patterns.  If an error is detected (which will likely cause an error in the pipeline, delaying results) an optional notification can be sent to the monitor using libnotify and a warning is sent to the Syslog using logger, which is setup to fire a warning to the Bioinformatics team via a Slack channel.

Writing to Syslog allows easier troubleshooting of the errors as well as allowing the extent of errors to be monitored.

###

NOTE: If a badly formatted sampleSheet is not detected by this script please raise an issue in this repo and provide the Bioinformatics team with the incorrectly formatted CSV file so that this script can be improved.
