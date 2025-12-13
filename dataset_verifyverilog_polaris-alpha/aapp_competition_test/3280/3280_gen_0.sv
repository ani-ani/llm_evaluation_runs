module show_recorder(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [1:0] k,
  input [31:0] show_times[0:15],
  output reg [2:0] count,
  output reg done
);

  // State encoding
  localparam IDLE       = 2'b00;
  localparam SORTING    = 2'b01;
  localparam ALLOCATING = 2'b10;
  localparam DONE       = 2'b11;

  reg [1:0] state, next_state;

  // Internal storage for up to 8 shows: x = start, y = end
  reg [31:0] show_x [0:7];
  reg [31:0] show_y [0:7];

  // Slot trackers: last end-time in each slot (max 4 slots)
  reg [31:0] slot_end [0:3];

  // Bubble sort indices
  reg [2:0] i_idx;     // outer loop index (0..7)
  reg [2:0] j_idx;     // inner loop index (0..6)
  reg       sort_done;

  // Allocation index
  reg [2:0] alloc_idx; // 0..7
  reg [2:0] show_count;

  // Temporary for swapping
  reg [31:0] tmp_x, tmp_y;

  // FSM sequential
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      done       <= 1'b0;
      count      <= 3'd0;
      i_idx      <= 3'd0;
      j_idx      <= 3'd0;
      sort_done  <= 1'b0;
      alloc_idx  <= 3'd0;
      show_count <= 3'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done       <= 1'b0;
          count      <= 3'd0;
          show_count <= 3'd0;
          sort_done  <= 1'b0;
          i_idx      <= 3'd0;
          j_idx      <= 3'd0;
          alloc_idx  <= 3'd0;

          if (start) begin
            // Load up to n shows from flat array: show_times[2*i] = x_i, [2*i+1] = y_i
            // For i >= n, fill with large end-time so they naturally bubble to the end
            show_x[0] <= show_times[0];
            show_y[0] <= show_times[1];
            show_x[1] <= (n > 3'd1) ? show_times[2]  : 32'hFFFFFFFF;
            show_y[1] <= (n > 3'd1) ? show_times[3]  : 32'hFFFFFFFF;
            show_x[2] <= (n > 3'd2) ? show_times[4]  : 32'hFFFFFFFF;
            show_y[2] <= (n > 3'd2) ? show_times[5]  : 32'hFFFFFFFF;
            show_x[3] <= (n > 3'd3) ? show_times[6]  : 32'hFFFFFFFF;
            show_y[3] <= (n > 3'd3) ? show_times[7]  : 32'hFFFFFFFF;
            show_x[4] <= (n > 3'd4) ? show_times[8]  : 32'hFFFFFFFF;
            show_y[4] <= (n > 3'd4) ? show_times[9]  : 32'hFFFFFFFF;
            show_x[5] <= (n > 3'd5) ? show_times[10] : 32'hFFFFFFFF;
            show_y[5] <= (n > 3'd5) ? show_times[11] : 32'hFFFFFFFF;
            show_x[6] <= (n > 3'd6) ? show_times[12] : 32'hFFFFFFFF;
            show_y[6] <= (n > 3'd6) ? show_times[13] : 32'hFFFFFFFF;
            show_x[7] <= (n > 3'd7) ? show_times[14] : 32'hFFFFFFFF;
            show_y[7] <= (n > 3'd7) ? show_times[15] : 32'hFFFFFFFF;
          end
        end

        SORTING: begin
          // Bubble sort by show_y ascending over fixed 8 entries
          if (!sort_done) begin
            if (i_idx < 3'd7) begin
              if (j_idx < 3'd7 - i_idx) begin
                if (show_y[j_idx] > show_y[j_idx+1]) begin
                  tmp_x                 <= show_x[j_idx];
                  tmp_y                 <= show_y[j_idx];
                  show_x[j_idx]         <= show_x[j_idx+1];
                  show_y[j_idx]         <= show_y[j_idx+1];
                  show_x[j_idx+1]       <= tmp_x;
                  show_y[j_idx+1]       <= tmp_y;
                end
                j_idx <= j_idx + 3'd1;
              end else begin
                j_idx <= 3'd0;
                i_idx <= i_idx + 3'd1;
              end
            end else begin
              sort_done <= 1'b1;
            end
          end
        end

        ALLOCATING: begin
          if (alloc_idx == 3'd0) begin
            // Initialize slot end times to zero at start of allocation
            slot_end[0] <= 32'd0;
            slot_end[1] <= 32'd0;
            slot_end[2] <= 32'd0;
            slot_end[3] <= 32'd0;
          end

          if (alloc_idx < n) begin
            // Try to assign current show to one of k slots
            // Greedy: first slot where show_x >= slot_end
            reg assigned;
            assigned = 1'b0;

            if (!assigned && (k > 2'd0) && (show_x[alloc_idx] >= slot_end[0])) begin
              slot_end[0] <= show_y[alloc_idx];
              show_count  <= show_count + 3'd1;
              assigned    <= 1'b1;
            end
            if (!assigned && (k > 2'd1) && (show_x[alloc_idx] >= slot_end[1])) begin
              slot_end[1] <= show_y[alloc_idx];
              show_count  <= show_count + 3'd1;
              assigned    <= 1'b1;
            end
            if (!assigned && (k > 2'd2) && (show_x[alloc_idx] >= slot_end[2])) begin
              slot_end[2] <= show_y[alloc_idx];
              show_count  <= show_count + 3'd1;
              assigned    <= 1'b1;
            end
            if (!assigned && (k > 2'd3) && (show_x[alloc_idx] >= slot_end[3])) begin
              slot_end[3] <= show_y[alloc_idx];
              show_count  <= show_count + 3'd1;
              assigned    <= 1'b1;
            end

            alloc_idx <= alloc_idx + 3'd1;
          end else begin
            // Allocation done; latch result in next state transition
          end
        end

        DONE: begin
          done  <= 1'b1;
          count <= show_count;
        end

        default: begin
          // Should not occur
          state <= IDLE;
        end
      endcase
    end
  end

  // FSM combinational next state
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = SORTING;
      end

      SORTING: begin
        if (sort_done)
          next_state = ALLOCATING;
      end

      ALLOCATING: begin
        if (alloc_idx >= n)
          next_state = DONE;
      end

      DONE: begin
        // Wait for start deassert then reassert to begin new computation
        if (!start)
          next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule