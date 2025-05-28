clear; close all; clc

open_system('dsp_project');

fs  = 16000;        
nfft = 1024;
hop = 256;
n_std_thresh = 1.2;

freq_mask_smooth_hz = 1000;
time_mask_smooth_ms = 100;

Lf = max(1, round(freq_mask_smooth_hz / (fs/nfft)));
Lt = max(1, round(time_mask_smooth_ms / (hop/fs*1e3)));