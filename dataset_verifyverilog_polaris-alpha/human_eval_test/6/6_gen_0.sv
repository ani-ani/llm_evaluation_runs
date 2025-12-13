module paren_depth_calculator (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [127:0] group_string,
  output logic [2:0]  max_depth,
  output logic        done
);

  typedef enum logic [1:0] {
    IDLE       = 2'b00,
    PROCESSING = 2'b01,
    DONE       = 2'b10
  } state_t;

  state_t       state, next_state;
  logic [3:0]   idx, next_idx;          // character index 0..15
  logic [3:0]   current_depth, next_current_depth; // allow up to 15, clamp to 3 bits for max_depth
  logic [2:0]   next_max_depth;
  logic         next_done;

  // Extract current character based on idx (0 is leftmost [127:120])
  logic [7:0] current_char;
  assign current_char = group_string[127 - (idx * 8) -: 8];

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state          <= IDLE;
      idx            <= 4'd0;
      current_depth  <= 4'd0;
      max_depth      <= 3'd0;
      done           <= 1'b0;
    end else begin
      state          <= next_state;
      idx            <= next_idx;
      current_depth  <= next_current_depth;
      max_depth      <= next_max_depth;
      done           <= next_done;
    end
  end

  // Combinational next-state and output logic
  always_comb begin
    // Default assignments
    next_state         = state;
    next_idx           = idx;
    next_current_depth = current_depth;
    next_max_depth     = max_depth;
    next_done          = done;

    case (state)
      IDLE: begin
        next_done          = 1'b0;
        next_idx           = 4'd0;
        next_current_depth = 4'd0;
        next_max_depth     = 3'd0;
        if (start) begin
          next_state = PROCESSING;
        end
      end

      PROCESSING: begin
        next_done = 1'b0;

        // Process current_char
        if (current_char == 8'h00) begin
          // Null terminator: finish early
          next_state = DONE;
        end else begin
          // Handle parentheses
          if (current_char == 8'h28) begin
            // '('
            if (current_depth < 4'hF) begin
              next_current_depth = current_depth + 4'd1;
            end else begin
              next_current_depth = current_depth;
            end
            // Update max_depth within 3-bit range (0-7)
            if (next_current_depth[2:0] > max_depth) begin
              next_max_depth = next_current_depth[2:0];
            end
          end else if (current_char == 8'h29) begin
            // ')'
            if (current_depth > 0) begin
              next_current_depth = current_depth - 4'd1;
            end else begin
              next_current_depth = 4'd0;
            end
          end

          // Advance index
          if (idx == 4'd15) begin
            // Last character processed -> DONE next
            next_state = DONE;
          end else begin
            next_idx = idx + 4'd1;
          end
        end
      end

      DONE: begin
        next_done = 1'b1;
        // Wait here until start deasserts, then go back to IDLE on next start
        if (!start) begin
          next_state = IDLE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule