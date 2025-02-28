function init_att=script_set_initatt(inputop,channl)
v = EXFO_VOA();
pm = Keysight8163B();
% set the initial power
new_att(1)=pm.Read_Power(1,channl);
for idx = 2:10
    cur_op = pm.Read_Power(1,channl);
    diff = cur_op-inputop;
    cur_att = v.get_Current_ATT;
    new_att(idx) = -1*(cur_att-diff);
    err = abs(new_att(idx) - new_att(idx-1));
    if err <= 0.002
        break;
    end
end
init_att = new_att(idx);
% check if init_att is too small
if init_att < 0
    error('The initial attenuation value cannot be negative. Please change the input initial optical power value');
end
end