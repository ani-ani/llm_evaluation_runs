module untileable_cell_counter(
  input clk,
  input rst_n,
  input start,
  input [3:0] street_len,
  input [3:0] num_patterns,
  input [15:0][4:0] street_chars,
  input [3:0][3:0] tile_lens,
  input [3:0][15:0][4:0] tile_patterns,
  output reg [4:0] untileable_count,
  output reg done
);

  // State encoding
  typedef enum logic [1:0] {
    IDLE        = 2'b00,
    CHECK_TILES = 2'b01,
    COUNT       = 2'b10,
    DONE_STATE  = 2'b11
  } state_t;

  state_t state, next_state;

  // Coverable flags (per street position)
  reg [15:0] coverable;

  // Iteration indices
  reg [3:0] curr_pattern;      // 0..3
  reg [3:0] start_pos;         // 0..15
  reg [4:0] match_len;         // supports up to 16
  reg       matching;          // current match-in-progress flag
  reg       compare_done;      // indicates completion of comparison for current start_pos

  // Internal wires/regs for convenience
  reg [3:0] curr_tile_len;
  reg       indices_valid;
  reg [3:0] cmp_index;         // index within tile during comparison

  // Current tile length based on selected pattern
  always @(*) begin
    case (curr_pattern)
      4'd0: curr_tile_len = tile_lens[0];
      4'd1: curr_tile_len = tile_lens[1];
      4'd2: curr_tile_len = tile_lens[2];
      4'd3: curr_tile_len = tile_lens[3];
      default: curr_tile_len = 4'd0;
    endcase
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = CHECK_TILES;
      end

      CHECK_TILES: begin
        // Exit when all patterns and positions processed
        if ((curr_pattern >= num_patterns) || (num_patterns == 0)) begin
          next_state = COUNT;
        end
      end

      COUNT: begin
        next_state = DONE_STATE;
      end

      DONE_STATE: begin
        if (!start)
          next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      coverable <= 16'b0;
      curr_pattern <= 4'd0;
      start_pos <= 4'd0;
      match_len <= 5'd0;
      matching <= 1'b0;
      compare_done <= 1'b0;
      untileable_count <= 5'd0;
      done <= 1'b0;
      cmp_index <= 4'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          untileable_count <= 5'd0;
          coverable <= 16'b0;
          curr_pattern <= 4'd0;
          start_pos <= 4'd0;
          match_len <= 5'd0;
          matching <= 1'b0;
          compare_done <= 1'b0;
          cmp_index <= 4'd0;
          // If start is already high, transition will occur via next_state
        end

        CHECK_TILES: begin
          done <= 1'b0;

          // Default: if compare just finished, advance indices below
          if (!compare_done) begin
            // If no valid patterns or tile length zero, skip
            if ((curr_pattern < num_patterns) && (curr_tile_len != 0) && (start_pos + curr_tile_len <= street_len)) begin
              // Perform character comparison sequentially across cycles
              // Compare one character per cycle
              // Access appropriate tile pattern row
              case (curr_pattern)
                4'd0: begin
                  if (tile_patterns[0][cmp_index] == street_chars[start_pos + cmp_index]) begin
                    // match remains possible
                    if (cmp_index + 1 == curr_tile_len) begin
                      matching <= 1'b1;
                      compare_done <= 1'b1;
                    end
                    cmp_index <= cmp_index + 1'b1;
                  end else begin
                    matching <= 1'b0;
                    compare_done <= 1'b1;
                  end
                end
                4'd1: begin
                  if (tile_patterns[1][cmp_index] == street_chars[start_pos + cmp_index]) begin
                    if (cmp_index + 1 == curr_tile_len) begin
                      matching <= 1'b1;
                      compare_done <= 1'b1;
                    end
                    cmp_index <= cmp_index + 1'b1;
                  end else begin
                    matching <= 1'b0;
                    compare_done <= 1'b1;
                  end
                end
                4'd2: begin
                  if (tile_patterns[2][cmp_index] == street_chars[start_pos + cmp_index]) begin
                    if (cmp_index + 1 == curr_tile_len) begin
                      matching <= 1'b1;
                      compare_done <= 1'b1;
                    end
                    cmp_index <= cmp_index + 1'b1;
                  end else begin
                    matching <= 1'b0;
                    compare_done <= 1'b1;
                  end
                end
                4'd3: begin
                  if (tile_patterns[3][cmp_index] == street_chars[start_pos + cmp_index]) begin
                    if (cmp_index + 1 == curr_tile_len) begin
                      matching <= 1'b1;
                      compare_done <= 1'b1;
                    end
                    cmp_index <= cmp_index + 1'b1;
                  end else begin
                    matching <= 1'b0;
                    compare_done <= 1'b1;
                  end
                end
                default: begin
                  matching <= 1'b0;
                  compare_done <= 1'b1;
                end
              endcase
            end else begin
              // No valid comparison at this start_pos; mark compare done to advance
              matching <= 1'b0;
              compare_done <= 1'b1;
            end
          end

          // When comparison for this start position is done, update coverable and advance indices
          if (compare_done) begin
            if (matching) begin
              // Mark all covered positions for this match
              for (i = 0; i < 16; i = i + 1) begin
                if ((i >= start_pos) && (i < start_pos + curr_tile_len) && (i < street_len)) begin
                  coverable[i] <= 1'b1;
                end
              end
            end

            // Advance to next start_pos
            if (start_pos + 1 < street_len) begin
              start_pos <= start_pos + 1'b1;
            end else begin
              // Move to next pattern
              start_pos <= 4'd0;
              if (curr_pattern + 1 < num_patterns)
                curr_pattern <= curr_pattern + 1'b1;
              else
                curr_pattern <= num_patterns; // triggers transition to COUNT via next_state
            end

            // Reset comparison control for next position
            cmp_index <= 4'd0;
            matching <= 1'b0;
            compare_done <= 1'b0;
          end
        end

        COUNT: begin
          done <= 1'b0;
          untileable_count <= 5'd0;
          for (i = 0; i < 16; i = i + 1) begin
            if ((i < street_len) && !coverable[i]) begin
              untileable_count <= untileable_count + 1'b1;
            end
          end
        end

        DONE_STATE: begin
          done <= 1'b1;
          // Hold untileable_count until next start low then high sequence returns to IDLE
        end

        default: begin
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule