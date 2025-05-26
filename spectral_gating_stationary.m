% spectral_gating_stationary.m
function denoised_signal = spectral_gating_stationary(y_chunk, fs, n_fft, win_length, hop_length, noise_thresh, prop_decrease)
    % Applies stationary spectral gating to a single audio channel.
    %
    % Inputs:
    %   y_chunk       - Input audio data (single channel, column vector).
    %   fs            - Sampling rate of the audio.
    %   n_fft         - FFT size for STFT.
    %   win_length    - Window length for STFT.
    %   hop_length    - Hop length for STFT.
    %   noise_thresh  - Precomputed noise threshold per frequency bin (column vector).
    %   prop_decrease - Proportion of decrease for the gain filter.

    window = hanning(win_length, 'periodic');
    noverlap = win_length - hop_length;

    % Perform STFT on the input chunk
    [s, ~, ~] = stft(y_chunk, fs, 'Window', window, 'OverlapLength', noverlap, 'FFTLength', n_fft);

    % Convert STFT magnitude to dB
    sig_stft_db = local_amp_to_db(s);

    % Create the threshold matrix matching dimensions of sig_stft_db
    db_thresh_mat = repmat(noise_thresh, 1, size(sig_stft_db, 2));

    % Create the binary mask
    sig_mask = sig_stft_db > db_thresh_mat;

    % Apply prop_decrease to the mask (gain factor)
    % This means if mask is 1 (signal > thresh), gain is prop_decrease.
    % If mask is 0 (signal <= thresh), gain is (1 - prop_decrease).
    % The Python code is: sig_mask = sig_mask * self._prop_decrease + np.ones(np.shape(sig_mask)) * (1.0 - self._prop_decrease)
    % This is equivalent to: gain = (signal > thresh) * prop_decrease + (signal <= thresh) * (1-prop_decrease) (if prop_decrease is gain for signal)
    % Or, more directly from the Python line: if mask is 1, it becomes prop_decrease. If mask is 0, it becomes 1-prop_decrease.
    % The intention is to reduce elements below threshold. A prop_decrease of 1 means full suppression for noise, 0 means no suppression.
    % The Python logic is effectively:
    % gain_values = ones(size(sig_mask));
    % gain_values(sig_mask == 1) = 1.0; % Keep signal
    % gain_values(sig_mask == 0) = 1.0 - prop_decrease; % Attenuate noise
    % Let's re-evaluate the Python:
    % sig_mask = sig_stft_db > db_thresh  (True/False, or 1/0 in calculation)
    % sig_mask = sig_mask * prop_decrease + (1 - prop_decrease)
    % If sig_stft_db > db_thresh (mask is 1):  1 * prop_decrease + (1 - prop_decrease) = prop_decrease + 1 - prop_decrease = 1. (Full signal)
    % If sig_stft_db <= db_thresh (mask is 0): 0 * prop_decrease + (1 - prop_decrease) = 1 - prop_decrease. (Attenuated signal/noise)
    % So, prop_decrease in the Python code means "how much to reduce the noise components by".
    % If prop_decrease = 1.0, noise components are multiplied by (1-1.0) = 0. (Full suppression)
    % If prop_decrease = 0.8, noise components are multiplied by (1-0.8) = 0.2. (Significant suppression)
    gain_mask = (sig_stft_db > db_thresh_mat) * 1.0 + (sig_stft_db <= db_thresh_mat) * (1.0 - prop_decrease);

    % Multiply complex STFT by the gain mask
    sig_stft_denoised = s .* gain_mask;

    % Perform Inverse STFT
    denoised_signal_temp = istft(sig_stft_denoised, fs, 'Window', window, 'OverlapLength', noverlap, 'FFTLength', n_fft, 'ConjugateSymmetric', true);
    
    % Trim or pad to original length
    original_length = length(y_chunk);
    current_length = length(denoised_signal_temp);

    if current_length > original_length
        denoised_signal = denoised_signal_temp(1:original_length);
    elseif current_length < original_length
        denoised_signal = zeros(original_length, 1); % Assuming column vector
        denoised_signal(1:current_length) = denoised_signal_temp;
    else
        denoised_signal = denoised_signal_temp;
    end
end

function x_db = local_amp_to_db(x_complex, top_db_val, eps_val_in)
    % Converts complex STFT data to dB, applying a noise floor relative to peak.
    if nargin < 2
        top_db_val = 80.0; % Default based on Python _amp_to_db
    end
    if nargin < 3
        eps_val_in = eps('double'); % Default epsilon
    end

    x_abs = abs(x_complex);
    x_db_temp = 20 * log10(x_abs + eps_val_in);
    
    % Apply floor: max(x_db, max_in_col - top_db)
    % Python: np.maximum(x_db, np.max(x_db, axis=-1, keepdims=True) - top_db)
    % axis=-1 for (freq, time) STFT means max over time for each freq bin
    max_val_per_freq_bin = max(x_db_temp, [], 2); % Max along each row (frequency bin)
    floor_val_per_freq_bin = max_val_per_freq_bin - top_db_val;
    
    x_db = max(x_db_temp, floor_val_per_freq_bin); % Element-wise maximum
end