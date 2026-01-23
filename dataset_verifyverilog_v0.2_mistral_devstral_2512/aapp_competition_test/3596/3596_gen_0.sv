module opponent_location_calculator(
  input clk,
  input rst_n,
  input start,
  input [31:0] a,
  input [31:0] b,
  input [31:0] c,
  input [31:0] l,
  output reg [63:0] result,
  output reg done
);

  // Constants in Q16.16 format
  localparam PI = 32'h0001_999A; // 3.244 in Q16.16
  localparam E = 32'h0001_13B5;   // 2.718 in Q16.16
  localparam ONE = 32'h0001_0000; // 1.0 in Q16.16
  localparam TWO = 32'h0002_0000; // 2.0 in Q16.16

  // State machine
  typedef enum logic [1:0] {
    IDLE,
    CALC_INTEGRAL,
    CALC_FINAL,
    DONE
  } state_t;
  state_t state, next_state;

  // Internal registers
  reg [31:0] integral_result;
  reg [31:0] midpoint;
  reg [31:0] partition_width;
  reg [2:0] partition_counter;
  reg [31:0] l_squared;
  reg [31:0] pi_times_e;
  reg [31:0] l_plus_one;
  reg [31:0] inv_l_plus_one;
  reg [31:0] temp1, temp2;
  reg [31:0] cycle_count;

  // Fixed-point multiplication and division functions
  function [31:0] fp_mult;
    input [31:0] a, b;
    begin
      fp_mult = $signed((a * b) >>> 16);
    end
  endfunction

  function [31:0] fp_div;
    input [31:0] a, b;
    begin
      fp_div = $signed((a << 16) / b);
    end
  endfunction

  // Taylor series approximation of f(t) = 0 (simplified)
  function [31:0] f_t;
    input [31:0] t;
    begin
      f_t = 32'h0000_0000; // f(t) ≈ 0 due to simplification
    end
  endfunction

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      integral_result <= 32'h0000_0000;
      partition_counter <= 3'd0;
      cycle_count <= 32'h0000_0000;
    end else begin
      state <= next_state;
    end
  end

  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = CALC_INTEGRAL;
          partition_width = fp_div((b - a), 8); // (b-a)/8
          integral_result = 32'h0000_0000;
          partition_counter = 3'd0;
          cycle_count = 32'h0000_0000;
        end
      end
      CALC_INTEGRAL: begin
        if (partition_counter < 8) begin
          // Calculate midpoint for current partition
          midpoint = a + fp_mult(partition_width, (partition_counter + 1)) - fp_mult(partition_width, 1);
          // Add f(midpoint) to integral
          integral_result = integral_result + f_t(midpoint);
          partition_counter = partition_counter + 1;
        end else begin
          next_state = CALC_FINAL;
        end
      end
      CALC_FINAL: begin
        if (cycle_count < 200) begin
          cycle_count = cycle_count + 1;
        end else begin
          // Compute l^2
          l_squared = fp_mult(l, l);
          // Compute π * e
          pi_times_e = fp_mult(PI, E);
          // Compute l^2 / (π * e)
          temp1 = fp_div(l_squared, pi_times_e);
          // Compute l + 1
          l_plus_one = l + ONE;
          // Compute 1 / (l + 1)
          inv_l_plus_one = fp_div(ONE, l_plus_one);
          // Final result: (l^2)/(π*e) + 1/(l+1)
          temp2 = temp1 + inv_l_plus_one;
          // Convert to Q32.32
          result = {32'h0000_0000, temp2};
          next_state = DONE;
        end
      end
      DONE: begin
        done = 1'b1;
        if (!start) begin
          next_state = IDLE;
          done = 1'b0;
        end
      end
    endcase
  end

endmodule