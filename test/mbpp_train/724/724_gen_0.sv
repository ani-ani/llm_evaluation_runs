module power_digit_sum(
  input clk,
  input rst_n,
  input start,
  input [3:0] base,
  input [3:0] power,
  output reg [7:0] digit_sum,
  output reg done
);

  // State encoding
  localparam IDLE         = 3'd0;
  localparam INIT         = 3'd1;
  localparam MUL_LOOP     = 3'd2;
  localparam MUL_WAIT     = 3'd3;
  localparam DD_INIT      = 3'd4;
  localparam DD_SHIFT     = 3'd5;
  localparam SUM_DIGITS   = 3'd6;
  localparam DONE         = 3'd7;

  reg [2:0] state, next_state;

  // Registers for power computation
  reg [3:0] base_reg;
  reg [3:0] power_reg;
  reg [4:0] exp_count;         // up to 15
  reg [31:0] result;           // holds base^power (sized generously)

  // Registers for double dabble
  reg [31:0] bin_shift;        // shifting binary value
  reg [5:0]  shift_count;      // up to 32 shifts
  reg [3:0]  bcd3, bcd2, bcd1, bcd0; // 4 BCD digits (covers up to 9999)

  // Sum register
  reg [7:0] sum_reg;

  // Combinational next-state logic
  always @* begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start && (base >= 4'd2))
          next_state = INIT;
      end
      INIT: begin
        next_state = (power_reg == 4'd0) ? DD_INIT : MUL_LOOP;
      end
      MUL_LOOP: begin
        // Start a multiply step, then go to wait
        next_state = MUL_WAIT;
      end
      MUL_WAIT: begin
        // One-cycle multiply complete
        if (exp_count == power_reg)
          next_state = DD_INIT;
        else
          next_state = MUL_LOOP;
      end
      DD_INIT: begin
        next_state = DD_SHIFT;
      end
      DD_SHIFT: begin
        if (shift_count == 6'd32)
          next_state = SUM_DIGITS;
        else
          next_state = DD_SHIFT;
      end
      SUM_DIGITS: begin
        next_state = DONE;
      end
      DONE: begin
        // Wait for start to deassert and next valid start
        if (!start)
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      base_reg    <= 4'd0;
      power_reg   <= 4'd0;
      exp_count   <= 5'd0;
      result      <= 32'd0;
      bin_shift   <= 32'd0;
      shift_count <= 6'd0;
      bcd3        <= 4'd0;
      bcd2        <= 4'd0;
      bcd1        <= 4'd0;
      bcd0        <= 4'd0;
      sum_reg     <= 8'd0;
      digit_sum   <= 8'd0;
      done        <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done      <= 1'b0;
          digit_sum <= 8'd0;
          // Latch inputs when valid start
          if (start && (base >= 4'd2)) begin
            base_reg  <= base;
            power_reg <= power;
          end
        end

        INIT: begin
          // Initialize result for exponentiation
          if (power_reg == 4'd0) begin
            // base^0 = 1
            result    <= 32'd1;
            exp_count <= 5'd0;
          end else begin
            result    <= base_reg;
            exp_count <= 5'd1;
          end
        end

        MUL_LOOP: begin
          // Trigger multiply (combinational, result latched in MUL_WAIT)
          // No register updates here besides as needed by protocol
        end

        MUL_WAIT: begin
          // Perform iterative multiplication: result = result * base_reg
          result    <= result * base_reg;
          exp_count <= exp_count + 5'd1;
        end

        DD_INIT: begin
          // Prepare for double dabble
          bin_shift   <= result;
          shift_count <= 6'd0;
          bcd3        <= 4'd0;
          bcd2        <= 4'd0;
          bcd1        <= 4'd0;
          bcd0        <= 4'd0;
        end

        DD_SHIFT: begin
          // Double dabble step: adjust BCD digits then shift in next MSB

          // Step 1: Add 3 to digits >=5
          if (bcd0 >= 4'd5) bcd0 <= bcd0 + 4'd3;
          if (bcd1 >= 4'd5) bcd1 <= bcd1 + 4'd3;
          if (bcd2 >= 4'd5) bcd2 <= bcd2 + 4'd3;
          if (bcd3 >= 4'd5) bcd3 <= bcd3 + 4'd3;

          // Step 2: Shift left: {bcd3,bcd2,bcd1,bcd0,bin_shift}
          {bcd3, bcd2, bcd1, bcd0, bin_shift} <=
            {bcd3, bcd2, bcd1, bcd0, bin_shift} << 1;

          // Increment shift counter
          shift_count <= shift_count + 6'd1;
        end

        SUM_DIGITS: begin
          // Sum BCD digits
          sum_reg   <= bcd0 + bcd1 + bcd2 + bcd3;
          digit_sum <= bcd0 + bcd1 + bcd2 + bcd3;
        end

        DONE: begin
          done <= 1'b1;
        end

        default: begin
          // Should not occur; keep safe defaults
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule