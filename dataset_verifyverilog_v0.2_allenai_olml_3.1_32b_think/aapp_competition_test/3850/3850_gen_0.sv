module key_assignment(input [9:0] p, input [9:0] people0, input [9:0] people1, input [9:0] key0, input [9:0] key1, input [9:0] key2, input [9:0] key3, output [10:0] result);
wire [10:0] time0_0, time0_1, window0_max;
wire [10:0] time1_0, time1_1, window1_max;
wire [10:0] time2_0, time2_1, window2_max;
assign time0_0 = |people0 - key0| + |key0 - p|;
assign time0_1 = |people1 - key1| + |key1 - p|;
assign window0_max = time0_0 > time0_1 ? time0_0 : time0_1;
assign time1_0 = |people0 - key1| + |key1 - p|;
assign time1_1 = |people1 - key2| + |key2 - p|;
assign window1_max = time1_0 > time1_1 ? time1_0 : time1_1;
assign time2_0 = |people0 - key2| + |key2 - p|;
assign time2_1 = |people1 - key3| + |key3 - p|;
assign window2_max = time2_0 > time2_1 ? time2_0 : time2_1;
assign result = window0_max < window1_max ? (window0_max < window2_max ? window0_max : window2_max) : (window1_max < window2_max ? window1_max : window2_max);
endmodule