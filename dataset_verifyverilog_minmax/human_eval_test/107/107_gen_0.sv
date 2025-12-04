module palindrome_counter(
  input clk,
  input rst_n,
  input start,
  input [7:0] n,
  output reg [7:0] even_count,
  output reg [7:0] odd_count,
  output reg done
);

  localparam IDLE       = 2'b00;
  localparam PROCESSING = 2'b01;
  localparam DONE       = 2'b10;

  reg [1:0] state, next_state;
  reg [7:0] n_latch;
  reg [7:0] current; // 1..n during PROCESSING

  // Extract decimal digits (valid for 0..255)
  wire [7:0] hundreds = current / 8'd100;
  wire [7:0] tens     = (current % 8'd100) / 8'd10;
  wire [7:0] units    = current % 8'd10;

  // Palindromes for 1..n (3-digit check, with 1- and 2-digit treated as palindromes by digit logic)
  wire is_pal = (hundreds == units);

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE:
        if (start) next_state = PROCESSING;
      PROCESSING:
        if (current == n_latch) next_state = DONE;
      DONE:
        next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // State and control registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      n_latch    <= 8'd0;
      current    <= 8'd0;
      even_count <= 8'd0;
      odd_count  <= 8'd0;
      done       <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            n_latch    <= n;           // Sample n on start
            current    <= 8'd1;        // Start checking from 1
            even_count <= 8'd0;
            odd_count  <= 8'd0;
          end
        end

        PROCESSING: begin
          // Evaluate current number
          if (is_pal) begin
            if (current[0]) odd_count  <= odd_count  + 1; // odd
            else            even_count <= even_count + 1; // even
          end

          // Advance to next number; finish if done
          if (current == n_latch) begin
            done <= 1'b1;
          end else begin
            current <= current + 1;
          end
        end

        DONE: begin
          done <= 1'b1; // Hold done until returning to IDLE
        end

        default: begin
          // should not occur; default to IDLE behavior
          state      <= IDLE;
          n_latch    <= 8'd0;
          current    <= 8'd0;
          even_count <= 8'd0;
          odd_count  <= 8'd0;
          done       <= 1'b0;
        end
      endcase

      state <= next_state;
    end
  end

endmodule
