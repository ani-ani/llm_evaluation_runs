module power_digit_sum(
  input reg clk,
  input reg rst_n,
  input reg start,
  input reg [3:0] base,
  input reg [3:0] power,
  output reg [7:0] digit_sum,
  output reg done
);

  // Internal signals
  localparam IDLE = 2'b00;
  localparam MUL  = 2'b01;
  localparam BCD  = 2'b10;
  localparam DONE = 2'b11;

  // Binary result width (enough for 15^15)
  localparam BIN_WIDTH = 64;
  // Number of BCD digits required for a 64-bit binary number
  localparam BCD_DIGITS = 20; // 20 decimal digits
  localparam BCD_WIDTH = BCD_DIGITS * 4; // 80 bits
  localparam SHIFT_WIDTH = BIN_WIDTH + BCD_WIDTH; // 144 bits

  reg [1:0] state;
  reg [3:0] cnt;               // multiplication loop counter (0-15)
  reg [BIN_WIDTH-1:0] result;  // current product (base^cnt)
  reg [BIN_WIDTH-1:0] bin_res; // final binary result for conversion
  reg [SHIFT_WIDTH-1:0] shift_reg; // combined shift register for double dabble
  reg [5:0] shift_cnt;         // counts shifts for conversion (0-64)
  reg start_dly;               // delayed start for edge detection
  reg [7:0] sum_reg;           // temporary sum register for digit sum

  integer i; // loop variable for nibble correction and sum

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done  <= 1'b0;
      cnt   <= 4'd0;
      result <= {BIN_WIDTH{1'b0}};
      bin_res <= {BIN_WIDTH{1'b0}};
      shift_reg <= {SHIFT_WIDTH{1'b0}};
      shift_cnt <= 6'd0;
      start_dly <= 1'b0;
      digit_sum <= 8'd0;
      sum_reg <= 8'd0;
    end else begin
      start_dly <= start; // capture start for edge detection

      case (state)
        IDLE: begin
          done <= 1'b0;
          // detect rising edge of start
          if (start && !start_dly) begin
            // Initialize for a new calculation
            if (base < 2) begin
              // Undefined result: treat as 0 and go directly to DONE
              bin_res <= 64'd0;
              shift_reg <= {64'd0, {BCD_WIDTH{1'b0}}};
              shift_cnt <= 6'd0;
              digit_sum <= 8'd0;
              state <= DONE;
              done <= 1'b1;
            end else begin
              // normal operation
              if (power == 4'd0) begin
                // base^0 = 1
                result <= 64'd1;
              end else begin
                result <= 64'd1; // start with 1
              end
              cnt   <= 4'd0;
              state <= MUL;
            end
          end
        end

        MUL: begin
          // iterative multiplication, one multiplication per cycle
          if (power == 4'd0) begin
            // nothing to multiply, result already 1
            bin_res <= result;
            state   <= BCD;
          end else if (cnt < power) begin
            result <= result * base;
            cnt    <= cnt + 1;
          end else begin
            // all multiplications done
            bin_res <= result;
            state   <= BCD;
          end
        end

        BCD: begin
          // Double-Dabble conversion
          if (shift_cnt == 0) begin
            // Load binary result into the upper part of the shift register
            shift_reg <= {bin_res, {BCD_WIDTH{1'b0}}};
          end
          // Perform shift and correction if we haven't shifted all bits yet
          if (shift_cnt < BIN_WIDTH) begin
            // Shift left by 1 bit
            shift_reg <= {shift_reg[SHIFT_WIDTH-2:0], 1'b0};
            // Correct each BCD digit (nibble) if >= 5
            for (i = 0; i < BCD_DIGITS; i = i + 1) begin
              if (shift_reg[4*i +: 4] > 4) begin
                shift_reg[4*i +: 4] <= shift_reg[4*i +: 4] + 4'd3;
              end
            end
            // Increment shift counter
            shift_cnt <= shift_cnt + 1;
          end else begin
            // All bits have been shifted, move to DONE
            state <= DONE;
          end
        end

        DONE: begin
          // Compute sum of BCD digits
          sum_reg = 8'd0;
          for (i = 0; i < BCD_DIGITS; i = i + 1) begin
            sum_reg = sum_reg + shift_reg[4*i +: 4];
          end
          digit_sum <= sum_reg;
          done <= 1'b1;
          // Return to IDLE when start is deasserted (or on next start pulse)
          if (!start) begin
            state <= IDLE;
            done  <= 1'b0;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule
