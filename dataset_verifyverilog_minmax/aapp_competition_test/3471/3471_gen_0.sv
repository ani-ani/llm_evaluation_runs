module xorbonacci_queries(
  input clk,
  input rst_n,
  input start,
  input [1:0] K,
  input [7:0] a1, a2, a3, a4,
  input [1:0] Q,
  input [3:0] l1, r1,
  input [3:0] l2, r2,
  input [3:0] l3, r3,
  input [3:0] l4, r4,
  output reg done,
  output reg [7:0] res1,
  output reg [7:0] res2,
  output reg [7:0] res3,
  output reg [7:0] res4
);

parameter IDLE = 2'b00;
parameter GEN = 2'b01;
parameter QUERY = 2'b10;

reg [1:0] state, K_reg, Q_reg;
reg [3:0] count, l1_r, r1_r, l2_r, r2_r, l3_r, r3_r, l4_r, r4_r;
reg [7:0] a1_reg, a2_reg, a3_reg, a4_reg;
reg [7:0] x [0:15];

integer i;

always @(posedge clk) begin
  if (rst_n == 0) begin
    state <= IDLE;
    done <= 0;
    count <= 0;
  end else begin
    case (state)
      IDLE: begin
        done <= 0;
        if (start) begin
          state <= GEN;
          count <= 0;
          K_reg <= K;
          a1_reg <= a1;
          a2_reg <= a2;
          a3_reg <= a3;
          a4_reg <= a4;
          Q_reg <= Q;
          l1_r <= l1;
          r1_r <= r1;
          l2_r <= l2;
          r2_r <= r2;
          l3_r <= l3;
          r3_r <= r3;
          l4_r <= l4;
          r4_r <= r4;
        end
      end
      GEN: begin
        if (count < 16) begin
          if (count < K_reg) begin
            case (count)
              0: x[count] <= a1_reg;
              1: x[count] <= a2_reg;
              2: x[count] <= a3_reg;
              3: x[count] <= a4_reg;
            endcase
          end else begin
            if (K_reg == 1) begin
              x[count] <= x[count-1];
            end else if (K_reg == 2) begin
              x[count] <= x[count-1] ^ x[count-2];
            end else if (K_reg == 3) begin
              x[count] <= x[count-1] ^ x[count-2] ^ x[count-3];
            end else if (K_reg == 4) begin
              x[count] <= x[count-1] ^ x[count-2] ^ x[count-3] ^ x[count-4];
            end
          end
          count <= count + 1;
        end else begin
          state <= QUERY;
        end
      end
      QUERY: begin
        // Compute result for query 1
        res1 = 0;
        if (Q_reg >= 1) begin
          for (i = l1_r-1; i <= r1_r-1; i = i+1) begin
            res1 = res1 ^ x[i];
          end
        end
        
        // Compute result for query 2
        res2 = 0;
        if (Q_reg >= 2) begin
          for (i = l2_r-1; i <= r2_r-1; i = i+1) begin
            res2 = res2 ^ x[i];
          end
        end
        
        // Compute result for query 3
        res3 = 0;
        if (Q_reg >= 3) begin
          for (i = l3_r-1; i <= r3_r-1; i = i+1) begin
            res3 = res3 ^ x[i];
          end
        end
        
        // Compute result for query 4
        res4 = 0;
        if (Q_reg >= 4) begin
          for (i = l4_r-1; i <= r4_r-1; i = i+1) begin
            res4 = res4 ^ x[i];
          end
        end
        
        done <= 1;
        state <= IDLE;
      end
    endcase
  end
end

endmodule