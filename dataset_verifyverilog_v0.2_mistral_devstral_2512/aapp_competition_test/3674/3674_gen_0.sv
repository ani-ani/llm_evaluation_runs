module math_problem_solver (
  input clk,
  input rst_n,
  input start,
  input [7:0] m,
  input [7:0] n,
  input [31:0] p,
  input [31:0] q,
  output reg [63:0] result,
  output reg found,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    COMPUTE_CANDIDATE,
    VERIFY,
    DONE
  } state_t;

  state_t state;
  reg [63:0] prefix;
  reg [63:0] base;
  reg [63:0] base2;
  reg [63:0] digits_p;
  reg [63:0] max_prefix;
  reg [63:0] candidate_x;
  reg [63:0] y_part;
  reg [63:0] y_candidate;
  reg [63:0] p_added;
  reg [63:0] temp;
  reg [63:0] counter;

  // Compute number of digits in p
  always @(*) begin
    digits_p = 1;
    if (p >= 10) digits_p = 2;
    if (p >= 100) digits_p = 3;
    if (p >= 1000) digits_p = 4;
    if (p >= 10000) digits_p = 5;
    if (p >= 100000) digits_p = 6;
    if (p >= 1000000) digits_p = 7;
    if (p >= 10000000) digits_p = 8;
    if (p >= 100000000) digits_p = 9;
    if (p >= 1000000000) digits_p = 10;
  end

  // Compute powers of 10
  function [63:0] pow10;
    input [31:0] exp;
    integer i;
    pow10 = 1;
    for (i = 0; i < exp; i = i + 1) begin
      pow10 = pow10 * 10;
    end
  endfunction

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 0;
      found <= 0;
      done <= 0;
      prefix <= 0;
      counter <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= COMPUTE_CANDIDATE;
            result <= 0;
            found <= 0;
            done <= 0;
            prefix <= pow10(n - 1);
            max_prefix <= pow10(n) - 1;
            base <= pow10(digits_p);
            base2 <= pow10(m - n - digits_p);
            counter <= 0;
          end
        end
        COMPUTE_CANDIDATE: begin
          // Compute candidate X
          temp = prefix * base2 * base + p * base2 + (prefix * base2) % q;
          candidate_x = temp * q;
          
          // Compute Y_part
          y_part = (candidate_x / pow10(m - n)) * base + p;
          
          state <= VERIFY;
        end
        VERIFY: begin
          // Verify if X = Y_part * q
          if (candidate_x == y_part * q) begin
            result <= candidate_x;
            found <= 1;
            state <= DONE;
          end else begin
            // Move to next prefix
            prefix <= prefix + 1;
            counter <= counter + 1;
            
            if (prefix > max_prefix || counter > 1000) begin
              state <= DONE;
            end else begin
              state <= COMPUTE_CANDIDATE;
            end
          end
        end
        DONE: begin
          done <= 1;
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule