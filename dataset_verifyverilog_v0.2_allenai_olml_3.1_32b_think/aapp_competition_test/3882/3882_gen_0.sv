module sym_trans_count (
input clk,
input rst_n, 
input start,
input [3:0] n,
output reg [29:0] result,
output reg done
);

parameter P = 1000000007;

localparam IDLE = 3'b000,
INIT = 3'b001,
ROW_LOOP = 3'b010,
COL_LOOP =3'b011,
CALC =3'b100,
DONE =3'b101;

reg [31:0] A [9][9]; 

reg [2:0] i;

reg [3:0] j;

reg [3:0] n_reg; 

reg [2:0] state;

reg [29:0] result_reg; 

always @(posedge clk) begin
   if (!rst_n) begin
      A <= {{9{9{1'b0}}}}; 
      i <= 0;
      j <=0;
      n_reg <=0;
      state <= IDLE;
      result_reg <=0;
   end else begin
      case (state)
         IDLE: begin
            if (start) begin
               state <= INIT;
            end
         end
         INIT: begin
            A[0][0] <= 1;
            i <= 1;
            j <=1; 
            n_reg <= n;
            state <= ROW_LOOP;
         end
         ROW_LOOP: begin
            if (i <= n_reg) begin
               A[i][0] <= A[i-1][i-1];
               j <=1; 
               state <= COL_LOOP;
            end else begin
               state <= DONE;
            end
         end
         COL_LOOP: begin
            if (j > i) begin
               i <= i +1;
               j <=1; 
               state <= ROW_LOOP;
            end else begin
               state <= CALC;
            end
         end
         CALC: begin
            reg [31:0] temp;
            temp = A[i][j-1] + A[i-1][j-1];
            if (temp >= P) temp = temp - P;
            A[i][j] <= temp;
            j <= j +1;
            state <= COL_LOOP;
         end
         DONE: begin
            result_reg <= A[n_reg][n_reg -1];
            done <=1;
         end
      endcase
   end
end

assign result = result_reg[29:0];
assign done = done;

endmodule