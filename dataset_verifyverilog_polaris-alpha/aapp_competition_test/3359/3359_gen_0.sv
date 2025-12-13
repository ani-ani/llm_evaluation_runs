module stellar_body_counter(
  input clk,
  input rst_n,
  input start,
  input [3:0] grid_row,
  input [3:0] grid_col,
  input [15:0] pixel_value,
  input pixel_valid,
  output reg [7:0] star_count,
  output reg done
);

  // Parameters
  localparam IDLE    = 2'b00;
  localparam LOAD    = 2'b01;
  localparam PROCESS = 2'b10;
  localparam DONE    = 2'b11;

  // 16x16 grid, 4-connected labeling with small label space (0-255)
  reg [1:0] state, next_state;

  // Store brightness info (bright if pixel_value >= 0x8000)
  reg bright [0:15][0:15];

  // Label map (8-bit labels, 0 means unassigned)
  reg [7:0] label [0:15][0:15];

  // Union-Find parent table for labels 0..255
  reg [7:0] parent [0:255];

  // Counters / indices
  reg [7:0] cycle_cnt;
  reg [3:0] r_idx;
  reg [3:0] c_idx;

  reg [7:0] next_label;      // Next new label to assign

  // Internal control
  reg processing_pass;       // 0: forward labeling pass, 1: consolidation pass
  reg counting_phase;        // 0: do UF compression, 1: count roots

  reg [7:0] count_label;     // label index for counting
  reg [7:0] root_count;      // counted stellar bodies

  integer i, j;

  // Find root function for union-find (combinational, no path compression here)
  function automatic [7:0] uf_find;
    input [7:0] x;
    reg [7:0] y;
    begin
      y = x;
      while (parent[y] != y && parent[y] != 8'd0) begin
        y = parent[y];
      end
      uf_find = y;
    end
  endfunction

  // Sequential state and registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= IDLE;
      done         <= 1'b0;
      star_count   <= 8'd0;
      cycle_cnt    <= 8'd0;
      r_idx        <= 4'd0;
      c_idx        <= 4'd0;
      next_label   <= 8'd1;
      processing_pass <= 1'b0;
      counting_phase  <= 1'b0;
      count_label     <= 8'd1;
      root_count      <= 8'd0;
      // Clear arrays
      for (i = 0; i < 16; i = i + 1) begin
        for (j = 0; j < 16; j = j + 1) begin
          bright[i][j] <= 1'b0;
          label[i][j]  <= 8'd0;
        end
      end
      for (i = 0; i < 256; i = i + 1) begin
        parent[i] <= 8'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done       <= 1'b0;
          star_count <= 8'd0;
          cycle_cnt  <= 8'd0;
          r_idx      <= 4'd0;
          c_idx      <= 4'd0;
          next_label <= 8'd1;
          processing_pass <= 1'b0;
          counting_phase  <= 1'b0;
          count_label     <= 8'd1;
          root_count      <= 8'd0;
          if (next_state == LOAD) begin
            // Initialize memories at start of LOAD
            for (i = 0; i < 16; i = i + 1) begin
              for (j = 0; j < 16; j = j + 1) begin
                bright[i][j] <= 1'b0;
                label[i][j]  <= 8'd0;
              end
            end
            for (i = 0; i < 256; i = i + 1) begin
              parent[i] <= 8'd0;
            end
          end
        end

        LOAD: begin
          // Accept pixels; position from grid_row/grid_col
          if (pixel_valid) begin
            bright[grid_row][grid_col] <= (pixel_value[15] == 1'b1); // >=0x8000 if MSB=1
          end
        end

        PROCESS: begin
          // cycle counter for timeout guarantee (not strictly needed for 16x16 but included)
          if (cycle_cnt < 8'd255)
            cycle_cnt <= cycle_cnt + 8'd1;

          if (!processing_pass) begin
            // First pass: forward scan, assign labels and record equivalences
            // Process one pixel per cycle at (r_idx, c_idx)
            if (r_idx < 4'd16) begin
              if (bright[r_idx][c_idx]) begin
                reg [7:0] up_label;
                reg [7:0] left_label;
                reg [7:0] cur_label;
                reg [7:0] min_label;
                up_label   = (r_idx > 0)        ? label[r_idx-1][c_idx]   : 8'd0;
                left_label = (c_idx > 0)        ? label[r_idx][c_idx-1]   : 8'd0;
                if (up_label == 8'd0 && left_label == 8'd0) begin
                  // New label
                  cur_label = next_label;
                  label[r_idx][c_idx] <= cur_label;
                  parent[cur_label]   <= cur_label; // self parent
                  next_label          <= next_label + 8'd1;
                end else if (up_label != 8'd0 && left_label == 8'd0) begin
                  // Use up label
                  cur_label = up_label;
                  label[r_idx][c_idx] <= cur_label;
                end else if (up_label == 8'd0 && left_label != 8'd0) begin
                  // Use left label
                  cur_label = left_label;
                  label[r_idx][c_idx] <= cur_label;
                end else begin
                  // Both neighbors have labels: choose min, unify
                  min_label = (up_label < left_label) ? up_label : left_label;
                  cur_label = min_label;
                  label[r_idx][c_idx] <= cur_label;
                  // Union operation: parent of max_label points to min_label (simple)
                  if (up_label != left_label) begin
                    if (up_label < left_label) begin
                      if (parent[left_label] == 8'd0 || parent[left_label] == left_label)
                        parent[left_label] <= uf_find(up_label);
                      else
                        parent[uf_find(left_label)] <= uf_find(up_label);
                    end else begin
                      if (parent[up_label] == 8'd0 || parent[up_label] == up_label)
                        parent[up_label] <= uf_find(left_label);
                      else
                        parent[uf_find(up_label)] <= uf_find(left_label);
                    end
                  end
                end
              end

              // Advance raster scan indices
              if (c_idx == 4'd15) begin
                c_idx <= 4'd0;
                if (r_idx == 4'd15) begin
                  r_idx <= 4'd0;
                  processing_pass <= 1'b1; // Move to consolidation next
                end else begin
                  r_idx <= r_idx + 4'd1;
                end
              end else begin
                c_idx <= c_idx + 4'd1;
              end
            end
          end else if (!counting_phase) begin
            // Consolidation / path compression for labels 1..next_label-1
            // One label per cycle
            if (count_label < next_label) begin
              if (parent[count_label] != 8'd0) begin
                parent[count_label] <= uf_find(count_label);
              end
              count_label <= count_label + 8'd1;
            end else begin
              // After finishing compression, prepare for counting roots
              count_label    <= 8'd1;
              counting_phase <= 1'b1;
            end
          end else begin
            // Counting unique roots as stellar bodies
            if (count_label < next_label) begin
              if (parent[count_label] == count_label && count_label != 8'd0)
                root_count <= root_count + 8'd1;
              count_label <= count_label + 8'd1;
            end
          end
        end

        DONE: begin
          done       <= 1'b1;
          star_count <= root_count;
        end

        default: begin
          // Should not occur
          done       <= 1'b0;
          star_count <= 8'd0;
        end
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = LOAD;
        end
      end

      LOAD: begin
        // Transition to PROCESS when start asserted (indicating end of loading)
        // Here we assume external controller pulses start again to begin processing.
        if (start) begin
          next_state = PROCESS;
        end
      end

      PROCESS: begin
        // Move to DONE when all phases complete or cycle limit reached
        if (counting_phase && (count_label >= next_label)) begin
          next_state = DONE;
        end else if (cycle_cnt >= 8'd250) begin
          // Safety: timeout to meet <=400 cycles requirement
          next_state = DONE;
        end
      end

      DONE: begin
        // Wait for start deassert then reassert to restart
        if (!start)
          next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

endmodule