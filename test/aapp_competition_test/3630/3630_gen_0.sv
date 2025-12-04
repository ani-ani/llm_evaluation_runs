module string_modifier(
  input clk,
  input rst_n,
  input start,
  input [7:0] s1 [0:15],
  input [7:0] s2 [0:15],
  input [3:0] length,
  output reg [8:0] moves,
  output reg done
);

  // State encoding
  localparam IDLE       = 2'd0;
  localparam PROCESSING = 2'd1;
  localparam DONE       = 2'd2;

  reg [1:0] state, next_state;

  // Index and control
  reg [4:0] idx;                // up to 16
  reg [4:0] count_cycles;       // track cycles for worst-case latency (optional)

  // Direction encoding: 0 = none (init), 1 = up, 2 = down
  reg [1:0] prev_dir;
  reg       first_char_done;

  // Per-character computation
  reg [5:0] a_val, b_val;       // 0-25 range
  reg [5:0] diff_up, diff_down; // 0-26
  reg [5:0] step;               // 0-13
  reg [1:0] cur_dir;

  // Sequential state update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state          <= IDLE;
      moves          <= 9'd0;
      done           <= 1'b1;
      idx            <= 5'd0;
      count_cycles   <= 5'd0;
      prev_dir       <= 2'd0;
      first_char_done<= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b1;
          moves <= 9'd0;
          idx <= 5'd0;
          count_cycles <= 5'd0;
          prev_dir <= 2'd0;
          first_char_done <= 1'b0;
          if (start) begin
            done <= 1'b0;
          end
        end

        PROCESSING: begin
          done <= 1'b0;
          count_cycles <= count_cycles + 5'd1;

          if (idx < length) begin
            // Map characters 'A'-'Z' to 0-25
            a_val <= (s1[idx] >= 8'd65 && s1[idx] <= 8'd90) ? (s1[idx] - 8'd65) : 6'd0;
            b_val <= (s2[idx] >= 8'd65 && s2[idx] <= 8'd90) ? (s2[idx] - 8'd65) : 6'd0;

            // Compute modulo-26 differences
            diff_up   <= ( (s2[idx] >= 8'd65 && s2[idx] <= 8'd90) && (s1[idx] >= 8'd65 && s1[idx] <= 8'd90) ) ?
                         ( (b_val >= a_val) ? (b_val - a_val) : (b_val + 6'd26 - a_val) ) : 6'd0;
            diff_down <= ( (s2[idx] >= 8'd65 && s2[idx] <= 8'd90) && (s1[idx] >= 8'd65 && s1[idx] <= 8'd90) ) ?
                         ( (a_val >= b_val) ? (a_val - b_val) : (a_val + 6'd26 - b_val) ) : 6'd0;

            // Determine minimal step and its direction
            if (diff_up <= diff_down) begin
              step    <= diff_up;
              cur_dir <= (diff_up == 6'd0) ? 2'd0 : 2'd1; // up or none
            end else begin
              step    <= diff_down;
              cur_dir <= 2'd2; // down
            end

            // Accumulate moves with directional grouping
            if (!first_char_done) begin
              // First character: just add step and set direction
              moves <= moves + step;
              prev_dir <= cur_dir;
              first_char_done <= 1'b1;
            end else begin
              if (step == 6'd0) begin
                // No movement, no effect on direction or moves
                prev_dir <= prev_dir;
              end else if (prev_dir == 2'd0) begin
                // Previous had no direction (edge case), start with current
                moves <= moves + step;
                prev_dir <= cur_dir;
              end else if (cur_dir == prev_dir) begin
                // Same direction: simple accumulation
                moves <= moves + step;
              end else begin
                // Direction change: still add step (minimal grouping already per-char)
                moves <= moves + step;
                prev_dir <= cur_dir;
              end
            end

            idx <= idx + 5'd1;
          end
        end

        DONE: begin
          done <= 1'b1;
        end
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = PROCESSING;
      end

      PROCESSING: begin
        // Transition to DONE after N characters processed
        if (idx >= length)
          next_state = DONE;
      end

      DONE: begin
        // Return to IDLE; result held until next start
        if (!start)
          next_state = IDLE;
      end
    endcase
  end

endmodule