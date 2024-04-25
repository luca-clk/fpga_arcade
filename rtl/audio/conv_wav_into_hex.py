# f_in = open(
#     "/home/luca/Downloads/Popular Gaming Sound Effects #2 (HD) (1).wav", 'rb')
# f_out = open("sound.hex", 'w')

# start = 46
# stop = 0x23c0
# arr = f_in.read()

# samples = []
# for idx in range(start, stop, 2):
#     sample = arr[idx] + arr[idx + 1] * 256
#     f_out.write(f"16'h{sample:0>4x}\n")

# f_in.close()
# f_out.close()
# yo = librosa.resample(y=y, orig_sr=sr, target_sr=24000)

import librosa
import numpy as np
import soundfile as sf

target_sr = 24000
num_bits = 12
gain = 0.5

input_mp3 = "/home/luca/Downloads/gaming_sound.mp3"
output_hex = "sound.hex"

y, sr = sf.read(input_mp3)
if np.ndim(y)>1:
    y = y[:,0]+y[:,1]

y_r = librosa.resample(y=y, orig_sr=sr, target_sr=24000)

max_y = max(np.abs(y_r))

max_out = 2**(num_bits-1)-1

y_o = np.int64(gain * max_out * y_r / max_y)
f_out = open("sound2.hex", 'w')

start = 0
length = 0x23c0
samples = []
for idx in range(start, length):
    sample = y_o[idx]
    f_out.write(f"16'h{sample:0>3x}\n")
