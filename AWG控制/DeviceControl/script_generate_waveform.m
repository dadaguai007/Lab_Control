clear;close all;

rng(2);
addpath(genpath('DeviceControl'));

ipaddr = ['172.16.104.21' ...
    '8'];
port = 5025;
modMethod = 'IQ';
model = 'M8195A_Rev1';

awg = KeysightAWG(ipaddr,port,modMethod,model);

fft_size = 1024;
qam_size = 4;
nPkts = 100;
nCP = 32;
nModCarriers = 320;

% dca = ElectricalSpectrumAnalyzer();

modSig = qammod(randi([0 qam_size-1],nModCarriers,nPkts),qam_size);
ofdmSig = ifft([zeros(1,nPkts);modSig;zeros(fft_size-nModCarriers-1,nPkts)]);
ofdmSig = [ofdmSig(end-nCP+1:end,:);ofdmSig];
% ofdmSig = ifft([modSig;zeros(fft_size/2,nPkts)]);
ofdmSig = ofdmSig(:);
scale_factor = max(max(abs(real(ofdmSig))),max(abs(imag(ofdmSig))));
ofdmSig = ofdmSig./scale_factor;

% ofdmSig = [ofdmSig;zeros(1000,1)];

AWG_LENGTH = 213120;

label = ofdmSig(1:1000);

if 0 % upsampling
    upSig = resample(ofdmSig,64e9,32e9);
    % rxSig = (15+upSig).*conj(15+upSig);
    % rxSig = [rxSig(end-10000:end);repmat(rxSig,5,1)];
    nZeros = AWG_LENGTH - length(upSig);
    upSig = [upSig;zeros(nZeros,1)];
    pkt_length = length(upSig)/2;
else
    upSig = ofdmSig;
end
[powershift,fshift,p1,fnew] = FFT(upSig,58e9);
% % add zeros
% nZeros = 2000;
% ofdmSig(end+1:end+1000) = zeros(nZeros,1);

% add iq delay
delay_ps = -20.5;
upSig = iqdelay(upSig, 64e9, delay_ps*1e-12).';

awg.SendDataToAWG(real(upSig),1);
awg.SendDataToAWG(imag(upSig),2);


% filename = sprintf('QPSK_OFDM_CP32-64GS-20GHz-%dps',delay_ps);
% generate_awg_file(filename,[real(upSig) imag(upSig)],64e9);


% 
