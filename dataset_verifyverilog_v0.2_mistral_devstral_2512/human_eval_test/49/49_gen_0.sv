module modp (
  input clk,
  input rst_n,
  input start,
  input [7:0] n,
  input [7:0] p,
  output reg [7:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    CALCULATING,
    DONE
  } state_t;

  state_t state;
  reg [7:0] base;
  reg [7:0] remaining_n;
  reg [3:0] bit_counter;

  // Modulo multiplication function
  function [7:0] mod_mult;
    input [7:0] a;
    input [7:0] b;
    input [7:0] mod;
    begin
      mod_mult = (a * b) % mod;
    end
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 0;
      base <= 0;
      remaining_n <= 0;
      bit_counter <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CALCULATING;
            result <= 1;
            base <= 2;
            remaining_n <= n;
            bit_counter <= 0;
            done <= 0;
          end
        end
        CALCULATING: begin
          if (bit_counter < 8) begin
            // Process current bit
            if (remaining_n[0]) begin
              result <= mod_mult(result, base, p);
            end
            base <= mod_mult(base, base, p);
            remaining_n <= remaining_n >> 1;
            bit_counter <= bit_counter + 1;
          end else begin
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