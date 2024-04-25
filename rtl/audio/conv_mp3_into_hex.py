import librosa
import numpy as np
import soundfile as sf

target_sr = 24000
num_bits = 12
gain = 0.5
start = 0

input_mp3 = "/home/luca/Downloads/ball.mp3"
output_hex = "/home/luca/Downloads/ball.hex"

y, sr = sf.read(input_mp3)
if np.ndim(y)>1:
    y = y[:,0]+y[:,1]

print(f"Audio input length {len(y)} sample rate {sr} duration {len(y)/sr}")
y_r = librosa.resample(y=y, orig_sr=sr, target_sr=24000)

max_y = max(np.abs(y_r))
max_out = 2**(num_bits-1)-1
y_o = np.int64(gain * max_out * y_r / max_y)

# crop heading and trailing 0's
idx = 0
while(y_o[idx] == 0):
    idx +=1
y_o = y_o[idx:]
idx = len(y_o)-1
while(y_o[idx] == 0):
    idx -=1
y_o = y_o[:idx+1]

print(f"Audio output length {len(y_o)} sample rate {target_sr} duration {len(y_o)/target_sr}")

f_out = open(output_hex, 'w')
for idx in range(start, len(y_o)):
    if (y_o[idx]>=0):
        sample = y_o[idx]
    else:
        sample = 2**num_bits + y_o[idx]
    f_out.write(f"{num_bits}'h{sample:0>3x},\n")

f_out.close()
