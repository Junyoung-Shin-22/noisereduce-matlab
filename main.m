% main.m

% 1. Parameters for Noise Reduction
inputFile = '/MATLAB Drive/DSP_Project/sp01_train_sn10.wav'; % !!! REPLACE THIS with your noisy WAV file !!!
outputFile = '/MATLAB Drive/DSP_Project/output.wav';          % Name for the denoised output file

% STFT Parameters (match these with how spectral_gating_stationary expects them)
n_fft = 1024;        % FFT size
win_length = 1024;   % Window length (scipy default is n_fft)
hop_length = 256;    % Hop length (scipy default is win_length // 4)

% Spectral Gating Parameters
n_std_thresh_stationary = 1.5; % Number of noise STDs above mean for threshold
prop_decrease = 1.0;           % Proportion to decrease noise by (0 to 1). 
                               % 1.0 means max suppression (noise part multiplied by 0).
                               % 0.8 means noise part multiplied by 0.2.
noise_duration_sec = 1.0;      % Duration of the initial part of audio to use as noise sample (in seconds)

% --- Define amp_to_db locally for noise profile calculation in main ---
% This is a helper function to convert amplitude to dB for noise profiling.
% It mirrors the 'local_amp_to_db' in spectral_gating_stationary.m
function x_db_local = main_local_amp_to_db(x_complex_local, top_db_local, eps_val_local_main)
    if nargin < 2
        top_db_local = 80.0;
    end
    if nargin < 3
        eps_val_local_main = eps('double');
    end
    x_abs_local = abs(x_complex_local);
    x_db_temp_local = 20 * log10(x_abs_local + eps_val_local_main);
    max_val_per_freq_bin_local = max(x_db_temp_local, [], 2);
    floor_val_per_freq_bin_local = max_val_per_freq_bin_local - top_db_local;
    x_db_local = max(x_db_temp_local, floor_val_per_freq_bin_local);
end
% --------------------------------------------------------------------

% 2. Read Noisy Audio File
[y_input, fs] = audioread(inputFile);

num_input_channels = size(y_input, 2);
y_output_denoised = zeros(size(y_input)); % Initialize output array

% 3. Process Each Channel
for channel_idx = 1:num_input_channels
    current_channel_audio = y_input(:, channel_idx);
    current_channel_audio = current_channel_audio(:); % Ensure it's a column vector

    % Define noise segment from the beginning of the current channel
    noise_samples_count = min(round(noise_duration_sec * fs), length(current_channel_audio));
    
    if noise_samples_count < win_length
        % Handle cases where noise segment is too short (very basic handling)
        % For a robust solution, more checks or different noise estimation might be needed.
        % Here, we'll proceed, but STFT might error or give poor results.
        if noise_samples_count == 0
             error('Noise segment for channel %d is empty based on noise_duration_sec. Cannot proceed.', channel_idx);
        end
        % If very short, the STFT will likely be problematic.
        % Consider issuing a warning if you add print statements back.
    end
    noise_segment = current_channel_audio(1:noise_samples_count);

    % Calculate noise statistics and threshold for the current channel
    stft_window_obj = hanning(win_length, 'periodic');
    stft_noverlap_val = win_length - hop_length;

    noise_stft_complex = stft(noise_segment, fs, 'Window', stft_window_obj, 'OverlapLength', stft_noverlap_val, 'FFTLength', n_fft);
    
    % Convert noise STFT to dB using the local helper for main.m
    noise_stft_db = main_local_amp_to_db(noise_stft_complex); 

    mean_freq_noise = mean(noise_stft_db, 2); % Mean across time for each freq bin
    std_freq_noise = std(noise_stft_db, 0, 2);  % Std dev across time (0 is weight, default N-1 norm)
    
    computed_noise_thresh = mean_freq_noise + std_freq_noise * n_std_thresh_stationary;

    % Denoise the current audio channel using the dedicated function
    denoised_channel_audio = spectral_gating_stationary(current_channel_audio, fs, n_fft, win_length, hop_length, computed_noise_thresh, prop_decrease);
    
    % Store the denoised channel in the output array (handle length differences)
    len_original_ch = length(current_channel_audio);
    len_denoised_ch = length(denoised_channel_audio);

    if len_denoised_ch >= len_original_ch
        y_output_denoised(:, channel_idx) = denoised_channel_audio(1:len_original_ch);
    else
        y_output_denoised(1:len_denoised_ch, channel_idx) = denoised_channel_audio;
        % The rest of y_output_denoised for this channel will remain zeros if shorter
    end
end

% 4. Save the Denoised Output
audiowrite(outputFile, y_output_denoised, fs);

% (Optional: add a disp(['Denoised audio saved to ', outputFile]); if you want confirmation)