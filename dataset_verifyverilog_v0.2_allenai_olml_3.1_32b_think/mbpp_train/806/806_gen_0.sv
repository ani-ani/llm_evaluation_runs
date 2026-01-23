module max_run_uppercase (
    input [7:0] char0,
    input [7:0] char1,
    input [7:0] char2,
    input [7:0] char3,
    input [7:0] char4,
    input [7:0] char5,
    input [7:0] char6,
    input [7:0] char7,
    output reg [3:0] max_run
);
wire is_upper_0;
assign is_upper_0 = (char0 >= 8'h41) && (char0 <= 8'h5A);
wire is_upper_1;
assign is_upper_1 = (char1 >= 8'h41) && (char1 <= 8'h5A);
wire is_upper_2;
assign is_upper_2 = (char2 >= 8'h41) && (char2 <= 8'h5A);
wire is_upper_3;
assign is_upper_3 = (char3 >= 8'h41) && (char3 <= 8'h5A);
wire is_upper_4;
assign is_upper_4 = (char4 >= 8'h41) && (char4 <= 8'h5A);
wire is_upper_5;
assign is_upper_5 = (char5 >= 8'h41) && (char5 <= 8'h5A);
wire is_upper_6;
assign is_upper_6 = (char6 >= 8'h41) && (char6 <= 8'h5A);
wire is_upper_7;
assign is_upper_7 = (char7 >= 8'h41) && (char7 <= 8'h5A);
wire [7:0] is_upper;
assign is_upper[0] = is_upper_0;
assign is_upper[1] = is_upper_1;
assign is_upper[2] = is_upper_2;
assign is_upper[3] = is_upper_3;
assign is_upper[4] = is_upper_4;
assign is_upper[5] = is_upper_5;
assign is_upper[6] = is_upper_6;
assign is_upper[7] = is_upper_7;
wire [3:0] run_length_7;
assign run_length_7 = is_upper[7] ? 1 : 0;
wire [3:0] run_length_6;
assign run_length_6 = is_upper[6] ? (1 + run_length_7) : 0;
wire [3:0] run_length_5;
assign run_length_5 = is_upper[5] ? (1 + run_length_6) : 0;
wire [3:0] run_length_4;
assign run_length_4 = is_upper[4] ? (1 + run_length_5) : 0;
wire [3:0] run_length_3;
assign run_length_3 = is_upper[3] ? (1 + run_length_4) : 0;
wire [3:0] run_length_2;
assign run_length_2 = is_upper[2] ? (1 + run_length_3) : 0;
wire [3:0] run_length_1;
assign run_length_1 = is_upper[1] ? (1 + run_length_2) : 0;
wire [3:0] run_length_0;
assign run_length_0 = is_upper[0] ? (1 + run_length_1) : 0;
wire [3:0] temp_max;
assign temp_max = run_length_0;
assign temp_max = (run_length_1 > temp_max) ? run_length_1 : temp_max;
assign temp_max = (run_length_2 > temp_max) ? run_length_2 : temp_max;
assign temp_max = (run_length_3 > temp_max) ? run_length_3 : temp_max;
assign temp_max = (run_length_4 > temp_max) ? run_length_4 : temp_max;
assign temp_max = (run_length_5 > temp_max) ? run_length_5 : temp_max;
assign temp_max = (run_length_6 > temp_max) ? run_length_6 : temp_max;
assign temp_max = (run_length_7 > temp_max) ? run_length_7 : temp_max;
assign max_run = temp_max;
endmodule