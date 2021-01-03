-- Noteblock Studio file (.nbs) player for FTB: Revelations
-- Original Program by James0x57
-- Updated by Tan Huynh
-- Noteblock Studio by _Davve_ - http://www.minecraftforum.net/topic/136749-minecraft-note-block-studio-150000-downloads/
-- Computronics by asie, maintained by Vexatos - https://wiki.vexatos.com/wiki:computronics
-- CC: Tweaked by SquidDev - https://tweaked.cc/

local args = {...};
local menu = {};
local box = nil;
local song = nil;
local action = 'mainList';
local isPlaying = false;
local stopFlag = false;
local settings = { rptMode = "allRandom"; }; -- "repeat" is reserved in lua
local maxtoshow = 15;

if turtle ~= nil then
	maxtoshow = 9;
end

function mountIronNoteblock()
	for _,side in ipairs({"left"; "right"; "back"; "bottom"; "top"; "front"}) do
		if peripheral.getType(side) == "iron_noteblock" then
			box = peripheral.wrap(side);
			return side;
		end
	end
	return nil;
end

function newSong(x, selectedIndex)
	return {
		fh = x;
		index = selectedIndex;
		length = 0;
		height = 0;
		name = "";
		author = "";
		originalAuthor = "";
		description = "";
		tempo = 10.00; --tks per second
		autoSaving = 0;
		autoSaveDur = 0;
		timeSig = 4;
		minSpent = 0;
		leftClicks = 0;
		rightClicks = 0;
		blocksAdded = 0;
		blocksRemoved = 0;
		midi = "";
		music = { wait={}; inst={}; note={}; };
	};
end

function loadMenu(fromDir)
	if fs.isDir(fromDir) then
		for _, file in ipairs(fs.list(fromDir)) do
		  if fs.isDir(file) == false and string.find(file, ".nbs", -4, true) ~= nil then -- if file and ends in ".nbs"
		  	menu[#menu+1] = { d=fromDir; fn=file };
		  end
		end
	end
	return #menu;
end

function readInt(fh) --little endian, fh is open in rb mode
	local ret = 0;
	local x = fh.read();
	if x == nil then return nil; end
	ret = x;
	x = fh.read();
	if x == nil then return nil; end
	ret = (x * 0x100) + ret;
	x = fh.read();
	if x == nil then return nil; end
	ret = (x * 0x10000) + ret;
	x = fh.read();
	if x == nil then return nil; end
	ret = (x * 0x1000000) + ret;
	return ret;
end

function readShort(fh) --little endian, fh is open in rb mode
	local ret = 0;
	local x = fh.read();
	if x == nil then return nil; end
	ret = x;
	x = fh.read();
	if x == nil then return nil; end
	ret = (x * 0x100) + ret;
	return ret;
end

function readString(fh, len) --fh is open in rb mode
	local ret = "";
	local x = 0;
	for i = 1, len do
		x = fh.read();
		if x == nil then return nil; end
		ret = ret .. string.char(x);
	end
	return ret;
end

function readHeader()
	song.length 		= readShort(song.fh);
	song.height 		= readShort(song.fh);
	song.name 			= readString(song.fh, readInt(song.fh));
	song.author 		= readString(song.fh, readInt(song.fh));
	song.originalAuthor = readString(song.fh, readInt(song.fh));
	song.description 	= readString(song.fh, readInt(song.fh));
	song.tempo 			= 1.000 / ( readShort(song.fh) / 100.00 );
	song.autoSaving 	= song.fh.read();
	song.autoSaveDur 	= song.fh.read();
	song.timeSig 		= song.fh.read();
	song.minSpent 		= readInt(song.fh);
	song.leftClicks 	= readInt(song.fh);
	song.rightClicks 	= readInt(song.fh);
	song.blocksAdded 	= readInt(song.fh);
	song.blocksRemoved 	= readInt(song.fh);
	song.midi 			= readString(song.fh, readInt(song.fh));
end

function readNotes()
	local curtk = 1;
	local tk = -1;
	local layer = -1;
	local inst = 0;
	local note = 33; -- MC is 33 to 57

	while true do
		tk = readShort(song.fh);
		if tk == nil then return false; end
		if tk == 0 then break; end
		while true do
			song.music.wait[curtk] = (tk * song.tempo) * 0.965; -- * 0.965 to speed it up a bit because lua slow
			layer = readShort(song.fh); --can't do anything with this info (yet?)
			if layer == nil then return false; end
			if layer == 0 then break; end
			song.music.inst[curtk]=song.fh.read();
			if song.music.inst[curtk] == 0 then
				song.music.inst[curtk] = 0;
			elseif song.music.inst[curtk] == 2 then
				song.music.inst[curtk] = 1;
			elseif song.music.inst[curtk] == 3 then
				song.music.inst[curtk] = 2;
			elseif song.music.inst[curtk] == 4 then
				song.music.inst[curtk] = 3;
			elseif song.music.inst[curtk] == 1 then
				song.music.inst[curtk] = 4;
			end
			song.music.note[curtk]=song.fh.read()-33;
			tk = 0;
			curtk = curtk + 1;
		end
	end
	return true;
end

function showInfo()
	term.clear();
	print("Now Playing: \n\n\n\n\n\n          " .. song.name);
	print("\n\n\n\n\n\nAuthor: " .. song.author);
	print("Original Author: " .. song.originalAuthor);
	print("Description: ");
	print(song.description);
	parallel.waitForAny(function()
		_, key = os.pullEvent("key");
	end, function()
		while true do 
			if not isPlaying then break; end
			os.sleep(0.125);
		end
	end);
	if settings.rptMode == "none" or isPlaying then --song finished in single play mode or key pressed exit
		action = 'mainList';
	end
end

function getRepeateMode() -- returns the name of currently selected repeat mode
	local rptText = "";

	if settings.rptMode == "allRandom" then
		rptText = "All (Random)";
	elseif settings.rptMode == "allOrdered" then
		rptText = "All (In Order)";
	elseif settings.rptMode == "one" then
		rptText = "One (Loop Song)";
	elseif settings.rptMode == "none" then
		rptText = "None";
	end

	return rptText;
end

function changeRepeatMode() -- cycles to next repeat mode and returns its name
	if settings.rptMode == "allRandom" then
		settings.rptMode = "allOrdered";
	elseif settings.rptMode == "allOrdered" then
		settings.rptMode = "one";
	elseif settings.rptMode == "one" then
		settings.rptMode = "none";
	elseif settings.rptMode == "none" then
		settings.rptMode = "allRandom";
	end

	return getRepeateMode();
end

function options()
	local selectedIndex = 1;
	while true do
		term.clear();
		local opts = {};
		opts[1] = "Show Now Playing";
		opts[2] = "Repeat: " .. getRepeateMode();
		opts[3] = "Next Song";
		opts[4] = "Stop";
		opts[5] = "Back To Song List";
		-- "Load Playlist" --> default song lists & any saved lists
		-- "Add " .. selected main menu song .. " to a playlist"
		-- "Queue " .. selected main menu song -- takes priority over repeat mode
		-- "Load songs from ..." -- prompts for folder path, erases current queue

		for i = 1, #opts do
			if i == selectedIndex then
				print("> " .. opts[i]);
			else
				print("  " .. opts[i]);
			end
		end
		print("----------------------\nUse Arrow keys and Enter to navigate.\n");
		_, key = os.pullEvent("key");

		if key == 208 or key == 31 then -- down or s
			selectedIndex = selectedIndex + 1;
			if selectedIndex > #opts then selectedIndex = 1; end
		elseif key == 200 or key == 17 then -- up or w
			selectedIndex = selectedIndex-1;
			if selectedIndex < 1 then selectedIndex = 1; end
		elseif key == 28 or key == 57 then -- enter or space
			if selectedIndex == 1 and isPlaying then
				action = 'nowPlaying';
				break;
			elseif selectedIndex == 2 then
				changeRepeatMode();
			elseif selectedIndex == 3 then
				skipSong();
				break;
			elseif selectedIndex == 4 then
				stopSong();
				action = 'mainList';
				break;
			else
				action = 'mainList';
				break;
			end
		end
	end
end

function mainList(startat, selectedIndex)
	term.clear();
	for i = startat, #menu do
		if startat + maxtoshow <= i then break end
		if i == selectedIndex then
			print("> " .. menu[i].fn);
		else
			print("  " .. menu[i].fn);
		end
	end
	print("----------------------\nUse Arrow keys and Enter to navigate.");
	print("Press m to access options or press e to exit.")
	_, key = os.pullEvent("key");

	if key == 208 or key == 31 then -- down or s
		selectedIndex = selectedIndex + 1;
		if selectedIndex >= startat + maxtoshow then startat = startat + maxtoshow; end
		if selectedIndex > #menu then selectedIndex = 1; startat = 1; end
	elseif key == 200 or key == 17 then -- up or w
		selectedIndex = selectedIndex-1;
		if selectedIndex < 1 then selectedIndex = 1; end
		if selectedIndex < startat then startat = startat - maxtoshow; end
		if startat < 1 then startat = 1; end
	elseif key == 205 or key == 32 then -- right or d
		selectedIndex = startat + maxtoshow;
		if selectedIndex > #menu then selectedIndex = 1; end
		startat = selectedIndex;
	elseif key == 203 or key == 30 then -- left or a
		selectedIndex = startat - maxtoshow;
		startat = startat - maxtoshow;
		if selectedIndex < 1 then selectedIndex = 1; end
		if startat < 1 then startat = 1; end
	elseif key == 28 or key == 57 then -- enter or space
		action = 'playSong';
	elseif key == 50 then -- m for menu
		action = 'options';
	elseif key == 18 then -- e to exit
		os.reboot();
	end

	return startat, selectedIndex;
end

function continueWith() -- returns a menu index of the next song based on the selected repeat mode
	local contWith = 1;
	if #menu > 0 then
		if settings.rptMode == "allRandom" then
			contWith = math.random(#menu);
		elseif settings.rptMode == "allOrdered" then
			contWith = song.index + 1;
			if contWith > #menu then
				contWith = 1;
			end
		elseif settings.rptMode == "one" then
			contWith = song.index;
		end
	end
	return contWith;
end

function playNotes(doReturn)
	while true do
		if action == 'songReady' then
			isPlaying = true;
			action = 'nowPlaying';
			os.queueEvent("playStarted");
			for i = 1, #song.music.wait - 1 do
				if song.music.wait[i] ~= 0 then
					os.sleep(song.music.wait[i]);
					if stopFlag then break; end
				end
				pcall(box.playNote, song.music.inst[i], song.music.note[i]);
			end
			isPlaying = false;
			os.queueEvent("playEnded");
			if not stopFlag then --song finished (instead of controller terminated)
				if #menu > 0 and settings.rptMode ~= "none" then
					menuAt(continueWith()); --continue playing songs based on current repeat mode
				end
			end
		end
		if doReturn ~= nil and doReturn == true then break; end
		os.sleep(0.25);
	end
end

function stopSong()
	if isPlaying then
		stopFlag = true;
		parallel.waitForAny(function()
			while true do 
				if not isPlaying then break; end
				os.sleep(0.125);
			end
		end);
		stopFlag = false;
	end
end

function menuAt(x) -- plays the song on the menu at index x
	stopSong();
	song = newSong(fs.open(menu[x].d .. "/" .. menu[x].fn, "rb"), x);
	readHeader();
	readNotes();
	song.fh.close();
	action = 'songReady';
end

function skipSong()
	if #menu > 0 and settings.rptMode ~= "none" then
		menuAt(continueWith()); --continue playing songs based on current repeat mode
	else
		stopSong();
	end
end

function controller() --handles actions
	local startat = 1;
	local selectedIndex = 1;
	while true do
		if action == 'mainList' then
			startat, selectedIndex = mainList(startat, selectedIndex);
		elseif action == 'playSong' then
			menuAt(selectedIndex);
			action = 'songReady';
		elseif action == 'songReady' then
			os.sleep(0.125);
		elseif action == 'nowPlaying' then
			showInfo();
		elseif action == 'options' then
			options();
		end
	end
end

function clearMenu()
	menu = {};
end

function menuTable() -- returns all the loaded songs that would show up in the menu
	return menu;
end

function launchUI()
	if box == nil then
		print("No Iron Noteblock Detected");
		return;
	end
	
	if args[1] == nil or fs.isDir(args[1]) == false then
		args[1] = "songs";
		if fs.isDir("songs") == false then
			fs.makeDir("songs");
		end
	elseif args[1] ~= nil and fs.isDir(args[1]) == true then
		loadMenu(args[1]);
	end

	clearMenu();
	loadMenu("songs");
	loadMenu("rom/songs"); -- \Desktop\MindCrack\minecraft\mods\ComputerCraft\lua\rom\songs (ComputerCraft folder inside \mods\ must be created, it is not there by default)

	parallel.waitForAll(playNotes, controller);
end

function current() -- returns convinient 'song' table with complete header info, notes, and etc, --OR-- nil if nothing is playing (useful)
	if isPlaying == true then
		return song; --full song table, has everything
	else
		return nil;
	end
end

mountIronNoteblock();
if shell ~= nil then --ran normally, not loaded as API
	launchUI();
else --else it was loaded as an api so don't do anything else automatically
	settings.rptMode = "none";
end
