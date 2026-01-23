module bool_count(input [7:0] data, output [3:0] count);
    assign count = (data[7] + data[6]) + (data[5] + data[4]) + (data[3] + data[2]) + (data[1] + data[0]);
endmodule