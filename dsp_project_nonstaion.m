clear; close all; clc

open_system('dsp_project_nonstationary');

fs  = 16000;        
nfft = 512;
hop = 128;
n_std_thresh = 1.5;
time_constant_s = 0.04;
t_frames = time_constant_s*fs/hop;
b = (sqrt(1+4*t_frames^2)-1)/(2*t_frames^2);


thresh_n_mult_nonstationary = 0.9;
sigmoid_slope = 10;
prop = 0.9;

freq_mask_smooth_hz = 50;
time_mask_smooth_ms = 20;

Lf = max(1, round(freq_mask_smooth_hz / (fs/nfft)));
Lt = max(1, round(time_mask_smooth_ms / (hop/fs*1e3)));