module martian_tax_solver (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [4:0] k,
  input [29:0] a,
  output reg [4:0] result_d,
  output reg [2:0] result_index,
  output reg valid,
  output reg done
);

  // States
  typedef enum logic [1:0] {
    IDLE,
    GCD_CALC,
    RESULT_GEN
  } state_t;
  state_t state, next_state;

  // Internal registers
  reg [4:0] g; // Current GCD
  reg [2:0] i; // Index for denominations
  reg [4:0] m; // Multiplier for result generation
  reg [4:0] current_gcd; // Final GCD

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      g <= 0;
      i <= 0;
      m <= 0;
      current_gcd <= 0;
      result_d <= 0;
      result_index <= 0;
      valid <= 0;
      done <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = GCD_CALC;
      end
      GCD_CALC: begin
        if (i == n) next_state = RESULT_GEN;
      end
      RESULT_GEN: begin
        if (m == k) next_state = IDLE;
      end
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      g <= 0;
      i <= 0;
      m <= 0;
      current_gcd <= 0;
      result_d <= 0;
      result_index <= 0;
      valid <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          // Reset outputs
          valid <= 0;
          done <= 0;
        end
        GCD_CALC: begin
          if (i == 0) begin
            // Initialize g with first denomination
            g <= a[5:0];
            i <= i + 1;
          end else if (i < n) begin
            // Compute gcd(g, a[i])
            reg [4:0] a_val = a[(i*6)+5:i*6];
            reg [4:0] temp_g = gcd_calc(g, a_val);
            g <= temp_g;
            i <= i + 1;
          end else begin
            // Final gcd with k
            current_gcd <= gcd_calc(g, k);
          end
        end
        RESULT_GEN: begin
          if (m == 0) begin
            // First result
            result_d <= (m * current_gcd) % k;
            result_index <= m;
            valid <= 1;
            done <= 0;
            m <= m + 1;
          end else if (m < k) begin
            // Subsequent results
            result_d <= (m * current_gcd) % k;
            result_index <= m;
            valid <= 1;
            done <= (m == k-1);
            m <= m + 1;
          end else begin
            // Done
            valid <= 0;
            done <= 1;
          end
        end
      endcase
    end
  end

  // GCD calculation function
  function [4:0] gcd_calc(input [4:0] a, input [4:0] b);
    reg [4:0] x = a;
    reg [4:0] y = b;
    while (y != 0) begin
      reg [4:0] temp = y;
      y = x % y;
      x = temp;
    end
    gcd_calc = x;
  endfunction

endmodule