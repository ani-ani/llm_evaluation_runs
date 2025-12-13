module tape_art_decoder(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [3:0] c[0:15],
  output reg [3:0] instr_l[0:15],
  output reg [3:0] instr_r[0:15],
  output reg [3:0] instr_c[0:15],
  output reg [4:0] instr_count,
  output reg done,
  output reg impossible
);

  // State encoding
  localparam IDLE               = 3'd0;
  localparam SCAN_FIRST_LAST    = 3'd1;
  localparam CHECK_CONSISTENCY  = 3'd2;
  localparam BUILD_INSTRUCTIONS = 3'd3;
  localparam DONE_STATE         = 3'd4;

  reg [2:0] state, next_state;

  // First/last occurrence for each color 0-15
  reg        used_color [0:15];
  reg [3:0]  first_pos  [0:15];
  reg [3:0]  last_pos   [0:15];

  // Sorted unique colors by their last occurrence (for reverse order)
  reg [3:0]  color_list [0:15];
  reg [4:0]  color_count;

  // Iterators / temporaries
  reg [4:0] idx;           // generic index (0-16)
  reg [4:0] jdx;
  reg [3:0] cur_color;

  // For building instructions
  reg [3:0]  pivot_l;
  reg [3:0]  pivot_r;
  reg [3:0]  pivot_c;
  reg [3:0]  pos;
  reg        conflict;

  integer i;

  // Sequential state register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Main sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Global reset of outputs and internal regs
      done         <= 1'b0;
      impossible   <= 1'b0;
      instr_count  <= 5'd0;
      idx          <= 5'd0;
      jdx          <= 5'd0;
      color_count  <= 5'd0;
      for (i = 0; i < 16; i = i + 1) begin
        used_color[i] <= 1'b0;
        first_pos[i]  <= 4'd0;
        last_pos[i]   <= 4'd0;
        color_list[i] <= 4'd0;
        instr_l[i]    <= 4'd0;
        instr_r[i]    <= 4'd0;
        instr_c[i]    <= 4'd0;
      end
    end else begin
      case (state)
        IDLE: begin
          done        <= 1'b0;
          impossible  <= 1'b0;
          instr_count <= 5'd0;
          // Wait for start pulse; clear internal structures when start is seen
          if (start) begin
            // Init per-color info
            for (i = 0; i < 16; i = i + 1) begin
              used_color[i] <= 1'b0;
              first_pos[i]  <= 4'd0;
              last_pos[i]   <= 4'd0;
            end
            color_count <= 5'd0;
            idx         <= 5'd0;
          end
        end

        // Scan c[0:n-1] to capture first/last occurrences
        SCAN_FIRST_LAST: begin
          if (idx < n) begin
            cur_color = c[idx];
            if (!used_color[cur_color]) begin
              used_color[cur_color] <= 1'b1;
              first_pos[cur_color]  <= idx[3:0];
            end
            last_pos[cur_color] <= idx[3:0];
            idx <= idx + 5'd1;
          end else begin
            // Build color_list from used_color (unsorted yet)
            color_count <= 5'd0;
            idx         <= 5'd0;
          end
        end

        // CHECK_CONSISTENCY stage does two things over time:
        // 1) Build a temporary color_list from used_color
        // 2) Check full coverage: each position's color must be the last among overlapping segments
        CHECK_CONSISTENCY: begin
          // Phase 1: build color_list (simple accumulation over colors 0..15)
          if (idx < 16) begin
            if (used_color[idx[3:0]]) begin
              color_list[color_count] <= idx[3:0];
              color_count <= color_count + 5'd1;
            end
            idx <= idx + 5'd1;
          end else begin
            // Phase 2: consistency check across all positions 0..n-1
            // One position per cycle using jdx
            if (jdx == 5'd0) begin
              conflict <= 1'b0;
            end

            if ((jdx < n) && !conflict) begin
              // For position jdx, determine top color by max last_pos among covering colors
              // covering: first_pos[color] <= jdx <= last_pos[color]
              reg [3:0] best_color;
              reg [3:0] best_last;
              reg       found_any;
              best_color = 4'd0;
              best_last  = 4'd0;
              found_any  = 1'b0;

              for (i = 0; i < 16; i = i + 1) begin
                if (used_color[i]) begin
                  if ((first_pos[i] <= jdx[3:0]) && (jdx[3:0] <= last_pos[i])) begin
                    if (!found_any || (last_pos[i] > best_last)) begin
                      best_last  = last_pos[i];
                      best_color = i[3:0];
                      found_any  = 1'b1;
                    end
                  end
                end
              end

              // If no covering color, conflict
              if (!found_any) begin
                conflict <= 1'b1;
              end else begin
                // Must match c[jdx]
                if (best_color != c[jdx]) begin
                  conflict <= 1'b1;
                end
              end

              jdx <= jdx + 5'd1;
            end
          end
        end

        // Build instructions in reverse application order.
        // We first sort colors by last_pos (ascending) via bubble sort style passes,
        // then emit instructions from largest last_pos to smallest.
        BUILD_INSTRUCTIONS: begin
          // Step 1: bubble sort color_list[0:color_count-1] by last_pos (ascending)
          // We'll do one compare-swap per cycle using idx,jdx as pointers.
          if (color_count == 0) begin
            // No colors
            instr_count <= 5'd0;
          end else begin
            // Bubble sort state machine inside this state:
            // Use (idx,jdx): idx = current outer pass, jdx = inner index
            if (idx < color_count) begin
              if (jdx + 1 < color_count - idx) begin
                // compare color_list[jdx] and color_list[jdx+1]
                reg [3:0] ca, cb;
                ca = color_list[jdx];
                cb = color_list[jdx + 1];
                if (last_pos[ca] > last_pos[cb]) begin
                  // swap
                  color_list[jdx]     <= cb;
                  color_list[jdx + 1] <= ca;
                end
                jdx <= jdx + 5'd1;
              end else begin
                jdx <= 5'd0;
                idx <= idx + 5'd1;
              end
            end else begin
              // Sorting done. Now emit instructions in reverse order.
              // We do this once: instr index k from 0..color_count-1 maps from
              // color_list[color_count-1-k].
              for (i = 0; i < 16; i = i + 1) begin
                instr_l[i] <= 4'd0;
                instr_r[i] <= 4'd0;
                instr_c[i] <= 4'd0;
              end
              for (i = 0; i < 16; i = i + 1) begin
                if (i < color_count) begin
                  reg [3:0] col;
                  col = color_list[color_count - 1 - i];
                  instr_l[i] <= first_pos[col];
                  instr_r[i] <= last_pos[col];
                  instr_c[i] <= col;
                end
              end
              instr_count <= color_count;
            end
          end
        end

        DONE_STATE: begin
          done <= 1'b1;
        end

        default: begin
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
          next_state = SCAN_FIRST_LAST;
      end

      SCAN_FIRST_LAST: begin
        if (idx >= n)
          next_state = CHECK_CONSISTENCY;
      end

      CHECK_CONSISTENCY: begin
        if (idx < 16) begin
          // still building color_list
          next_state = CHECK_CONSISTENCY;
        end else if (jdx < n && !conflict) begin
          // still checking positions
          next_state = CHECK_CONSISTENCY;
        end else if (conflict) begin
          next_state = DONE_STATE;
        end else begin
          // all positions ok
          next_state = BUILD_INSTRUCTIONS;
        end
      end

      BUILD_INSTRUCTIONS: begin
        if (color_count == 0) begin
          // No colors -> valid but zero instructions
          next_state = DONE_STATE;
        end else if (idx < color_count) begin
          // still sorting
          next_state = BUILD_INSTRUCTIONS;
        end else begin
          // sorting and instruction generation done
          next_state = DONE_STATE;
        end
      end

      DONE_STATE: begin
        // Wait for start low then high to restart
        if (!start)
          next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Set impossible flag combinationally based on conflict after checks
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      impossible <= 1'b0;
    end else begin
      if (state == CHECK_CONSISTENCY && conflict && next_state == DONE_STATE) begin
        // Impossible case
        impossible  <= 1'b1;
        instr_count <= 5'd0;
      end else if (state == IDLE && start) begin
        impossible <= 1'b0;
      end
    end
  end

endmodule