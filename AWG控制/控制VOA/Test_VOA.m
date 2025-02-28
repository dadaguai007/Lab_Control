clear; close all;clc;
voa = EXFO_VOA();
pm = Keysight8163B();

% channels to be captured
chIDs = 1;


outpow_min = -40;
outpow_max = -27;
% 先将EDFA调节功率，使功率计达到一个最大的目标值，衰减器的固定衰减值不用理会
% 比如：调节至-2dBm，那么可以设置为一个(-10,-5)范围的采集值。
% 再指定所需要采集的光功率的范围值，范围值必须要小于上述设定的目标值。
% 直接运行，设定好文件名即可。
% outpow_min = -49;
% outpow_max = -45;
att_start = script_set_initatt(outpow_min,1);% 衰减值得初始值，一般设置为最大光功率，后续是衰减递增
att_step = 0.5;
nAtt = outpow_max-outpow_min+1;
nAtt=nAtt*2;
att_vec = att_start - att_step*(0:nAtt-2);% 减法或者加法
% 需要选择一个好的衰减值，使进PD的光功率凑出一个整值（都是使用近似的值来代表）
for iAtt = 1:length(att_vec)
    % set attenuation
    att_curr = att_vec(iAtt);
    voa.Set_Att_Directly(att_curr);
    pd_inpower(iAtt) = pm.Read_Power(1,1);
    pd_inpower(iAtt)=pd_inpower(iAtt)+20;
    % display the output
    fprintf('Pow = %1.2f\n;',pd_inpower(iAtt));
    pause(5);
    Amp_power(iAtt) = pm.Read_Power(1,2);
end

% save(sprintf('%s\\pd_inpower.mat',datapath),'pd_inpower');
figure;
plot(pd_inpower,Amp_power)

%%
% pm = AnritsuMT9810B();% GPIB地址为1
% Pow = pm.Read_Power(2);