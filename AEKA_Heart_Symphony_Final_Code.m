%% AEKA Heart Symphony Final Code

clear;
clc;

% arduino connection
a = arduino("COM3", "Uno");

FsECG = 500; % ideal sampling 
recordTime = 10; %seconds of data to record

fprintf("Collecting ECG data...\n"); % display to user

%store ECG data into table
ecgTable = readVoltage(a, "A0", Duration=recordTime, SampleRate=FsECG, OutputFormat ="timetable");

fprintf("ECG data collection complete.\n"); %update user on complete process

% Pull Voltage data from table
ecg = ecgTable.Voltage;

ecg = ecg - mean(ecg); % remove DC offset

% Bandpass filter - eliminate noise and focus on QRS frequency range
ecgFiltered = bandpass(ecg, [5 15], FsECG);

% Detect R-peak
signal = abs(ecgFiltered); % absolute value of peak values
signal = signal / max(signal); % scale data
threshold = 0.35; % minimum height to count as a peak

% Calculate BPM from the R peaks
[~, locs] = findpeaks(signal, 'MinPeakHeight', threshold, 'MinPeakDistance', round(FsECG * 0.3));

% Calculate BPM with RR interval
if length(locs)>1
    RR = diff(locs) / FsECG; %time between peaks (RR interval)
    bpm = 60/mean(RR); %heart rate formula
else
    bpm = 0;
end

% Display BPM
fprintf('Detected BPM: %.2f\n', bpm);

% Define song file paths
song_50 = '50bpm.mp3';   % less than/ equal to 59 BPM
song_70 = '70bpm.mp3'; % 60- 79 BPM
song_90 = '90bpm.mp3'; % 80– 99 BPM
song_110 = '110bpm.mp3'; % 100-119 BPM
song_130 = '130bpm.mp3'; % 120-139 BPM
song_150 = '150bpm.mp3'; % 140-159 BPM
song_170 = '170bpm.mp3'; % 160-179 BPM
song_190 = '190bpm.mp3'; % 180-199 BPM
song_200_on = '200bpm.mp3'; % over 200 BPM

% Select song based on BPM range
if bpm <= 59
    file = song_50;
elseif bpm >= 60 && bpm <= 79
    file = song_70;
elseif bpm >= 80 && bpm <= 99
    file = song_90;
elseif bpm >= 100 && bpm <= 119
    file = song_110;
elseif bpm >= 120 && bpm <= 139
    file = song_130;
elseif bpm >= 140 && bpm <= 159
    file = song_150;
elseif bpm >= 160 && bpm <= 179
    file = song_170;
elseif bpm >= 180 && bpm <= 199
    file = song_190;
else
    file = song_200_on;
end

fprintf("Playing track for BPM %.0f\n", bpm);

% Play track - Limit to 10 seconds
[y, FsAudio] = audioread(file);
duration_sec = 10;
max_samples = duration_sec * FsAudio;
y = y(1:min(max_samples, size(y,1)), :); 

% Play and wait for it to finish
player = audioplayer(y, FsAudio);
play(player);
pause(duration_sec); % keeps script alive for 10 seconds
stop(player); % stops cleanly after
fprintf('Done playing.\n'); % The End