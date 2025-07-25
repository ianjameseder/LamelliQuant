//=============================================================================================//
//																																																							
// ImageJ macro which segments the leading edge of lamellopodia kymographs																															
// Semi automated processing version of the macro																																															
//																																																						
// Created by Ian Eder and Abrahim Kashkoush																																		
// Modified for streamlined settings workflow																																		
//																																																						
// Version 1.1 6.22.25																																						
//              																																																	
//=============================================================================================//

// Default user settings for edge detection
threshold_min_default = 30;
threshold_max_default = 255;
minWidth_default = 20;
background_default = true;
rolling_ball_default = 25;
sorbel_default = true;

// Global batch settings (will be set after first image)
batch_threshold_min = 0;
batch_threshold_max = 0;
batch_minWidth = 0;
batch_background = false;
batch_rolling_ball = 0;
batch_sorbel = false;
batch_settings_initialized = false;

// Directory Structure
dir = getDirectory("Choose Directory");
list = getFileList(dir);
out = getDirectory("Choose output");

// Check that there are tiffs in the directory
number_files = lengthOf(list);
number_of_tif = 0;	
for (i=0; i<number_files; i++) {
	if (endsWith(list[i], ".tiff") || endsWith(list[i], ".tif")) {
		number_of_tif++;
	}
}
if (number_of_tif == 0) {
	exit("This folder doesn't contain any compatible files!");
}

// Main analysis loop, 1 iteration per tif/tiff file
for (i = 0; i < list.length; i++) {
	open(dir + list[i], "Default");
	originalTitle = getTitle();
	fileNoExtension = File.nameWithoutExtension;
	j = 0;

	do {
		Dialog.create("Next Step");
		Dialog.addChoice("What do you want to do?", newArray("Draw a line", "Open next movie"), "Draw another line");
		Dialog.show();
		choice = Dialog.getChoice();

		if (choice == "Draw a line") {
			selectWindow(originalTitle);
			waitForUser("Draw a line, then click OK to continue.");

			getPixelSize(unit, pixelWidth, pixelHeight);
			run("Reslice [/]...", "output=1.000 slice_count=1 avoid");
			run("Rotate 90 Degrees Left");
			
			Kymograph_Name = out + fileNoExtension + j;
			saveAs("Tiff", Kymograph_Name);
			rename("Reslice of " + fileNoExtension);
			

			// Determine which settings to use
			current_threshold_min = 0;
			current_threshold_max = 0;
			current_minWidth = 0;
			current_background = false;
			current_rolling_ball = 0;
			current_sorbel = false;

			if (!batch_settings_initialized) {
				// First image - get settings from user
				Dialog.create("LamelliQuant: Settings (First Image)");
				Dialog.addNumber("Minimum Threshold for Edge (Max = 255):", threshold_min_default);
				Dialog.addNumber("Maximum Threshold for Edge (Max = 255):", threshold_max_default);
				Dialog.addNumber("Minimum Size for particles:", minWidth_default);
				Dialog.addCheckbox("Background Subtraction?", background_default);
				Dialog.addNumber("Background Subtraction rolling ball:", rolling_ball_default);
				Dialog.addCheckbox("Sobel Edge Detection?", sorbel_default);
				Dialog.show();

				current_threshold_min = Dialog.getNumber();
				current_threshold_max = Dialog.getNumber();
				current_minWidth = Dialog.getNumber();
				current_background = Dialog.getCheckbox();
				current_rolling_ball = Dialog.getNumber();
				current_sorbel = Dialog.getCheckbox();
			} else {
				// Subsequent images - start with batch settings
				current_threshold_min = batch_threshold_min;
				current_threshold_max = batch_threshold_max;
				current_minWidth = batch_minWidth;
				current_background = batch_background;
				current_rolling_ball = batch_rolling_ball;
				current_sorbel = batch_sorbel;
			}

			good_job_edge_detection = false;

			while (good_job_edge_detection == false) {
				selectWindow("Reslice of " + fileNoExtension);

				run("Duplicate...", "title=Kymo");
				selectWindow("Kymo");
				run("8-bit");

				run("Duplicate...", "title=Copy");
				selectWindow("Copy");
				run("8-bit");

				if (current_background == true) {
					run("Subtract Background...", "rolling=" + current_rolling_ball + " light");
				}


				if (current_sorbel == true) {
					run("Find Edges");
				} else {
					run("Invert");
				}
				
				setThreshold(current_threshold_min, current_threshold_max, "raw");
				run("Analyze Particles...", "size=" + current_minWidth + "-Infinity pixel circularity=0-1.00 display summarize add composite");
				close("Results");
				close("Summary");

				roiManager("Deselect");
				roiManager("Combine");
				roiManager("Add");
				size = RoiManager.size;
				roiManager("Select", size - 1);

				saveName = out + fileNoExtension + "_line" + j + "_XY.csv";
				run("Save XY Coordinates...", "save=[" + saveName + "]");

				roiManager("Show All without labels");
				run("Flatten");
				run("8-bit");
				roi_image_name = "Reslice of " + fileNoExtension + "-1";
				run("Duplicate...", "title=ROI");
				close(roi_image_name);
				close("Copy-1");
				close("Copy");
				close("ROI Manager");

				run("Merge Channels...", "c4=Kymo c5=ROI create");
				Stack.setChannel(2);
				setMinAndMax(143, 255);
				rename("Edge Detection Validation");

				Dialog.create("Edge Detection");
				Dialog.addChoice("Does the edge detection look correct?", newArray("Yes", "No"), "Yes");
				Dialog.show();
				user_happy_edge_check = Dialog.getChoice();

				if (user_happy_edge_check == "Yes") {
					good_job_edge_detection = true;
					
					// If this is the first image, save settings as batch defaults
					if (!batch_settings_initialized) {
						batch_threshold_min = current_threshold_min;
						batch_threshold_max = current_threshold_max;
						batch_minWidth = current_minWidth;
						batch_background = current_background;
						batch_rolling_ball = current_rolling_ball;
						batch_sorbel = current_sorbel;
						batch_settings_initialized = true;
					}
					
					close("Reslice of " + fileNoExtension);
					close("Edge Detection Validation");
					break;
				} else {
					// User not happy - get new settings using current values
					selectWindow("Edge Detection Validation");
					close();

					Dialog.create("LamelliQuant: Adjust Settings");
					Dialog.addNumber("Minimum Threshold for Edge (Max = 255):", current_threshold_min);
					Dialog.addNumber("Maximum Threshold for Edge (Max = 255):", current_threshold_max);
					Dialog.addNumber("Minimum Width for particles:", current_minWidth);
					Dialog.addCheckbox("Background Subtraction?", current_background);
					Dialog.addNumber("Background Subtraction rolling ball:", current_rolling_ball);
					Dialog.addCheckbox("Sobel Edge Detection?", current_sorbel);
					Dialog.show();

					current_threshold_min = Dialog.getNumber();
					current_threshold_max = Dialog.getNumber();
					current_minWidth = Dialog.getNumber();
					current_background = Dialog.getCheckbox();
					current_rolling_ball = Dialog.getNumber();
					current_sorbel = Dialog.getCheckbox();
				}
			}
		}
		j++;
	} while (choice == "Draw a line");

	close("*");
}