module salary_damage_calculator (
  input clk,
  input rst_n,
  input start,
  input [31:0] L0, R0,
  input [31:0] L1, R1,
  input [31:0] L2, R2,
  input [31:0] L3, R3,
  output reg [31:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    CALCE,
    CALCSUM,
    DIVIDE,
    DONE
  } state_t;

  state_t state;
  reg [31:0] E [0:3];
  reg [31:0] sum;
  reg [4:0] cycle_count;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      result <= 32'b0;
      cycle_count <= 5'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CALCE;
            done <= 1'b0;
            cycle_count <= 5'b0;
          end
        end
        CALCE: begin
          // Compute expected values E[i] = (L[i] + R[i]) / 2
          E[0] <= (L0 + R0) >> 1;
          E[1] <= (L1 + R1) >> 1;
          E[2] <= (L2 + R2) >> 1;
          E[3] <= (L3 + R3) >> 1;
          state <= CALCSUM;
          cycle_count <= 5'b0;
        end
        CALCSUM: begin
          // Compute sum of pairwise differences
          if (cycle_count == 0) begin
            sum <= E[1] - E[0];
          end else if (cycle_count == 1) begin
            sum <= sum + (E[2] - E[0]);
          end else if (cycle_count == 2) begin
            sum <= sum + (E[3] - E[0]);
          end else if (cycle_count == 3) begin
            sum <= sum + (E[2] - E[1]);
          end else if (cycle_count == 4) begin
            sum <= sum + (E[3] - E[1]);
          end else if (cycle_count == 5) begin
            sum <= sum + (E[3] - E[2]);
            state <= DIVIDE;
          end
          cycle_count <= cycle_count + 1;
        end
        DIVIDE: begin
          // Divide by 16 (N^2 = 4^2 = 16)
          result <= sum >> 4;
          state <= DONE;
        end
        DONE: begin
          done <= 1'b1;
          if (!start) begin
            state <= IDLE;
            done <= 1'b0;
          end
        end
      endcase
    end
  end

endmodule