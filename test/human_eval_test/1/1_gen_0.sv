module paren_grouper(
  input              clk,
  input              rst_n,
  input              start,
  input      [7:0]   char_array [0:15],
  output reg [3:0]   group_start [0:3],
  output reg [3:0]   group_end   [0:3],
  output reg [1:0]   group_count,
  output reg         done
);

  // State encoding
  localparam IDLE       = 2'b00;
  localparam PROCESSING = 2'b01;
  localparam VALIDATE   = 2'b10;
  localparam DONE       = 2'b11;

  reg [1:0] state, next_state;

  // Position counter: 0-15
  reg [3:0] pos;

  // Balance counter: 3-bit signed (-4 to +3)
  reg signed [2:0] balance;
  reg signed [2:0] next_balance;

  // Current group index: 0-3
  reg [1:0] current_group;

  // Internal flags
  reg invalid_pattern;
  reg next_invalid_pattern;

  integer i;

  // Combinational next state logic
  always @(*) begin
    next_state = state;
    next_balance = balance;
    next_invalid_pattern = invalid_pattern;

    case (state)
      IDLE: begin
        if (start) begin
          next_state = PROCESSING;
        end
      end

      PROCESSING: begin
        // Default stay in PROCESSING, transitions controlled by sequential block
        next_state = PROCESSING;
      end

      VALIDATE: begin
        // After validation, move to DONE
        next_state = DONE;
      end

      DONE: begin
        // After one cycle of DONE, go back to IDLE
        next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      pos <= 4'd0;
      balance <= 3'sd0;
      current_group <= 2'd0;
      invalid_pattern <= 1'b0;
      group_count <= 2'd0;
      done <= 1'b0;
      for (i = 0; i < 4; i = i + 1) begin
        group_start[i] <= 4'd0;
        group_end[i]   <= 4'd0;
      end
    end else begin
      state <= next_state;
      balance <= next_balance;
      invalid_pattern <= next_invalid_pattern;

      done <= 1'b0; // default, only asserted in DONE state

      case (state)
        IDLE: begin
          // Clear outputs / internal registers on new start
          if (start) begin
            pos <= 4'd0;
            balance <= 3'sd0;
            current_group <= 2'd0;
            invalid_pattern <= 1'b0;
            group_count <= 2'd0;
            for (i = 0; i < 4; i = i + 1) begin
              group_start[i] <= 4'd0;
              group_end[i]   <= 4'd0;
            end
          end
        end

        PROCESSING: begin
          // Process one character per cycle
          if (pos < 4'd16) begin
            // Read current character
            case (char_array[pos])
              8'h20: begin
                // space: ignore, no balance change
              end

              8'h28: begin
                // '('
                // If balance is about to go from 0 to 1, start new group
                if (balance + 3'sd1 == 3'sd1) begin
                  // Start new group only if within limit
                  if (current_group < 2'd4) begin
                    group_start[current_group] <= pos;
                  end
                end

                // Update balance
                next_balance <= balance + 3'sd1;

                // If balance exceeds +3 (beyond spec) mark invalid
                if (balance + 3'sd1 > 3'sd3)
                  next_invalid_pattern <= 1'b1;
              end

              8'h29: begin
                // ')'
                // Update balance first
                next_balance <= balance - 3'sd1;

                // If going negative, invalid
                if (balance - 3'sd1 < -3'sd4)
                  next_invalid_pattern <= 1'b1;

                // If new balance is negative, invalid nesting
                if (balance - 3'sd1 < 3'sd0)
                  next_invalid_pattern <= 1'b1;

                // If we just returned to 0, close current group
                if ((balance - 3'sd1) == 3'sd0) begin
                  if (current_group < 2'd4) begin
                    group_end[current_group] <= pos;
                    // Increment group_count and current_group
                    group_count <= group_count + 2'd1;
                    current_group <= current_group + 2'd1;
                  end else begin
                    // More than 4 groups -> invalid
                    next_invalid_pattern <= 1'b1;
                  end
                end
              end

              default: begin
                // Invalid character -> invalid pattern
                next_invalid_pattern <= 1'b1;
              end
            endcase

            // Increment position
            pos <= pos + 4'd1;

            // Check termination conditions after processing char
            if ((pos == 4'd15) || (current_group == 2'd4)) begin
              // Move to VALIDATE on next cycle
              state <= VALIDATE;
            end
          end else begin
            // Safety: if pos already at 16, go to VALIDATE
            state <= VALIDATE;
          end
        end

        VALIDATE: begin
          // Final validation: ensure balance is zero and not invalid
          if ((balance != 3'sd0) || invalid_pattern) begin
            group_count <= 2'd0;
          end
          // Next state handled by combinational (DONE)
        end

        DONE: begin
          // Assert done for one cycle, hold group_count from VALIDATE
          done <= 1'b1;
          // Next state will go to IDLE
        end

        default: begin
          // Should not occur, reset to IDLE
          state <= IDLE;
        end
      endcase
    end
  end

endmodule