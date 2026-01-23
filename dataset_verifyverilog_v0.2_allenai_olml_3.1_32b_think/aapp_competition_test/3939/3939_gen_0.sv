module slime_k_solver (
 input clk,
 input rst_n,
 input start,
 input [7:0] k,
 input [7:0] a_0, a_1, a_2, a_3, a_4, a_5, a_6, a_7,
 output reg result, output reg done);
reg [2:0] state;
reg exist_k;
reg done_delay;
reg adjacent_ok;
reg distance2_ok;
always @(posedge clk) begin
 if (!rst_n) begin
 state <= 3'b000;
 exist_k <=0;
 done <=0;
 result <=0;
 done_delay <=0;
 adjacent_ok <=0;
 distance2_ok <=0;
 end else begin
 case (state)
 3'b000: begin
 if (start)
 state <= 3'b001;
 end
 3'b001: begin
 exist_k = (a_0 == k) || (a_1 == k) || (a_2 == k) || (a_3 == k) || (a_4 == k) || (a_5 == k) || (a_6 == k) || (a_7 == k);
 state <= 3'b010;
 end
 3'b010: begin
 adjacent_ok = ( (a_0 >=k && a_1 >=k) || (a_1 >=k && a_2 >=k) || (a_2 >=k && a_3 >=k) || (a_3 >=k && a_4 >=k) || (a_4 >=k && a_5 >=k) || (a_5 >=k && a_6 >=k) || (a_6 >=k && a_7 >=k) );
 distance2_ok = ( (a_0 >=k && a_2 >=k) || (a_1 >=k && a_3 >=k) || (a_2 >=k && a_4 >=k) || (a_3 >=k && a_5 >=k) || (a_4 >=k && a_6 >=k) || (a_5 >=k && a_7 >=k) );
 if (!exist_k) begin
 result <=0;
 end else begin
 result <= (adjacent_ok || distance2_ok);
 end
 state <= 3'b100;
 done_delay <=0;
 end
 3'b100: begin
 if (done_delay ==0) begin
 done <=0;
 done_delay <=1;
 end else begin
 done <=1;
 done_delay <=1;
 end
 endcase
 end
end
endmodule