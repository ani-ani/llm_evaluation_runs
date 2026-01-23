module ring_reconstruct ( 
input clk,
input rst_n, 
input start,
input [2:0] valid_count,
input [31:0] b0, b1, b2, b3, b4, b5, b6, b7,
output reg [31:0] a0, a1, a2, a3, a4, a5, a6, a7,
output reg done,
output reg error
);

reg [31:0] a_temp_reg [8]; 
reg [31:0] a_final [8]; 
reg [2:0] state; 
reg [3:0] cycle_count; 
reg [31:0] d; 
reg [31:0] k; 
reg [31:0] adjusted_a [8]; 
reg done_flag;
reg error_flag;

localparam IDLE = 0, INIT=1, CHECK=2, ADJUST=3, OUTPUT=4, DONE=5;

always @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      a_temp_reg <= 0;
a_final <=0;
      state <= IDLE;
      cycle_count <=0;
      d <=0;
      k <=0;
      done_flag <=0;
      error_flag <=0;
   end else begin
      if (start) begin
         case (state)
            IDLE: begin
               if (cycle_count ==0) begin
                  state <= INIT;
                  cycle_count <=0;
               end
            end
            INIT: begin
               if (cycle_count <2) begin
                  cycle_count <= cycle_count +1;
               end else begin
                  a_temp_reg[0] <= temp_a[0];
a_temp_reg[1] <= temp_a[1];
a_temp_reg[2] <= temp_a[2];
a_temp_reg[3] <= temp_a[3];
a_temp_reg[4] <= temp_a[4];
a_temp_reg[5] <= temp_a[5];
a_temp_reg[6] <= temp_a[6];
a_temp_reg[7] <= temp_a[7];
                  state <= CHECK;
                  cycle_count <=0;
               end
            end
            CHECK: begin
               if (cycle_count ==0) begin
                  d <= a_temp_reg[7] + a_temp_reg[0] + a_temp_reg[1] - b7;
                  cycle_count <=1;
               end else if (cycle_count <3) begin
                  cycle_count <= cycle_count +1;
               end else begin
                  state <= ADJUST;
                  cycle_count <=0;
               end
            end
            ADJUST: begin
               k <= d / 4;
               adjusted_a[0] = a_temp_reg[0] + k;
               adjusted_a[1] = a_temp_reg[1] - k;
               adjusted_a[2] = a_temp_reg[2] + k;
               adjusted_a[3] = a_temp_reg[3] - k;
               adjusted_a[4] = a_temp_reg[4] + k;
               adjusted_a[5] = a_temp_reg[5] - k;
               adjusted_a[6] = a_temp_reg[6] + k;
               adjusted_a[7] = a_temp_reg[7] - k;
               error_flag <= 0;
               error_flag |= (adjusted_a[0] < 32'd0);
               error_flag |= (adjusted_a[1] < 32'd0);
               error_flag |= (adjusted_a[2] < 32'd0);
               error_flag |= (adjusted_a[3] < 32'd0);
               error_flag |= (adjusted_a[4] < 32'd0);
               error_flag |= (adjusted_a[5] < 32'd0);
               error_flag |= (adjusted_a[6] < 32'd0);
               error_flag |= (adjusted_a[7] < 32'd0);
               if (cycle_count <5) begin
                  cycle_count <= cycle_count +1;
               end else begin
                  a_final <= adjusted_a;
                  state <= OUTPUT;
                  cycle_count <=0;
               end
            end
            OUTPUT: begin
               a0 <= a_final[0];
a1 <= a_final[1];
a2 <= a_final[2];
a3 <= a_final[3];
a4 <= a_final[4];
a5 <= a_final[5];
a6 <= a_final[6];
a7 <= a_final[7];
               done_flag <=1;
               if (cycle_count <5) begin
                  cycle_count <= cycle_count +1;
               end else begin
                  state <= DONE;
                  cycle_count <=0;
               end
            end
            DONE: begin
               if (cycle_count <5) begin
                  cycle_count <= cycle_count +1;
               end
            end
         endcase
      end // if start
   end // else if not reset
end // always @clk

reg [31:0] temp_a [8];
always @(*) begin
   temp_a[0] = 0;
   temp_a[1] = b0 - temp_a[0];
   temp_a[2] = b1 - temp_a[1] - temp_a[0];
   temp_a[3] = b2 - temp_a[2] - temp_a[1];
   temp_a[4] = b3 - temp_a[3] - temp_a[2];
   temp_a[5] = b4 - temp_a[4] - temp_a[3];
   temp_a[6] = b5 - temp_a[5] - temp_a[4];
   temp_a[7] = b6 - temp_a[6] - temp_a[5];
end

assign a0 = a_final[0];
assign a1 = a_final[1];
assign a2 = a_final[2];
assign a3 = a_final[3];
assign a4 = a_final[4];
assign a5 = a_final[5];
assign a6 = a_final[6];
assign a7 = a_final[7];
assign done = done_flag;
assign error = error_flag;

endmodule