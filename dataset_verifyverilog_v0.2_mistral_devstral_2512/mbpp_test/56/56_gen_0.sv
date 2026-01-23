module check_reverse (
  input clk,
  input rst_n,
  input start,
  input [7:0] n,
  output reg result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    REVERSE_LOOP,
    CALCULATE,
    COMPARE,
    DONE
  } state_t;

  // Internal registers
  state_t state;
  reg [15:0] rev;
  reg [15:0] temp_n;
  reg [15:0] two_rev;
  reg [15:0] n_plus_one;
  reg [3:0] digit_count;

  // Reset state
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      rev <= 0;
      temp_n <= 0;
      two_rev <= 0;
      n_plus_one <= 0;
      digit_count <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= REVERSE_LOOP;
            temp_n <= n;
            rev <= 0;
            digit_count <= 0;
          end
        end
        REVERSE_LOOP: begin
          if (temp_n > 0) begin
            rev <= rev * 10 + temp_n % 10;
            temp_n <= temp_n / 10;
            digit_count <= digit_count + 1;
          end else begin
            state <= CALCULATE;
          end
        end
        CALCULATE: begin
          two_rev <= rev * 2;
          n_plus_one <= n + 1;
          state <= COMPARE;
        end
        COMPARE: begin
          result <= (two_rev == n_plus_one);
          state <= DONE;
        end
        DONE: begin
          done <= 1;
          if (!start) begin
            done <= 0;
            state <= IDLE;
          end
        end
      endcase
    end
  end

endmodule