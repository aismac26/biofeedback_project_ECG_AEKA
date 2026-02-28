%% AEKA Heart Symphony Baseline Code

%draft code if AD8232 works
%
% port = "";
% baudrate = ;
% s = serialport(port, baudrate);
% configureTerminator(s,"LF");
% 
% Fs = ; % Sampling frequency
% recordTime = 10; % seconds to collect ECG
% numSamples = Fs * recordTime;
% 
% ecg = zeros(numSamples,1);
% 
% fprintf("Collecting ECG data...\n");
% 
% for i = 1:numSamples
%     data = readline(s);
%     ecg(i) = str2double(data);
% end
% 
% fprintf("ECG collection complete.\n");
% 
% ECG filtering
% % ecg = ecg - mean(ecg);
% 
% ecgFiltered = bandpass(ecg, [5 15], Fs);
%
% R-peak detect
% 
% threshold = 0.6 * max(ecgFiltered);
% 
% [peaks, locs] = findpeaks(ecgFiltered, ...
%     'MinPeakHeight', threshold, ...
%     'MinPeakDistance', round(0.4*Fs));
% 
% numBeats = length(locs);
% 
% % BPM calculation
% bpm = (numBeats / recordTime) * 60;
% 
% fprintf("Detected BPM: %.2f\n", bpm);
% we would replace "bpm =" with the value calculated above


% Simulated or measured BPM value
bpm = 180; % Replace this with the actual BPM input

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
    fprintf('BPM: %d → Playing slowest track\n', bpm);
    [y, Fs] = audioread(song_50);
elseif bpm >= 60 && bpm <= 79
   fprintf('BPM: %d → Playing slower track\n', bpm);
   [y, Fs] = audioread(song_70);
elseif bpm >= 80 && bpm <= 99
   fprintf('BPM: %d → Playing slow track\n', bpm);
   [y, Fs] = audioread(song_90);
elseif bpm >= 100 && bpm <= 119
   fprintf('BPM: %d → Playing mid-energy track\n', bpm);
   [y, Fs] = audioread(song_110);
elseif bpm >= 120 && bpm <= 139
   fprintf('BPM: %d → Playing mid-high energy track\n', bpm);
   [y, Fs] = audioread(song_130);
elseif bpm >= 140 && bpm <= 159
   fprintf('BPM: %d → Playing high energy track\n', bpm);
   [y, Fs] = audioread(song_150);
elseif bpm >= 160 && bpm <= 179
   fprintf('BPM: %d → Playing higher energy track\n', bpm);
   [y, Fs] = audioread(song_170);
elseif bpm >= 180 && bpm <= 199
   fprintf('BPM: %d → Playing highest energy track\n', bpm);
   [y, Fs] = audioread(song_190);
else
   fprintf('BPM: %d → Out of range, playing default track\n', bpm);
   [y, Fs] = audioread(song_200_on);
end

% Limit to 10 seconds
duration_sec = 10;
max_samples = duration_sec * Fs;
y = y(1:min(max_samples, length(y)), :); % handles stereo too

% Play and wait for it to finish
player = audioplayer(y, Fs);
play(player);
pause(duration_sec); % keeps script alive for 10 seconds
stop(player);        % stops cleanly after
fprintf('Done playing.\n');