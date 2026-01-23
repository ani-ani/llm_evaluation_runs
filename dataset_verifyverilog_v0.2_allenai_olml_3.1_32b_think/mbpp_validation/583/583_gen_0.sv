module catalan_number (
 input clk,
 input rst_n, // active-low reset
 input start,
 input [4:0] n,
 output reg [31:0] result,
 output reg done
);

reg [31:0] catalan [11];
reg [3:0] current_i;
reg [3:0] current_j;
reg [31:0] sum_temp;
reg [4:0] state;
reg [4:0] n_value;

localparam IDLE = 4'd0,
INIT = 4'd1,
COMPUTE_I = 4'd2,
COMPUTE_SUM = 4'd3,
UPDATE_CATALAN = 4'd4,
DONE = 4'd5;

always @(posedge clk) begin
   if (!rst_n) begin
      catalan <= 0;
      current_i <=0;
      current_j <=0;
      sum_temp <=0;
      state <= IDLE;
      n_value <=0;
      result <=0;
      done <=0;
   end else begin
      if (state == IDLE) begin
         if (start == 1'b1) begin
            n_value <= (n > 10) ? 10 : n;
            state <= INIT;
         end
      end else if (state == INIT) begin
         catalan[0] <= 1;
         catalan[1] <=1;
         if (n_value ==0 || n_value ==1) begin
            result <= catalan[n_value];
            done <=1'b1;
            state <= DONE;
         end else begin
            current_i <=2;
            state <= COMPUTE_I;
         end
      end else if (state == COMPUTE_I) begin
         sum_temp <=0;
         current_j <=0;
         state <= COMPUTE_SUM;
      end else if (state == COMPUTE_SUM) begin
         if (current_j < current_i) begin
            sum_temp <= sum_temp + catalan[current_j] * catalan[current_i -1 - current_j];
            current_j <= current_j +1;
         end else begin
            state <= UPDATE_CATALAN;
         end
      end else if (state == UPDATE_CATALAN) begin
         catalan[current_i] <= sum_temp;
         if (current_i == n_value) begin
            result <= catalan[n_value];
            done <=1'b1;
            state <= DONE;
         end else begin
            current_i <= current_i +1;
            if (current_i > n_value) begin
               result <= catalan[n_value];
               done <=1'b1;
               state <= DONE;
            end else begin
               state <= COMPUTE_I;
            end
         end
      end
   end
endmodule