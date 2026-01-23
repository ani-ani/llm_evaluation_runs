module subset_sum_solver (
  input clk,
  input rst_n,
  input start,
  input [63:0] x_in [0:7],
  output reg [63:0] result,
  output reg done
);

  // Constants
  localparam MOD = 1000000007;
  localparam [2:0] IDLE = 3'b000;
  localparam [2:0] LOAD = 3'b001;
  localparam [2:0] CALC = 3'b010;
  localparam [2:0] DONE = 3'b100;

  // Pre-calculated powers of 2
  localparam [63:0] pow2 [0:7] = '{1, 2, 4, 8, 16, 32, 64, 128};

  // State machine
  reg [2:0] state = IDLE;
  reg [2:0] next_state = IDLE;

  // Internal registers
  reg [63:0] x_reg [0:7];
  reg [127:0] acc = 0;
  reg [5:0] i = 0;

  // State transitions
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      i <= 0;
      acc <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    case (state)
      IDLE: begin
        if (start) next_state = LOAD;
        else next_state = IDLE;
      end
      LOAD: next_state = CALC;
      CALC: begin
        if (i == 7) next_state = DONE;
        else next_state = CALC;
      end
      DONE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
      result <= 0;
      i <= 0;
      acc <= 0;
    end else begin
      case (state)
        LOAD: begin
          for (int j = 0; j < 8; j = j + 1) begin
            x_reg[j] <= x_in[j];
          end
          i <= 0;
          acc <= 0;
        end
        CALC: begin
          if (i < 8) begin
            // Compute term = x_reg[i] * (pow2[i] - pow2[7-i])
            reg [127:0] term;
            reg [63:0] coeff = pow2[i] - pow2[7-i];
            term = $signed(x_reg[i]) * $signed(coeff);
            
            // Accumulate with modulo
            acc = acc + term;
            
            // Modulo operation
            if (acc[127]) begin
              acc = acc + MOD;
            end
            acc = acc % MOD;
            
            i <= i + 1;
          end
        end
        DONE: begin
          done <= 1;
          result <= acc[63:0];
        end
        default: begin
          done <= 0;
        end
      endcase
    end
  end

endmodule