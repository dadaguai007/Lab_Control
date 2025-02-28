function result = iqdelay(data, fs, delay)
% Apply a <delay> to an input vector <data> with samplerate <fs>.
% <delay> is given in seconds (does not have to be multiple of the
% sample interval). 
% If data is complex, keeps the imaginary part unchanged.

% determine number of samples
n = length(data);
% make sure the input data has the right format (row-vector)
data = reshape(data, 1, n);
% the algorithm works only for even number of samples
if (mod(n,2) ~= 0)
    n = 2 * n;
    data = repmat(data, 1, 2);
    dflag = 1;
else
    dflag = 0;
end
% convert to frequency domain
fdata = fftshift(fft(real(data)))/n;
% create linear phase vector (= delay)
phd = [-n/2:n/2-1]/n*2*pi*(delay*fs);
% convert it into frequency domain
fdelay = exp(j*(-phd));
% apply delay (convolution ~ multiplication)
fresult = fdata .* fdelay;
% ...and convert back into time domain
result = real(ifft(fftshift(fresult)))*n;
% get imaginary part from input vector
if (~isreal(data))
    result = complex(result, imag(data));
end
if (dflag)
    result = result(1:n/2);
end
%~isreal(data)是一个逻辑表达式，用于检查变量 data 是否为实数。
% 如果 data 不是实数，即具有虚部，表达式的值为 true；如果 data 是实数，表达式的值为 false。


% 对于线性时不变系统，可以在频域上通过延迟相位来实现时域延迟。这是基于信号的频谱与其时域表示之间的傅里叶变换关系。
% 
% 具体而言，可以通过以下步骤在频域上进行延迟相位的处理：
% 1. 对输入信号进行傅里叶变换，将其转换到频域。
% 2. 在频域上引入相位延迟，即对频谱的每个频率分量都应用相位延迟。
% 3. 对处理后的频域信号进行逆傅里叶变换，将其转换回时域。
% 这样，通过在频域上应用相位延迟，就可以实现时域延迟的效果。
% 需要注意的是，这种方法假定信号在整个频率范围内都具有恒定的传输延迟。

%相位延迟量，应该还是与采样率进行相乘，决定了每秒采样点的数量

% 当在时域上对信号进行延迟时，对应的频域相位将会发生移动。
% 具体而言，延迟一个信号的时域表示等效于在频域上引入相位移动。