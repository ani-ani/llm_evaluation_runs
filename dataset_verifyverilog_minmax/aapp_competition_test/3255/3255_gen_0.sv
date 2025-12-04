module hopper_path_finder(
  input clk,               // clock signal
  input rst_n,             // active-low reset
  input start,             // initiate computation
  input [2:0] D,           // max jump distance (1-7)
  input [7:0] M,           // max value difference (signed)
  input [15:0] arr_0,      // array elements
  input [15:0] arr_1,
  input [15:0] arr_2,
  input [15:0] arr_3,
  input [15:0] arr_4,
  input [15:0] arr_5,
  input [15:0] arr_6,
  input [15:0] arr_7,
  output reg [3:0] max_length,  // result: longest path length
  output reg done           // high when computation complete
);

  // Internal array storage
  reg [15:0] mem [0:7];

  // BFS queue: store (index, length, visited mask)
  localparam QDEPTH = 64;
  localparam QW = 3 + 4 + 8; // idx(3) + len(4) + mask(8)
  reg [QW-1:0] queue [0:QDEPTH-1];
  reg [5:0] qhead, qtail, qcount; // up to 64 entries

  // Next-layer temporary storage for BFS level (parallel candidate collection)
  reg next_filled [0:7];
  reg [2:0] next_idx  [0:7];
  reg [3:0] next_len  [0:7];
  reg [7:0] next_mask [0:7];
  reg [2:0] next_filled_count;
  // Parallel candidate evaluation (8 targets)
  wire [7:0] cand_valid;
  wire [2:0] cand_idx  [0:7];
  wire [3:0] cand_len  [0:7];
  wire [7:0] cand_mask [0:7];

  // Current queue entry (replicated combinational for all 8 comparators)
  reg [2:0] cur_idx;
  reg [3:0] cur_len;
  reg [7:0] cur_mask;

  // Control
  reg [5:0] cycle_cnt;
  reg [2:0] state, next_state;
  localparam IDLE = 3'd0;
  localparam INIT = 3'd1;
  localparam BFS_POP = 3'd2;
  localparam BFS_CMP = 3'd3;
  localparam BFS_UPDATE = 3'd4;
  localparam DONE = 3'd5;

  // Helper functions
  function [2:0] abs_diff3;
    input [2:0] a, b;
    begin
      abs_diff3 = (a >= b) ? (a - b) : (b - a);
    end
  endfunction

  function [15:0] abs_diff16;
    input [15:0] a, b;
    reg [15:0] diff;
    begin
      diff = a - b;
      abs_diff16 = diff[15] ? (~diff + 1) : diff;
    end
  endfunction

  // Current queue entry (driven in POP stage; held via registers)
  always_comb begin
    cur_idx  = queue[qhead][QW-1 -: 3];
    cur_len  = queue[qhead][QW-1-3 -: 4];
    cur_mask = queue[qhead][QW-1-3-4 -: 8];
  end

  // Parallel validity checks for all 8 potential next indices
  genvar g;
  generate
    for (g = 0; g < 8; g = g + 1) begin : gen_cands
      wire [2:0] nidx = 3'(g);
      wire [2:0] dist = abs_diff3(cur_idx, nidx);
      wire [15:0] diff = abs_diff16(mem[cur_idx], mem[nidx]);
      wire in_range = (dist <= D) && (dist != 0); // distance constraint
      wire diff_ok = (diff <= M);                 // value difference constraint
      wire not_visited = ~cur_mask[g];            // no revisits
      assign cand_valid[g] = (in_range && diff_ok && not_visited) ? 1'b1 : 1'b0;
      assign cand_idx[g]   = nidx;
      assign cand_len[g]   = cur_len + 1;
      assign cand_mask[g]  = cur_mask | (1'b1 << g);
    end
  endgenerate

  // State machine + datapath
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset states and outputs
      state <= IDLE;
      max_length <= 4'd0;
      done <= 1'b0;
      cycle_cnt <= 6'd0;
      // Clear queue and temp storage
      qhead <= 6'd0;
      qtail <= 6'd0;
      qcount <= 6'd0;
      next_filled_count <= 3'd0;
      for (int i = 0; i < 8; i++) begin
        next_filled[i] <= 1'b0;
        next_idx[i]    <= 3'd0;
        next_len[i]    <= 4'd0;
        next_mask[i]   <= 8'd0;
      end
    end else begin
      // Default: keep current values; FSM will update
      next_filled_count <= next_filled_count; // avoid warnings
      case (state)
        IDLE: begin
          max_length <= 4'd0;
          done <= 1'b0;
          if (start) begin
            state <= INIT;
          end
        end

        INIT: begin
          // Load array into internal memory
          mem[0] <= arr_0;
          mem[1] <= arr_1;
          mem[2] <= arr_2;
          mem[3] <= arr_3;
          mem[4] <= arr_4;
          mem[5] <= arr_5;
          mem[6] <= arr_6;
          mem[7] <= arr_7;

          // Clear queue
          qhead <= 6'd0;
          qtail <= 6'd0;
          qcount <= 6'd0;

          // Clear next-layer temp storage
          next_filled_count <= 3'd0;
          for (int i = 0; i < 8; i++) begin
            next_filled[i] <= 1'b0;
            next_idx[i]    <= 3'd0;
            next_len[i]    <= 4'd0;
            next_mask[i]   <= 8'd0;
          end

          // Prepare initial candidates from each start node (parallel)
          for (int s = 0; s < 8; s++) begin
            bit found = 1'b0;
            // Check all possible next nodes in parallel (reuse the same check hardware as below)
            for (int t = 0; t < 8 && !found; t++) begin
              if (s != t) begin
                wire [2:0] dist = abs_diff3(3'(s), 3'(t));
                wire [15:0] diff = abs_diff16(mem[s], mem[t]);
                if ((dist <= D) && (dist != 0) && (diff <= M)) begin
                  // There is room in next_filled?
                  if (next_filled_count < 3'd8) begin
                    // Write to next storage at next_filled_count
                    next_idx[next_filled_count] <= 3'(t);
                    next_len[next_filled_count] <= 4'd1; // path length after taking s->t
                    next_mask[next_filled_count] <= (8'(1) << s) | (8'(1) << t);
                    next_filled[next_filled_count] <= 1'b1;
                    next_filled_count <= next_filled_count + 1'b1;
                    found = 1'b1;
                  end
                end
              end
            end
            // Note: If no valid t or no space, skip (path of length 1 cannot be extended)
          end

          // Prepare queue with those next-layer entries (up to 8)
          qtail <= next_filled_count;
          qcount <= next_filled_count;
          for (int j = 0; j < 8; j++) begin
            if (j < next_filled_count) begin
              queue[j] <= {next_idx[j], next_len[j], next_mask[j]};
            end else begin
              queue[j] <= {QW{1'b0}};
            end
          end
          // Reset next storage for BFS iterations
          next_filled_count <= 3'd0;
          for (int i = 0; i < 8; i++) next_filled[i] <= 1'b0;

          // Update max_length: longest initial path seen (length 1)
          max_length <= (next_filled_count > 0) ? 4'd1 : 4'd0;

          state <= (cycle_cnt >= 6'd63) ? DONE : BFS_POP;
        end

        BFS_POP: begin
          if (qcount == 6'd0) begin
            // No more paths to extend
            state <= DONE;
          end else begin
            // Dequeue head
            qhead <= qhead + 1'b1;
            qcount <= qcount - 1'b1;
            state <= BFS_CMP;
          end
        end

        BFS_CMP: begin
          // Fill next-layer temp storage with valid neighbors (parallel check)
          next_filled_count <= 3'd0;
          for (int k = 0; k < 8; k++) next_filled[k] <= 1'b0;
          for (int i = 0; i < 8; i++) begin
            if (cand_valid[i] && (next_filled_count < 3'd8)) begin
              next_idx[next_filled_count] <= cand_idx[i];
              next_len[next_filled_count] <= cand_len[i];
              next_mask[next_filled_count] <= cand_mask[i];
              next_filled[next_filled_count] <= 1'b1;
              next_filled_count <= next_filled_count + 1'b1;
            end
          end
          state <= BFS_UPDATE;
        end

        BFS_UPDATE: begin
          // Enqueue as many next-layer entries as possible without overflow
          for (int i = 0; i < 8; i++) begin
            if (next_filled[i]) begin
              if (qcount < QDEPTH) begin
                queue[qtail] <= {next_idx[i], next_len[i], next_mask[i]};
                qtail <= qtail + 1'b1;
                qcount <= qcount + 1'b1;
              end
            end
          end

          // Update max_length if we discovered longer paths (ignore length 0 entries)
          if (cur_len != 4'd0) begin
            if (cur_len > max_length) max_length <= cur_len;
          end
          // Also check any candidate that would extend current path
          for (int j = 0; j < 8; j++) begin
            if (next_filled[j] && (next_len[j] > max_length)) begin
              max_length <= next_len[j];
            end
          end

          state <= (cycle_cnt >= 6'd63) ? DONE : BFS_POP;
        end

        DONE: begin
          done <= 1'b1;
          state <= DONE; // stay done until reset
        end

        default: state <= IDLE;
      endcase

      // Global cycle counter for worst-case bound (64 cycles from start)
      if (state == IDLE) begin
        cycle_cnt <= 6'd0;
      end else begin
        cycle_cnt <= cycle_cnt + 1'b1;
      end
    end
  end

endmodule
