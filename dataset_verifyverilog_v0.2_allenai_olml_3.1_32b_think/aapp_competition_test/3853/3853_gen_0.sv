module magic_boxes ( input clk, input rst_n, input start, input [4:0] k_in, input [19:0] a_in, input [1:0] type_index, input valid_in, output reg [5:0] result, output reg done );
parameter IDLE = 3'd0;
parameter CAPTURE = 3'd1;
parameter COMPUTE = 3'd2;
parameter DONE = 3'd3;
reg [4:0] k_reg [4];
reg [19:0] a_reg [4];
reg [3:0] captured;
reg [2:0] capture_count;
reg [2:0] state;
reg [5:0] result;
reg done;
function [3:0] compute_n;
 input [19:0] a;
 begin
 if (a == 0) return 4'd0;
 else if (a <= 1) return 4'd0;
 else if (a <= 4) return 4'd1;
 else if (a <= 16) return 4'd2;
 else if (a <= 64) return 4'd3;
 else if (a <= 256) return 4'd4;
 else if (a <= 1024) return 4'd5;
 else if (a <= 4096) return 4'd6;
 else if (a <= 16384) return 4'd7;
 else if (a <= 65536) return 4'd8;
 else if (a <= 262144) return 4'd9;
 else return 4'd10;
 end
always @(posedge clk) begin
 if (!rst_n) begin
 state <= IDLE;
 k_reg <= 0;
 a_reg <= 0;
 captured <= 0;
 capture_count <=0;
 result <=0;
 done <=0;
 end else begin
 done <=0;
 case (state)
 IDLE: begin
 if (start) begin
 state <= CAPTURE;
 k_reg <= 0;
 a_reg <=0;
 captured <=0;
 capture_count <=0;
 end
 end
 CAPTURE: begin
 if (valid_in) begin
 if (type_index >=0 && type_index <=3) begin
 if (!captured[type_index]) begin
 captured[type_index] =1;
 k_reg[type_index] = k_in;
 a_reg[type_index] = a_in;
 capture_count <= capture_count +1;
 end
 end
 end
 if (capture_count ==4) begin
 state <= COMPUTE;
 end
 end
 COMPUTE: begin
 wire [3:0] p0, p1, p2, p3;
 wire [3:0] max_p;
 p0 = k_reg[0] + compute_n(a_reg[0]);
 p1 = k_reg[1] + compute_n(a_reg[1]);
 p2 = k_reg[2] + compute_n(a_reg[2]);
 p3 = k_reg[3] + compute_n(a_reg[3]);
 max_p = p0 > p1 ? p0 : p1;
 max_p = max_p > p2 ? max_p : p2;
 max_p = max_p > p3 ? max_p : p3;
 result <= max_p;
 state <= DONE;
 end
 DONE: begin
 if (start) begin
 state <= IDLE;
 k_reg <=0;
 a_reg <=0;
 captured <=0;
 capture_count <=0;
 result <=0;
 done <=0;
 end
 done <=1;
 endcase
 end
 end
endmodule