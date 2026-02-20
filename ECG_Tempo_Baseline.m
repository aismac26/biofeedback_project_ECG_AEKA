%% AEKA Heart Symphony Baseline Code
% Reads EMG/ECG signal from Mikroe Click via Arduino
% Displays real-time signal and computes tempo control
%
% Hardware:
% Arduino Uno + Mikroe Shield
% EMG Click (AN -> A0)
%
% Author: Ava Jones
% Sprint 1 Baseline
%% AEKA Heart Symphony - ECG -> BPM -> Tempo (Real-time)
clear; clc; close all

%% ---------- SETTINGS (EDIT THESE) ----------
port = "";                 % leave "" for auto
board = "";                % leave "" for auto
ecgPin = "A0";             % analog input pin
Fs = 250;                  % target sample rate (Hz)
runTime_s = 60;            % total run time (seconds)

winSeconds = 8;            % how many seconds to display on plot
bpmUpdateSeconds = 2;      % how often to recompute BPM/tempo

% R-peak detection tuning (you WILL tweak these once you see your signal)
minPeakDistance_s = 0.30;  % 0.30s => max ~200 BPM
minPeakProm = 0.08;        % volts, adjust based on your filtered amplitude

% Tempo mapping
baseTempo_BPM = 90;        % "normal" music tempo when HR = 90
tempoClamp = [0.7, 1.5];   % clamp playback rate multiplier

% Logging
doLogCSV = true;
csvName = "AEKA_ECG_Log.csv";

%% ---------- CONNECT ARDUINO ----------
% If you have multiple boards/ports, specify them:
% a = arduino(port, board);
a = arduino();

%% ---------- FILTER DESIGN ----------
% ECG useful band: ~0.5–40 Hz, plus optional 60 Hz notch
bp = designfilt("bandpassiir", ...
    "FilterOrder", 4, ...
    "HalfPowerFrequency1", 0.5, ...
    "HalfPowerFrequency2", 40, ...
    "SampleRate", Fs);

notch = designfilt("bandstopiir", ...
    "FilterOrder", 4, ...
    "HalfPowerFrequency1", 59, ...
    "HalfPowerFrequency2", 61, ...
    "SampleRate", Fs);

%% ---------- AUDIO SETUP (TEMPO CONTROL) ----------
% Pick any short loopable audio. Keep it small for responsiveness.
% If you don’t have a file, comment this section and use the "metronome" below.
useAudioFile = false;
audioFile = "music.wav"; % put a wav in same folder if using

if useAudioFile
    [y, fsMusic] = audioread(audioFile);
    y = mean(y, 2); % mono
    player = audioplayer(y, fsMusic);
    play(player);
else
    % Simple metronome click as a fallback "audio output"
    fsClick = 8000;
    tClick = (0:1/fsClick:0.03).';
    click = sin(2*pi*1000*tClick) .* hann(length(tClick));
    clickPlayer = audioplayer(click, fsClick);
    lastClickTime = tic;
end

%% ---------- BUFFERS ----------
Nwin = round(winSeconds * Fs);
t0 = tic;

rawBuf = zeros(Nwin,1);
filtBuf = zeros(Nwin,1);
timeBuf = linspace(-winSeconds, 0, Nwin).';

% For BPM calculation, keep a longer history of peak times
peakTimes = [];  % seconds (relative to start)

% Logging arrays
logT = [];
logRaw = [];
logFilt = [];
logBPM = [];

%% ---------- PLOT SETUP ----------
fig = figure("Name","AEKA ECG Live","Color","w");
ax1 = subplot(2,1,1);
hRaw = plot(ax1, timeBuf, rawBuf, "LineWidth", 1);
grid(ax1,"on"); ylabel(ax1,"Raw (V)"); title(ax1,"Raw ECG (Arduino A0)");

ax2 = subplot(2,1,2);
hFilt = plot(ax2, timeBuf, filtBuf, "LineWidth", 1);
grid(ax2,"on"); ylabel(ax2,"Filtered (V)"); xlabel(ax2,"Time (s)");
title(ax2,"Filtered ECG + R-peaks + BPM");

hPeaks = line(ax2, nan, nan, "LineStyle","none", "Marker","v", "MarkerSize",6);

bpmText = text(ax2, 0.02, 0.9, "BPM: --", "Units","normalized", "FontSize",12, "FontWeight","bold");

%% ---------- MAIN LOOP ----------
dt = 1/Fs;
nextBpmUpdate = 0;

while toc(t0) < runTime_s && ishandle(fig)
    loopStart = tic;

    % 1) Read one sample
    v = readVoltage(a, ecgPin);
    tNow = toc(t0);

    % 2) Update rolling buffers
    rawBuf = [rawBuf(2:end); v];

    % Filter: notch then bandpass (order can be swapped; this is fine)
    vf = filtfilt(bp, filtfilt(notch, rawBuf));
    filtBuf = vf; % vf is full window length (same size as rawBuf)

    % 3) Peak detection on the WINDOW (only on last few seconds)
    minDist = round(minPeakDistance_s * Fs);
    [pks, locs] = findpeaks(filtBuf, ...
        "MinPeakDistance", minDist, ...
        "MinPeakProminence", minPeakProm);

    % Convert locs (indices in window) to time in seconds (relative)
    tWindow = linspace(tNow-winSeconds, tNow, Nwin).';
    peakTwindow = tWindow(locs);

    % 4) BPM update every bpmUpdateSeconds
    if tNow >= nextBpmUpdate
        nextBpmUpdate = tNow + bpmUpdateSeconds;

        % Keep a global peak time list (append new peaks near the end)
        % Only add peaks that are "recent" and not duplicates
        recentPeaks = peakTwindow(peakTwindow > (tNow - bpmUpdateSeconds - 0.2));
        for k = 1:numel(recentPeaks)
            if isempty(peakTimes) || all(abs(peakTimes - recentPeaks(k)) > 0.2)
                peakTimes(end+1,1) = recentPeaks(k); %#ok<SAGROW>
            end
        end

        % Compute BPM using last ~10 seconds of peaks
        keepMask = peakTimes > (tNow - 10);
        peakTimes = peakTimes(keepMask);

        bpm = NaN;
        if numel(peakTimes) >= 2
            rr = diff(peakTimes);              % seconds
            bpm = 60 / median(rr);             % robust against one bad interval
        end

        % Update display
        if isnan(bpm) || bpm < 30 || bpm > 220
            bpmStr = "BPM: --";
        else
            bpmStr = sprintf("BPM: %.0f", bpm);
        end
        bpmText.String = bpmStr;

        % 5) Map BPM -> Tempo and control audio
        if ~isnan(bpm) && bpm >= 30 && bpm <= 220
            tempoMult = bpm / baseTempo_BPM;
            tempoMult = max(tempoClamp(1), min(tempoClamp(2), tempoMult));

            if useAudioFile
                % Change playback rate by changing SampleRate
                if isvalid(player)
                    player.SampleRate = round(fsMusic * tempoMult);
                    if ~isplaying(player), play(player); end
                end
            else
                % Metronome click at the BPM (audible proof of control)
                % Only click when enough time has passed
                if toc(lastClickTime) >= (60/bpm)
                    play(clickPlayer);
                    lastClickTime = tic;
                end
            end
        end

        % Logging BPM (hold last value for this update)
        logBPM(end+1,1) = bpm; %#ok<SAGROW>
    end

    % 6) Update plot (raw + filtered + peaks)
    hRaw.YData = rawBuf;
    hRaw.XData = timeBuf; % fixed -winSeconds..0 display

    hFilt.YData = filtBuf;
    hFilt.XData = timeBuf;

    % Peaks plotted on the filtered window in the same -winSeconds..0 axis
    peakX = peakTwindow - tNow;     % convert to relative time in window
    set(hPeaks, "XData", peakX, "YData", pks);

    drawnow limitrate

    % 7) Log raw/filt (optional)
    if doLogCSV
        logT(end+1,1) = tNow;      %#ok<SAGROW>
        logRaw(end+1,1) = v;       %#ok<SAGROW>
        logFilt(end+1,1) = filtBuf(end); %#ok<SAGROW>
    end

    % 8) Timing control to approximate Fs
    elapsed = toc(loopStart);
    pause(max(0, dt - elapsed));
end

%% ---------- SAVE CSV ----------
if doLogCSV && ~isempty(logT)
    T = table(logT, logRaw, logFilt, ...
        "VariableNames", ["t_s","raw_V","filt_V"]);

    % If you want BPM in the CSV too, we can add it, but it updates slower than samples.
    writetable(T, csvName);
    fprintf("Saved log to %s\n", csvName);
end

% Stop audio cleanly
if useAudioFile
    if exist("player","var") && isvalid(player)
        stop(player);
    end
end