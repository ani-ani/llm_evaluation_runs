module get_positive (
    input [7:0][7:0] data_in,
    input [2:0] count,
    output reg [7:0] data_out_0,
    output reg [7:0] data_out_1,
    output reg [7:0] data_out_2,
    output reg [7:0] data_out_3,
    output reg [7:0] data_out_4,
    output reg [7:0] data_out_5,
    output reg [7:0] data_out_6,
    output reg [7:0] data_out_7,
    output reg [2:0] out_count
);

reg [7:0] valid;
always @(*) begin
    valid[0] = (count > 0) ? ((data_in[0][7] == 0) && |data_in[0]|) : 0;
    valid[1] = (count > 1) ? ((data_in[1][7] == 0) && |data_in[1]|) : 0;
    valid[2] = (count > 2) ? ((data_in[2][7] == 0) && |data_in[2]|) : 0;
    valid[3] = (count > 3) ? ((data_in[3][7] == 0) && |data_in[3]|) : 0;
    valid[4] = (count > 4) ? ((data_in[4][7] == 0) && |data_in[4]|) : 0;
    valid[5] = (count > 5) ? ((data_in[5][7] == 0) && |data_in[5]|) : 0;
    valid[6] = (count > 6) ? ((data_in[6][7] == 0) && |data_in[6]|) : 0;
    valid[7] = (count > 7) ? ((data_in[7][7] == 0) && |data_in[7]|) : 0;
end

wire [3:0] prefix [0:7];
assign prefix[0] = 0;
assign prefix[1] = valid[0];
assign prefix[2] = prefix[1] + valid[1];
assign prefix[3] = prefix[2] + valid[2];
assign prefix[4] = prefix[3] + valid[3];
assign prefix[5] = prefix[4] + valid[4];
assign prefix[6] = prefix[5] + valid[5];
assign prefix[7] = prefix[6] + valid[6];

assign out_count = valid[0] + valid[1] + valid[2] + valid[3] + valid[4] + valid[5] + valid[6] + valid[7];

assign data_out_0 = (valid[0] && prefix[0] == 0) ? data_in[0] : (valid[1] && prefix[1] == 0) ? data_in[1] : (valid[2] && prefix[2] == 0) ? data_in[2] : (valid[3] && prefix[3] == 0) ? data_in[3] : (valid[4] && prefix[4] == 0) ? data_in[4] : (valid[5] && prefix[5] == 0) ? data_in[5] : (valid[6] && prefix[6] == 0) ? data_in[6] : (valid[7] && prefix[7] == 0) ? data_in[7] : 8'b0;
assign data_out_1 = (valid[0] && prefix[0] == 1) ? data_in[0] : (valid[1] && prefix[1] == 1) ? data_in[1] : (valid[2] && prefix[2] == 1) ? data_in[2] : (valid[3] && prefix[3] == 1) ? data_in[3] : (valid[4] && prefix[4] == 1) ? data_in[4] : (valid[5] && prefix[5] == 1) ? data_in[5] : (valid[6] && prefix[6] == 1) ? data_in[6] : (valid[7] && prefix[7] == 1) ? data_in[7] : 8'b0;
assign data_out_2 = (valid[0] && prefix[0] == 2) ? data_in[0] : (valid[1] && prefix[1] == 2) ? data_in[1] : (valid[2] && prefix[2] == 2) ? data_in[2] : (valid[3] && prefix[3] == 2) ? data_in[3] : (valid[4] && prefix[4] == 2) ? data_in[4] : (valid[5] && prefix[5] == 2) ? data_in[5] : (valid[6] && prefix[6] == 2) ? data_in[6] : (valid[7] && prefix[7] == 2) ? data_in[7] : 8'b0;
assign data_out_3 = (valid[0] && prefix[0] == 3) ? data_in[0] : (valid[1] && prefix[1] == 3) ? data_in[1] : (valid[2] && prefix[2] == 3) ? data_in[2] : (valid[3] && prefix[3] == 3) ? data_in[3] : (valid[4] && prefix[4] == 3) ? data_in[4] : (valid[5] && prefix[5] == 3) ? data_in[5] : (valid[6] && prefix[6] == 3) ? data_in[6] : (valid[7] && prefix[7] == 3) ? data_in[7] : 8'b0;
assign data_out_4 = (valid[0] && prefix[0] == 4) ? data_in[0] : (valid[1] && prefix[1] == 4) ? data_in[1] : (valid[2] && prefix[2] == 4) ? data_in[2] : (valid[3] && prefix[3] == 4) ? data_in[3] : (valid[4] && prefix[4] == 4) ? data_in[4] : (valid[5] && prefix[5] == 4) ? data_in[5] : (valid[6] && prefix[6] == 4) ? data_in[6] : (valid[7] && prefix[7] == 4) ? data_in[7] : 8'b0;
assign data_out_5 = (valid[0] && prefix[0] == 5) ? data_in[0] : (valid[1] && prefix[1] == 5) ? data_in[1] : (valid[2] && prefix[2] == 5) ? data_in[2] : (valid[3] && prefix[3] == 5) ? data_in[3] : (valid[4] && prefix[4] == 5) ? data_in[4] : (valid[5] && prefix[5] == 5) ? data_in[5] : (valid[6] && prefix[6] == 5) ? data_in[6] : (valid[7] && prefix[7] == 5) ? data_in[7] : 8'b0;
assign data_out_6 = (valid[0] && prefix[0] == 6) ? data_in[0] : (valid[1] && prefix[1] == 6) ? data_in[1] : (valid[2] && prefix[2] == 6) ? data_in[2] : (valid[3] && prefix[3] == 6) ? data_in[3] : (valid[4] && prefix[4] == 6) ? data_in[4] : (valid[5] && prefix[5] == 6) ? data_in[5] : (valid[6] && prefix[6] == 6) ? data_in[6] : (valid[7] && prefix[7] == 6) ? data_in[7] : 8'b0;
assign data_out_7 = (valid[0] && prefix[0] == 7) ? data_in[0] : (valid[1] && prefix[1] == 7) ? data_in[1] : (valid[2] && prefix[2] == 7) ? data_in[2] : (valid[3] && prefix[3] == 7) ? data_in[3] : (valid[4] && prefix[4] == 7) ? data_in[4] : (valid[5] && prefix[5] == 7) ? data_in[5] : (valid[6] && prefix[6] == 7) ? data_in[6] : (valid[7] && prefix[7] == 7) ? data_in[7] : 8'b0;
endmodule