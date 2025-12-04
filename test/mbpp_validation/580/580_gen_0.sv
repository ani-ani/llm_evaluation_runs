module even_nested_elements (
  input  clk,
  input  rst_n,
  input  start,
  input  [15:0][2:0][7:0] flat_tuple,
  input  [3:0] size_in,
  output reg [15:0][2:0][7:0] flat_out,
  output reg [3:0] size_out,
  output reg done
);

  // FSM state encoding
  typedef enum logic [1:0] {
    IDLE       = 2'b00,
    PROCESSING = 2'b01,
    DONE       = 2'b10
  } state_t;

  state_t state, state_n;

  // Internal registers
  reg [3:0]  in_idx, in_idx_n;          // input index (0..15)
  reg [3:0]  out_idx, out_idx_n;        // output index (0..15)
  reg [2:0]  current_level, current_level_n;

  // Stack to track nesting levels (max depth 3 -> stack depth 4 is sufficient)
  reg [2:0] level_stack [0:3];
  reg [1:0] sp, sp_n;                   // stack pointer

  // Extracted fields from current input element
  reg [2:0] in_level;
  reg [7:0] in_value;

  integer i;

  // Combinational extraction for current element
  always @* begin
    if (in_idx < size_in) begin
      in_level = flat_tuple[in_idx][2:0];
      in_value = flat_tuple[in_idx][7:0];
    end else begin
      in_level = 3'd0;
      in_value = 8'hFF;
    end
  end

  // Combinational next-state and output logic
  always @* begin
    // Default next values = hold
    state_n         = state;
    in_idx_n        = in_idx;
    out_idx_n       = out_idx;
    current_level_n = current_level;
    sp_n            = sp;

    // Default: hold flat_out, size_out, done in sequential block; only update where assigned

    case (state)
      IDLE: begin
        if (start) begin
          state_n         = PROCESSING;
          in_idx_n        = 4'd0;
          out_idx_n       = 4'd0;
          current_level_n = 3'd0;
          sp_n            = 2'd0;
        end
      end

      PROCESSING: begin
        if (in_idx < size_in) begin
          // Handle nesting and level hierarchy via stack
          if (in_idx == 0) begin
            // Initialize stack with first element's level
            current_level_n      = in_level;
            level_stack[0]       = in_level;
            sp_n                 = 2'd0;
          end else begin
            if (in_level > current_level) begin
              // Going deeper; push if within max depth and valid increment
              if (in_level <= 3 && (in_level == current_level + 1)) begin
                sp_n                        = sp + 1'b1;
                level_stack[sp + 1'b1]      = in_level;
                current_level_n             = in_level;
              end else begin
                // Invalid jump; clamp: treat as same level
                current_level_n = current_level;
              end
            end else if (in_level < current_level) begin
              // Climb up: pop until matching or root
              current_level_n = current_level;
              sp_n            = sp;
              while ((sp_n != 2'd0) && (in_level < current_level_n)) begin
                sp_n            = sp_n - 1'b1;
                current_level_n = level_stack[sp_n - 1'b0];
              end
              if (in_level == current_level_n) begin
                // matched level
              end else begin
                // If still not matching, treat as top-level reset
                current_level_n = in_level;
                sp_n            = 2'd0;
                level_stack[0]  = in_level;
              end
            end else begin
              // Same level
              current_level_n = in_level;
            end
          end

          // Filter condition for keeping even elements
          if ((in_value != 8'h00) && (in_value != 8'hFF) && (in_value[0] == 1'b0)) begin
            // Keep element - assign into output
            if (out_idx < 4'd16) begin
              // Maintain structure: preserve level as current_level_n
              // Note: pack as {level, value}
              // flat_out updated in sequential always block (use out_idx_n)
              ; // assignment in sequential block using latched values
            end
            out_idx_n = (out_idx < 4'd16) ? (out_idx + 1'b1) : out_idx;
          end

          // Move to next input element
          in_idx_n = in_idx + 1'b1;

          // If we've just consumed the last input, next cycle go to DONE
          if (in_idx == size_in - 1'b1) begin
            state_n = DONE;
          end
        end else begin
          // Safety: if in_idx exceeded, go to DONE
          state_n = DONE;
        end
      end

      DONE: begin
        // Wait for start to deassert and assert again to restart
        if (!start) begin
          state_n = IDLE;
        end
      end

      default: begin
        state_n = IDLE;
      end
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= IDLE;
      in_idx        <= 4'd0;
      out_idx       <= 4'd0;
      current_level <= 3'd0;
      sp            <= 2'd0;
      size_out      <= 4'd0;
      done          <= 1'b0;
      // Initialize outputs to unused
      for (i = 0; i < 16; i = i + 1) begin
        flat_out[i][2:0] <= 3'd0;
        flat_out[i][7:0] <= 8'hFF;
      end
    end else begin
      state         <= state_n;
      in_idx        <= in_idx_n;
      out_idx       <= out_idx_n;
      current_level <= current_level_n;
      sp            <= sp_n;

      case (state)
        IDLE: begin
          done     <= 1'b0;
          size_out <= 4'd0;
          if (start) begin
            // Clear outputs at start
            for (i = 0; i < 16; i = i + 1) begin
              flat_out[i][2:0] <= 3'd0;
              flat_out[i][7:0] <= 8'hFF;
            end
          end
        end

        PROCESSING: begin
          done <= 1'b0;
          // Write kept element for current in_idx-1 (combinational decided)
          // Determine element index just processed
          if (in_idx < size_in) begin
            // Use current input fields (in_level,in_value) and keep condition
            if ((in_value != 8'h00) && (in_value != 8'hFF) && (in_value[0] == 1'b0)) begin
              if (out_idx < 4'd16) begin
                flat_out[out_idx][2:0] <= current_level_n;
                flat_out[out_idx][7:0] <= in_value;
              end
            end
          end
        end

        DONE: begin
          done     <= 1'b1;
          size_out <= out_idx;
          // Ensure remaining outputs marked unused
          for (i = out_idx; i < 16; i = i + 1) begin
            flat_out[i][2:0] <= 3'd0;
            flat_out[i][7:0] <= 8'hFF;
          end
        end

        default: begin
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule