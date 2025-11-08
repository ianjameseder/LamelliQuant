//=============================================================================================//
//																																								
// ImageJ macro: Segment leading edge of lamellipodia kymographs using Sobel OR Canny
// User selects method at start, then all kymographs use that chosen method.
//
// Created by Ian Eder and Abrahim Kashkoush
// Modified to single-method selection
//
// Version 2.0 (Single Method Selection) — 2025-11-05
//=============================================================================================//


// =========================
// Defaults — SOBEL branch
// =========================
threshold_min_default = 30;
threshold_max_default = 255;
minWidth_default      = 20;
background_default    = true;
rolling_ball_default  = 25;
sorbel_default        = true; // (spelling preserved from original)

// =========================
// Defaults — CANNY branch
// =========================
canny_gaussian_default = 2.0;
canny_low_default      = 2.5;
canny_high_default     = 7.5;
canny_minWidth_default = 20;

// =========================
// Batch settings (persist after first accepted image)
// =========================
// Sobel batch
batch_threshold_min       = 0;
batch_threshold_max       = 0;
batch_minWidth            = 0;
batch_background          = false;
batch_rolling_ball        = 0;
batch_sorbel              = false;
batch_sobel_initialized   = false;

// Canny batch
batch_canny_gaussian      = 0;
batch_canny_low           = 0;
batch_canny_high          = 0;
batch_canny_minWidth      = 0;
batch_canny_initialized   = false;

// =========================
// Directory setup
// =========================
dir = getDirectory("Choose Directory");
list = getFileList(dir);
out  = getDirectory("Choose output");

// Sanity: must have tif/tiff files
number_files = lengthOf(list);
number_of_tif = 0; 
for (i=0; i<number_files; i++) {
	if (endsWith(list[i], ".tiff") || endsWith(list[i], ".tif")) number_of_tif++;
}
if (number_of_tif == 0) exit("This folder doesn't contain any compatible files!");

// =========================
// METHOD SELECTION (FIRST)
// =========================
Dialog.create("LamelliQuant: Method Selection");
Dialog.addChoice("Select Edge Detection Method:", newArray("Sobel", "Canny"), "Sobel");
Dialog.show();
selected_method = Dialog.getChoice();

// =========================
// Main loop (per movie)
// =========================
for (i = 0; i < list.length; i++) {
	open(dir + list[i], "Default");
	originalTitle = getTitle();
	fileNoExtension = File.nameWithoutExtension;
	j = 0;

	do {
		Dialog.create("Next Step");
		Dialog.addChoice("What do you want to do?", newArray("Draw a line", "Open next movie"), "Draw a line");
		Dialog.show();
		choice = Dialog.getChoice();

		if (choice == "Draw a line") {
			selectWindow(originalTitle);
			waitForUser("Draw a line, then click OK to continue.");

			getPixelSize(unit, pixelWidth, pixelHeight);
			run("Reslice [/]...", "output=1.000 slice_count=1 avoid");
			run("Rotate 90 Degrees Left");
			Kymograph_Name = out + fileNoExtension + j; // base kymograph save
			saveAs("Tiff", Kymograph_Name);
			currentKymoName = "Reslice of " + fileNoExtension;
			rename(currentKymoName);

			// --------------------------------------------------
			// Process using SELECTED METHOD ONLY
			// --------------------------------------------------
			if (selected_method == "Sobel") {
				// SOBEL workflow
				selectWindow(currentKymoName);
				run("Duplicate...", "title=Reslice_SOBEL");
				
				current_threshold_min = 0;
				current_threshold_max = 0;
				current_minWidth      = 0;
				current_background    = false;
				current_rolling_ball  = 0;
				current_sorbel        = false;

				if (!batch_sobel_initialized) {
					Dialog.create("LamelliQuant (Sobel): Settings — First Image");
					Dialog.addNumber("Minimum Threshold for Edge (Max = 255):", threshold_min_default);
					Dialog.addNumber("Maximum Threshold for Edge (Max = 255):", threshold_max_default);
					Dialog.addNumber("Minimum Size for particles:", minWidth_default);
					Dialog.addCheckbox("Background Subtraction?", background_default);
					Dialog.addNumber("Background Subtraction rolling ball:", rolling_ball_default);
					Dialog.addCheckbox("Sobel Edge Detection?", sorbel_default);
					Dialog.show();

					current_threshold_min = Dialog.getNumber();
					current_threshold_max = Dialog.getNumber();
					current_minWidth      = Dialog.getNumber();
					current_background    = Dialog.getCheckbox();
					current_rolling_ball  = Dialog.getNumber();
					current_sorbel        = Dialog.getCheckbox();
				} else {
					current_threshold_min = batch_threshold_min;
					current_threshold_max = batch_threshold_max;
					current_minWidth      = batch_minWidth;
					current_background    = batch_background;
					current_rolling_ball  = batch_rolling_ball;
					current_sorbel        = batch_sorbel;
				}

				good_job_edge_detection = false;
				while (good_job_edge_detection == false) {
					selectWindow("Reslice_SOBEL");

					run("Duplicate...", "title=Kymo_SOBEL");
					selectWindow("Kymo_SOBEL");
					run("8-bit");

					run("Duplicate...", "title=Copy_SOBEL");
					selectWindow("Copy_SOBEL");
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
					sizeS = RoiManager.size;
					roiManager("Select", sizeS - 1);

					saveNameS = out + fileNoExtension + "_Sobel_line" + j + "_XY.csv";
					run("Save XY Coordinates...", "save=[" + saveNameS + "]");

					roiManager("Show All without labels");
					run("Flatten");
					run("8-bit");
					roi_image_nameS = "Reslice_SOBEL-1";
					run("Duplicate...", "title=ROI_SOBEL");
					close(roi_image_nameS);
					close("Copy_SOBEL-1");
					close("Copy_SOBEL");
					close("ROI Manager");

					run("Merge Channels...", "c4=Kymo_SOBEL c5=ROI_SOBEL create");
					Stack.setChannel(2);
					setMinAndMax(143, 255);
					rename("Edge Detection Validation (Sobel)");

					Dialog.create("Edge Detection — Sobel");
					Dialog.addChoice("Does the edge detection look correct?", newArray("Yes", "No"), "Yes");
					Dialog.show();
					user_happy_edge_checkS = Dialog.getChoice();

					if (user_happy_edge_checkS == "Yes") {
						good_job_edge_detection = true;
						if (!batch_sobel_initialized) {
							batch_threshold_min = current_threshold_min;
							batch_threshold_max = current_threshold_max;
							batch_minWidth      = current_minWidth;
							batch_background    = current_background;
							batch_rolling_ball  = current_rolling_ball;
							batch_sorbel        = current_sorbel;
							batch_sobel_initialized = true;
						}
						close("Edge Detection Validation (Sobel)");
						close("Reslice_SOBEL");
					} else {
						selectWindow("Edge Detection Validation (Sobel)");
						close();

						Dialog.create("LamelliQuant (Sobel): Adjust Settings");
						Dialog.addNumber("Minimum Threshold for Edge (Max = 255):", current_threshold_min);
						Dialog.addNumber("Maximum Threshold for Edge (Max = 255):", current_threshold_max);
						Dialog.addNumber("Minimum Width for particles:", current_minWidth);
						Dialog.addCheckbox("Background Subtraction?", current_background);
						Dialog.addNumber("Background Subtraction rolling ball:", current_rolling_ball);
						Dialog.addCheckbox("Sobel Edge Detection?", current_sorbel);
						Dialog.show();

						current_threshold_min = Dialog.getNumber();
						current_threshold_max = Dialog.getNumber();
						current_minWidth      = Dialog.getNumber();
						current_background    = Dialog.getCheckbox();
						current_rolling_ball  = Dialog.getNumber();
						current_sorbel        = Dialog.getCheckbox();
					}
				}
			} else {
				// CANNY workflow
				selectWindow(currentKymoName);
				run("Duplicate...", "title=Reslice_CANNY");
				
				current_canny_gaussian = 0;
				current_canny_low      = 0;
				current_canny_high     = 0;
				current_canny_minWidth = 0;

				if (!batch_canny_initialized) {
					Dialog.create("LamelliQuant (Canny): Settings — First Image");
					Dialog.addNumber("Gaussian kernel radius:", canny_gaussian_default);
					Dialog.addNumber("Low threshold:",        canny_low_default);
					Dialog.addNumber("High threshold:",       canny_high_default);
					Dialog.addNumber("Minimum Size for particles:", canny_minWidth_default);
					Dialog.show();

					current_canny_gaussian = Dialog.getNumber();
					current_canny_low      = Dialog.getNumber();
					current_canny_high     = Dialog.getNumber();
					current_canny_minWidth = Dialog.getNumber();
				} else {
					current_canny_gaussian = batch_canny_gaussian;
					current_canny_low      = batch_canny_low;
					current_canny_high     = batch_canny_high;
					current_canny_minWidth = batch_canny_minWidth;
				}

				good_job_edge_detection = false;
				while (good_job_edge_detection == false) {
					selectWindow("Reslice_CANNY");

					run("Duplicate...", "title=Kymo_CANNY");
					selectWindow("Kymo_CANNY");
					run("8-bit");

					run("Duplicate...", "title=Copy_CANNY");
					selectWindow("Copy_CANNY");
					run("8-bit");

					// Call Canny Edge Detector plugin
					run("Canny Edge Detector", "gaussian=" + current_canny_gaussian + " low=" + current_canny_low + " high=" + current_canny_high);

					setThreshold(128, 255, "raw");
					run("Analyze Particles...", "size=" + current_canny_minWidth + "-Infinity pixel circularity=0-1.00 display summarize add composite");
					close("Results");
					close("Summary");

					roiManager("Deselect");
					roiManager("Combine");
					roiManager("Add");
					sizeC = RoiManager.size;
					roiManager("Select", sizeC - 1);

					saveNameC = out + fileNoExtension + "_Canny_line" + j + "_XY.csv";
					run("Save XY Coordinates...", "save=[" + saveNameC + "]");

					roiManager("Show All without labels");
					run("Flatten");
					run("8-bit");
					roi_image_nameC = "Reslice_CANNY-1";
					run("Duplicate...", "title=ROI_CANNY");
					close(roi_image_nameC);
					close("Copy_CANNY-1");
					close("Copy_CANNY");
					close("ROI Manager");

					run("Merge Channels...", "c4=Kymo_CANNY c5=ROI_CANNY create");
					Stack.setChannel(2);
					setMinAndMax(143, 255);
					rename("Edge Detection Validation (Canny)");

					Dialog.create("Edge Detection — Canny");
					Dialog.addChoice("Does the edge detection look correct?", newArray("Yes", "No"), "Yes");
					Dialog.show();
					user_happy_edge_checkC = Dialog.getChoice();

					if (user_happy_edge_checkC == "Yes") {
						good_job_edge_detection = true;
						if (!batch_canny_initialized) {
							batch_canny_gaussian = current_canny_gaussian;
							batch_canny_low      = current_canny_low;
							batch_canny_high     = current_canny_high;
							batch_canny_minWidth = current_canny_minWidth;
							batch_canny_initialized = true;
						}
						close("Edge Detection Validation (Canny)");
						close("Reslice_CANNY");
					} else {
						selectWindow("Edge Detection Validation (Canny)");
						close();

						Dialog.create("LamelliQuant (Canny): Adjust Settings");
						Dialog.addNumber("Gaussian kernel radius:", current_canny_gaussian);
						Dialog.addNumber("Low threshold:",        current_canny_low);
						Dialog.addNumber("High threshold:",       current_canny_high);
						Dialog.addNumber("Minimum Size for particles:", current_canny_minWidth);
						Dialog.show();

						current_canny_gaussian = Dialog.getNumber();
						current_canny_low      = Dialog.getNumber();
						current_canny_high     = Dialog.getNumber();
						current_canny_minWidth = Dialog.getNumber();
					}
				}
			}

			// Close the base kymograph after processing
			close(currentKymoName);
		}
		j++;
	} while (choice == "Draw a line");

	close("*");
}