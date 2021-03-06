currentFolder = getDirectory("startup");
var mark;
var markCount = 0;
// Filter out the ROIs that has pixel value 255, which are the white shadow. 
function filter255(array) {
	mark = newArray(array.length);
	markCount = 0;
	for (l = 0; l < array.length; l++) {
		line = split(array[l], " ");
//		print(getValue(parseInt(line[2]), parseInt(line[3])));
		if (getValue(parseInt(line[2]), parseInt(line[3])) == 255) {
			mark[l] = 1;
			if (l < array.length - 1) {
				nextLine = split(array[l + 1], " ");
			} else {
				break;	
			}
			if (parseInt(line[0]) != parseInt(nextLine[0])) {
				markCount++;
			}
		}	
	}
}


// A function to draw the ROIs in the first slice as preview. 
function preview(con_th) {
	f = File.openAsString(folder + "medium_products/sorted_roi.txt");
	lines = split(f, "\n");
	filter255(lines);
	setSlice(1);

	// Filter out border ROIs
	rr = 0.03;
	for (l = 0; l < lines.length; l++) {
		line = split(lines[l], " ");
		if (isBorder(parseInt(line[2]), parseInt(line[3]), width, height, rr) == true) {
			mark[l] = 1;
		}
	}

	// Filter out ROIs based on present slides number. 
	repC = 0;
	start = 0;
	final = 0;
	const = "0";
	for (l = 0; l < lines.length; l++) {
		line = split(lines[l], " ");
		if (line[0] == const) {
			repC++;
			final = l;
		} else {
			if (repC < con_th) {
				for (tt = start; tt <= final; tt++) {
					mark[tt] = 1;	
				}
			}
			repC = 0;
			const = line[0];
			start = l;
			final = l;
		}
	}
	
	
	// draw all the selected roi in the first slice as a preview. 
	for (sInd = 0; sInd < lines.length; sInd++) {
		if (mark[sInd] == 1) {
			continue;	
		}
		temp = lines[sInd];
		slice = split(temp, " ");
		if (slice[1] == 0) {
			x1 = round(slice[2] - ovalRadius);
			xC = ovalRadius * 2;
			y1 = round(slice[3] - ovalRadius);
			yC = ovalRadius * 2;
			makeOval(x1, y1, xC, yC);
			roiManager("add");
		}
	}

	roiManager("Deselect");	
 
	roiManager("Show All");
	temp = lines[lines.length - 1];
	roiNums = split(temp, " ");
	spotNum = parseInt(roiNums[0]) - markCount;
}

// Filter out v value in the list l.
function filterExtreme(l, v) {
	result = newArray(0);
	for (i = 0; i < l.length; i++) {
		if (l[i] != v) {
			result = Array.concat(result, l[i]);
		}	
	}	
	return result;
}

// Check whether the ROI is on the border. If so, it is highly possible to be an outlier. 
function isBorder(xx, yy, width, height, ratio) {
	if (xx < width * ratio || xx > width * (1 - ratio) || yy < height * ratio || yy > height * (1 - ratio)) {
		return true	
	}
	return false
}

// Return a magnifier for arrow length. 
function dynamic_magnifier(x, base) {
	if (x >= 0) {
		return base * (1 - 0.8 * pow(PI, -1.5 * x))
	} else {
		return - base * (1 - 0.8 * pow(PI, -1.5 * abs(x)))	
	}
}


function filteredROICount(sorted_roi_list, mark_list) {
	if (sorted_roi_list.length != mark_list.length) {
		exit("The roi list length doesn't equal to mark list length.");
	}
	count = 0;
	for (i = 1; i < sorted_roi_list.length; i++) {
		if (mark_list[i] == 1) {
			continue;	
		} 
		last = split(sorted_roi_list[i - 1], " ");
		curr = split(sorted_roi_list[i], " ");
		if (last[0] != curr[0]) {
			count++;
		}
	}	
	return count
}


// A preview window to let users decide if the number of ROIs is acceptable. 
var f;
var lines;
var folder;
var animation;
macro "workStage" {
	run("8-bit");
//	setOption("Min & max gray value", true);
	setOption("mean", true);
	setOption("Std", true);
	run("Set Measurements...", "mean standard min centroid redirect=None decimal=3");
	folder = getDirectory("Choose a Directory");
	File.saveString(folder, currentFolder + "Working_Directory.txt");
	isMp = File.isDirectory(folder + "medium_products/");
	
	if (isMp == 0) {
		File.makeDirectory(folder + "medium_products/");	
	}

	roiManager("reset");
	// Calculate oval redius. 
	getDimensions(width, height, channels, slices, frames);
	sliceCount = 0;
	if (slices >= frames) {
		sliceCount = slices;
	} else {
		sliceCount = frames;	
	}
	var ovalRadius = 0;
	refRadius = 11;
	refWidth = 1000;
	refHeight = 700;
	ovalRadius = round(sqrt(pow(refRadius, 2) * ((width * height) / (refWidth * refHeight))));


	originId = getImageID();
	satisfaction = false;
	
	while (satisfaction == false) {
		roiManager("reset");
		Dialog.create("ROI selection input");
		Dialog.addMessage("What is your expected ROI radius?");
		Dialog.addNumber("\t\t\t\t\t\t", ovalRadius, 0, 5, "pixels");
		Dialog.addMessage("What is the minimum duration for a selected ROI?");
		Dialog.addSlider("\t\t\t\t\t\t", 0, sliceCount, sliceCount * 0.75);
//		Dialog.addMessage("What is the quality threshold for ROI detection? (smaller threhsold generates more ROIs)");
//		Dialog.addNumber("\t\t\t\t\t\t", 0, 1, 5, "");
		Dialog.show();
		ovalRadius = Dialog.getNumber();
		con_th = Dialog.getNumber();
//		quality_th = Dialog.getNumber();
		File.saveString(d2s(ovalRadius, 0), folder + "medium_products/approx_roi_radius.txt");
//		File.saveString(d2s(quality_th, 1), folder + "medium_products/quality_threshold.txt");
		
		// Get the ROI track mate data by calling 2 functions. 
		selectImage(originId);
		run("get track mate data");
		run("roi xml to txt");
		run("movement smoother");
		
		preview(con_th);
		Dialog.create("Preview");
		Dialog.addCheckbox("Satisfied ?", false);
		Dialog.show();
		satisfaction = Dialog.getCheckbox();
	}

	f = File.openAsString(folder + "medium_products/sorted_roi.txt");
	lines = split(f, "\n");
	numRoi = filteredROICount(lines, mark);
	
	Dialog.create("Analysis parameters input");
	Dialog.addRadioButtonGroup("\t Do you want to draw arrow animation?", newArray("Yes", "No"), 0, 2, "Yes");
	Dialog.addMessage("Output saving settings");
	Dialog.addCheckbox("\t\t\t\t\t\tSave the result table as excel?", 0);
	Dialog.addCheckbox("\t\t\t\t\t\tSave the arrows animation?", 0);
	Dialog.addMessage(numRoi + " ROIs left after filtering. How many layers do you want to separate the results?");
	Dialog.addSlider("\t\t\t\t\t\t", 0, numRoi, 3);
	Dialog.show();
	animation = Dialog.getRadioButton();
	excelB = Dialog.getCheckbox();
	arrowB = Dialog.getCheckbox();
	ll = Dialog.getNumber();


	if (animation == "Yes") {
		Dialog.create("Arrow Animation Settings");
		Dialog.addNumber("Arrow magnifier ", 15);
		Dialog.addNumber("Minimum movement length:", 0.1);
		Dialog.addNumber("Maximum movement length:", 4);
		arrow_types = newArray(2);
		arrow_types[0] = "Between frames";
		arrow_types[1] = "Still start";
		Dialog.addRadioButtonGroup("Arrow type", arrow_types, 2, 1, "Between frames");
		Dialog.show();
		
		base = Dialog.getNumber();
		min_square_mov = pow(Dialog.getNumber(), 2);
		max_square_mov = pow(Dialog.getNumber(), 2);
		a_t = Dialog.getRadioButton();
		run("Duplicate...", "title=Stage duplicate");
		selectWindow("Stage");

		if (a_t == "Still start") {
			for (i = 1; i < lines.length; i++ ) {
				if (mark[i] == 1) {
					continue;	
				}
				reference = split(lines[i], " ");
				break;
			}
		}
		
		for (i = 1; i < lines.length; i++ ) {
			if (mark[i] == 1) {
				continue;	
			}
			lastL = split(lines[i - 1], " ");
			currL = split(lines[i], " ");
			
			if (lastL[0] == currL[0] && pow(currL[2] - lastL[2], 2) + pow(currL[3] - lastL[3], 2) > min_square_mov && lastL[0] == currL[0] && pow(currL[2] - lastL[2], 2) + pow(currL[3] - lastL[3], 2) < max_square_mov) {
				setSlice(currL[1] + 1);
				if (a_t == "Still start") {
					if (pow(currL[2] - reference[2], 2) + pow(currL[3] - reference[3], 2) > max_square_mov){
						reference = currL;
						continue;	
					}
					makeArrow(round(reference[2]), round(reference[3]), round(parseFloat(reference[2]) + dynamic_magnifier(parseFloat(currL[2]) - parseFloat(reference[2]), base)), round(parseFloat(reference[3]) + dynamic_magnifier(parseFloat(currL[3]) - parseFloat(reference[3]), base)), "filled");
				} else if (a_t == "Between frames") {
					makeArrow(round(lastL[2]), round(lastL[3]), round(parseFloat(lastL[2]) + dynamic_magnifier(parseFloat(currL[2]) - parseFloat(lastL[2]), base)), round(parseFloat(lastL[3]) + dynamic_magnifier(parseFloat(currL[3]) - parseFloat(lastL[3]), base)), "filled");
				}
				run("Arrow Tool...", "width=1 size=4 color=Green style=Open");	
				Roi.setStrokeColor("green");
				run("Add Selection...");	
				close("Exception");
			} else if (lastL[0] != currL[0] && a_t == "Still start") {
				reference = currL;
			}
			
		}
	}

	close("Results");
	roiManager("Deselect");
	roiManager("Measure");
	
	for (i = 1; i < lines.length; i++ ) {
		if (i < sliceCount) {
			setResult("Slice Number", i - 1, i + 1);
		}
		
		lastL = split(lines[i - 1], " ");
		currL = split(lines[i], " ");
		if (mark[i] == 1) {
			continue;	
		}
		if (parseInt(currL[1]) < sliceCount - 1 && i != (lines.length - 1)) {
			nextL = split(lines[i + 1], " ");
		}
		if (parseInt(currL[1]) < sliceCount - 1 && lastL[0] == currL[0]) {
			dir = getDirection(parseFloat(currL[2]), parseFloat(currL[3]), parseFloat(nextL[2]), parseFloat(nextL[3]), parseFloat(lastL[2]), parseFloat(lastL[3]), parseFloat(currL[2]), parseFloat(currL[3]));
			bright = getPixel(lastL[2], lastL[3]);
			
			setResult("pixel_value_" + currL[0], lastL[1], bright);
			setResult("start_x_" + currL[0], lastL[1], lastL[2]);
			setResult("start_y_" + currL[0], lastL[1], lastL[3]);
			setResult("end_x_" + currL[0], lastL[1], currL[2]);
			setResult("end_y_" + currL[0], lastL[1], currL[3]);
			setResult("movement_length_" + currL[0], lastL[1], sqrt(pow(currL[2] - lastL[2], 2) + pow(currL[3] - lastL[3], 2)));
			setResult("direction_change_" + currL[0] + "_degree", lastL[1], dir);
			if (parseInt(currL[1]) - parseInt(lastL[1]) > 1) {
				for (ind = 1; ind < parseInt(currL[1]) - parseInt(lastL[1]); ind++) {
					setResult("pixel_value_" + currL[0], lastL[1] + ind, NaN);
					setResult("start_x_" + currL[0], lastL[1] + ind, NaN);
					setResult("start_y_" + currL[0], lastL[1] + ind, NaN);
					setResult("end_x_" + currL[0], lastL[1] + ind, NaN);
					setResult("end_y_" + currL[0], lastL[1] + ind, NaN);
					setResult("movement_length_" + currL[0], lastL[1] + ind, NaN);
					setResult("direction_change_" + currL[0] + "_degree", lastL[1] + ind, NaN);
				}	
			}
		}
	}

	heads = Table.headings;
	heads = split(heads, "	");
	selected = newArray(0);
	tt = 0;
	for (i = 0; i < heads.length; i++) {
		sep = split(heads[i], "_");
		if (sep[0] == "pixel") {
//			data = Table.getColumn(heads[i]);
//			data = filterExtreme(data, 0);
//			Array.getStatistics(data, min, max, mean, stdDev);
//			std_data = newArray(data.length);
//			for (j = 0; j < std_data.length; j++) {
//				std_data[j] = (data[j] - mean) / stdDev;
//			}
//			The ROI satisfied the spike_filter will be marked * in the begining.
			selected = Array.concat(selected, sep[2]);
//			if (spike_filter(std_data, spike_num, persis, spike_gap, exact) == true) {
//				selected = Array.concat(selected, sep[2]);
//				Table.renameColumn("pixel_value_" + sep[2], "*pixel_value_" + sep[2]);
//				Table.renameColumn("start_x_" + sep[2], "*start_x_" + sep[2]);
//				Table.renameColumn("start_y_" + sep[2], "*start_y_" + sep[2]);
//				Table.renameColumn("end_x_" + sep[2], "*end_x_" + sep[2]);
//				Table.renameColumn("end_y_" + sep[2], "*end_y_" + sep[2]);
//				Table.renameColumn("movement_length_" + sep[2], "*movement_length_" + sep[2]);
//				Table.renameColumn("direction_change_" + sep[2] + "_degree", "*direction_change_" + sep[2] + "_degree");
//			}
		}
		tt++;
	}

	
	if (excelB == 1) {
		isRe = File.isDirectory(folder + "results/");
		if (isRe == 0) {
			File.makeDirectory(folder + "results/");
			isReEx = File.isDirectory(folder + "results/excel_data/");
			if (isReEx == 0) {
				File.makeDirectory(folder + "results/excel_data/");
			}
		} else {
			isReEx = File.isDirectory(folder + "results/excel_data/");
			if (isReEx == 0) {
				File.makeDirectory(folder + "results/excel_data/");
			}
		}
		selectImage(originId);
		temp = getInfo("image.filename");
		if (temp == "") {
			imageName = "untitled";
		} else {
			wholeName = split(temp, ".");
			imageName = wholeName[0];
		}
		
		
		run("Read and Write Excel", "file=[" + folder + "results/excel_data/" + imageName + "_data.xlsx]");
	}
	if (arrowB == 1) {
		isRe = File.isDirectory(folder + "results/");
		if (isRe == 0) {
			File.makeDirectory(folder + "results/");
			isReAr = File.isDirectory(folder + "results/arrows_animations/");
			if (isReAr == 0) {
				File.makeDirectory(folder + "results/arrows_animations/");	
			}
		} else {
			isReAr = File.isDirectory(folder + "results/arrows_animations/");
			if (isReAr == 0) {
				File.makeDirectory(folder + "results/arrows_animations/");	
			}	
		}
		selectImage(originId);
		temp = getInfo("image.filename");
		wholeName = split(temp, ".");
		imageName = wholeName[0];
		selectWindow("Stage");
		saveAs("Tiff", folder + "results/arrows_animations/" + imageName + "_stage");
	}

	
	ranges = newArray(selected.length);
	for (z = 0; z < selected.length; z++) {
//		data = Table.getColumn("*movement_length_" + selected[z]);
		data = Table.getColumn("movement_length_" + selected[z]);
		Array.getStatistics(data, min, max, mean, stdDev);
		range = max - min;
		ranges[z] = range;
	}

	IJ.renameResults("output_data");
	ranges = Array.sort(ranges);
	start = 0;
	cap = floor(ranges.length * (1 / ll) + 1);
	mins = newArray(ll);
	maxs = newArray(ll);
	means = newArray(ll);
	stds = newArray(ll);
	nums = newArray(ll);
	ini = ranges.length % cap;
	for (i = 0; i < ll; i++) {
		if (i == 0) {
			curr = 	Array.slice(ranges, start, start + ini);
		} else {
			curr = 	Array.slice(ranges, start, start + cap);
		}
		Array.getStatistics(curr, min, max, mean, stdDev);
		mins[i] = min;
		maxs[i] = max;
		means[i] = mean;
		stds[i] = stdDev;
		nums[i] = curr.length;
		if (i == 0) {
			start = start + ini;	
		} else {
			start = start + cap;
		}
	}
	
	Table.create("Movement_Layers");
	Table.setColumn("num", nums);
	Table.setColumn("mean", means);
	Table.setColumn("stdDev", stds);
	Table.setColumn("max", maxs);
	Table.setColumn("min", mins);
}

function getDirection(oriX, oriY, desX, desY, formOriX, formOriY, formDesX, formDesY) {

	if ((oriX == desX && oriY == desY) || (formOriX == formDesX && formOriY == formDesY)) {
		return NaN;	
	}

	infinity = 1/0;
	
	if (formDesX - formOriX == 0) {
		if (formDesY - formOriY < 0) {
			k1 = infinity;	
		} else {
			k1 = -infinity;
		}
	} else {
		k1 = (formDesY - formOriY) / (formDesX - formOriX);		
	}

	b1 = formOriY - k1 * formOriX;

	if (desX - oriX == 0) {
		if (desY - oriY < 0) {
			k2 = infinity;	
		} else {
			k2 = -infinity;
		}
	} else {
		k2 = (desY - oriY) / (desX - oriX);		
	}
	
	b2 = oriY - k2 * oriX;
	
//	constant = (1 - k1 * k2) / (k1 + k2);
//	bisecK = sqrt(1 + pow(constant, 2)) - constant;

	formDist = sqrt(pow(formDesX - formOriX, 2) + pow(formDesY - formOriY, 2));
	currDist = sqrt(pow(desX - oriX, 2) + pow(desY - oriY, 2));
	formOriToCurrDes = sqrt(pow(desX - formOriX, 2) + pow(desY - formOriY, 2));

	cosDegree = (pow(formDist, 2) + pow(currDist, 2) - pow(formOriToCurrDes, 2)) / (2 * formDist * currDist);
	degree = 180 - acos(cosDegree) * (180 / PI);

	deltaX = formDesX - formOriX;
	deltaY = formDesY - formOriY;
	
	if (deltaX > 0) {
		if (desY <= desX * k1 + b1) {
			return degree;	
		} else {
			return -degree;	
		}
	} else if (deltaX < 0) {
		if (desY >= desX * k1 + b1) {
			return degree;	
		} else {
			return -degree;	
		}	
	} else {
		if (deltaY < 0) {
			if (desX < oriX) {
				return degree;	
			} else {
				return -degree;	
			}
		} else {
			if (desX > oriX) {
				return degree;	
			} else {
				return -degree;	
			}
		}
	}
}
	
