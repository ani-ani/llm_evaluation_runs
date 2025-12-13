module loot_divider(
  input clk, // Clock
  input rst_n, // Active-low reset
  input start, // Start computation
  input [2:0] k, // Number of denominations (1-8)
  input [7:0] x [7:0], // 8-element array of coin counts (each 8-bit)
  output reg [31:0] left_behind, // Result
  output reg done // High when computation completes
);

  // State encoding
  localparam STATE_IDLE    = 2'b00;
  localparam STATE_PROCESS = 2'b01;
  localparam STATE_DONE    = 2'b10;

  reg [1:0] state, next_state;
  reg [2:0] idx, next_idx;           // index for denominations 0..7
  reg [15:0] carry, next_carry;      // sufficient width for accumulated carry
  reg [31:0] next_left_behind;

  // Combinational next-state and output logic (except registered outputs)
  always @* begin
    // Default assignments
    next_state        = state;
    next_idx          = idx;
    next_carry        = carry;
    next_left_behind  = left_behind;

    case (state)
      STATE_IDLE: begin
        if (start) begin
          next_state        = (k != 0) ? STATE_PROCESS : STATE_DONE;
          next_idx          = 3'd0;
          next_carry        = 16'd0;
          next_left_behind  = 32'd0;
        end
      end

      STATE_PROCESS: begin
        if (idx < k) begin
          // Compute coins = x[idx] + carry
          // x[idx] is 8-bit, carry up to 16-bit; sum fits in 16 bits
          reg [15:0] coins;
          coins = {8'd0, x[idx]} + carry;

          // If odd, leave one coin of value (1 << idx)
          if (coins[0]) begin
            next_left_behind = next_left_behind + (32'd1 << idx);
            coins = coins - 16'd1;
          end

          // Compute carry for next denomination
          next_carry = coins >> 1;

          // Move to next denomination
          next_idx = idx + 3'd1;

          // If this was the last required denomination, go to DONE next
          if (next_idx >= k) begin
            next_state = STATE_DONE;
          end
        end else begin
          // Safety: if idx already reached/exceeded k
          next_state = STATE_DONE;
        end
      end

      STATE_DONE: begin
        // Hold result until next start or reset
        // Transition back to IDLE when start is deasserted (optional simple policy)
        if (!start) begin
          next_state = STATE_IDLE;
        end
      end

      default: begin
        next_state = STATE_IDLE;
      end
    endcase
  end

  // Sequential logic for state and registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= STATE_IDLE;
      idx           <= 3'd0;
      carry         <= 16'd0;
      left_behind   <= 32'd0;
      done          <= 1'b0;
    end else begin
      state       <= next_state;
      idx         <= next_idx;
      carry       <= next_carry;
      left_behind <= next_left_behind;

      // done is registered: high only in DONE state
      done <= (next_state == STATE_DONE);
    end
  end

endmodule