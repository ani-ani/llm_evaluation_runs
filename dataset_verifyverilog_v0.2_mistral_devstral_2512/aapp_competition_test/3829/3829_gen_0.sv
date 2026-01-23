module expected_max_dice (
  input clk,
  input rst_n,
  input start,
  input [15:0] m,
  input [15:0] n,
  output reg [31:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    CALCULATE,
    DONE
  } state_t;

  state_t state;
  reg [15:0] i_loop;  // Loop counter for i from 1 to m
  reg [15:0] j_loop;  // Loop counter for exponentiation (n iterations)
  reg [31:0] base;    // (i-1)/m in Q16.16
  reg [31:0] power;   // base^n in Q16.16
  reg [31:0] acc;     // Accumulator for the sum

  // Reset state
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i_loop <= 0;
      j_loop <= 0;
      base <= 0;
      power <= 0;
      acc <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CALCULATE;
            i_loop <= 1;
            acc <= 0;
          end
        end
        CALCULATE: begin
          if (i_loop < m) begin
            // Compute base = (i_loop - 1) / m in Q16.16
            base <= (i_loop - 1) << 16;
            base <= $signed(base) / m;
            
            // Compute power = base^n using a loop
            power <= 1 << 16;  // Initialize to 1.0 in Q16.16
            j_loop <= 0;
            
            if (j_loop < n) begin
              j_loop <= j_loop + 1;
              power <= $signed(power) * $signed(base) >> 16;  // Multiply and shift to maintain Q16.16
            end else begin
              // Compute P_max_ge_i = 1 - power
              reg [31:0] p_max_ge_i = (1 << 16) - power;
              
              // Accumulate into acc
              acc <= acc + p_max_ge_i;
              
              // Move to next i
              i_loop <= i_loop + 1;
            end
          end else begin
            // All iterations done
            result <= acc;
            state <= DONE;
            done <= 1;
          end
        end
        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule