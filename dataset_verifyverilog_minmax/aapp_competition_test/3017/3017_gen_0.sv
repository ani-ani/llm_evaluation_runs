module count_power_substrings(
  input clk,
  input rst_n,
  input start,
  input [15:0] n,
  input [4:0][3:0] power_str,
  input [2:0] substr_len,
  output reg [16:0] count,
  output reg done
);
  // Constants for FSM
  localparam IDLE  = 2'b00;
  localparam ACTIVE = 2'b01;
  localparam DONE   = 2'b10;

  // FSM state and counter
  logic [1:0] state;
  logic [15:0] k;
  logic [3:0] bcd_digits[5];
  logic found;

  // BCD conversion (combinational)
  always_comb begin
    bcd_digits[0] = 4'(k / 10000);
    bcd_digits[1] = 4'((k % 10000) / 1000);
    bcd_digits[2] = 4'((k % 1000) / 100);
    bcd_digits[3] = 4'((k % 100) / 10);
    bcd_digits[4] = 4'(k % 10);
  end

  // Substring match function
  function logic substring_match(input logic [3:0] bcd[5],
                                 input logic [4:0][3:0] pw,
                                 input [2:0] len);
    int i, j;
    logic match;
  begin
    substring_match = 1'b0;
    for (i = 0; i <= 5 - len; i++) begin
      match = 1'b1;
      for (j = 0; j < len; j++) begin
        if (bcd[i + j] != pw[j]) begin
          match = 1'b0;
          break;
        end
      end
      if (match) begin
        substring_match = 1'b1;
        break;
      end
    end
  end
  endfunction

  assign found = substring_match(bcd_digits, power_str, substr_len);

  // FSM sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      count <= 17'b0;
      k <= 16'b0;
      done <= 1'b0;
    end else begin
      // default hold values
      state <= state;
      count <= count;
      k <= k;
      done <= done;

      case (state)
        IDLE: begin
          if (start) begin
            state <= ACTIVE;
            count <= 17'b0;
            k <= 16'b0;
            done <= 1'b0;
          end
        end
        ACTIVE: begin
          // Count if substring found for current k
          count <= count + (found ? 1 : 0);
          if (k == n) begin
            // Completed processing all numbers up to n
            state <= DONE;
            done <= 1'b1;
          end else begin
            state <= ACTIVE;
            k <= k + 1;
            done <= 1'b0;
          end
        end
        DONE: begin
          // Hold final count and done flag
          state <= DONE;
          count <= count;
          done <= 1'b1;
        end
      endcase
    end
  end

endmodule