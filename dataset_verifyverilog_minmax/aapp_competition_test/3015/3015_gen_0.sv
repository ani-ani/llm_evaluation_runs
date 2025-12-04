module hamster_navigator(
  input clk, // Clock signal
  input rst_n, // Active-low reset
  input start, // Start computation (pulse high)
  input [1:0] start_node, // 2-bit start ball (0-3)
  input [1:0] bed_node, // 2-bit bed ball (0-3)
  input [15:0] graph_data, // Packed graph edge: {2'bstart, 2'bend, 4'bweight} [max 16 edges]
  input [3:0] edge_count, // Number of valid edges (0-15)
  output reg [15:0] min_time, // Computed time to bed (0-65535)
  output reg infinity, // High if no valid path
  output reg done // High when computation complete
);

  // --- Local parameters ---
  localparam EDGE_W = 8;  // 2 (src) + 2 (dst) + 4 (wgt) = 8 bits per edge
  localparam MAX_EDGES = 16;
  localparam LOG2_W = $clog2(EDGE_W); // for muxes
  localparam ST_IDLE = 2'b00;
  localparam ST_CALC = 2'b01;
  localparam ST_DONE = 2'b10;

  // --- Edge RAM (1 read port, 1 write port) ---
  reg [EDGE_W-1:0] edge_ram [0:MAX_EDGES-1];
  reg [3:0] wr_ptr;          // write pointer within current load
  reg [3:0] rd_ptr;          // read pointer during compute
  reg [3:0] load_count;      // number of edges actually loaded (<= edge_count)

  // --- BFS state: 4 nodes x (left/right turn), up to 8 steps (2 per node) ---
  reg [3:0] step;            // 0..8
  reg [1:0] cur_state;

  // Frontier current: {node[1:0], turn}
  // frontier_cur[0..7] -> 8 possible states in canonical order
  // turn 0: nodes 0..3 at indices 0..3; turn 1: nodes 0..3 at indices 4..7
  reg [2:0] frontier_cur [0:7];
  // Frontier next buffer (shift register across cycles to align with edge reads)
  reg [2:0] frontier_next_buf [0:7];

  // Direct access to current frontier (packed for edge decode)
  wire [3:0] frontier_cur_nodes;
  wire       frontier_cur_turn;
  assign {frontier_cur_turn, frontier_cur_nodes} = frontier_cur[step[2:0]]; // turn is MSB for canonical decode

  // Best known time to each node (across both turns, to avoid cycles)
  reg [15:0] best_time [0:3];

  // Bed reachable detection (capture earliest step when reached)
  reg found_step_valid;
  reg [3:0] found_step; // 0..8
  reg [15:0] min_time_internal;

  // Edge being examined this cycle (from buffer-aligned read)
  wire [1:0] e_src;
  wire [1:0] e_dst;
  wire [3:0] e_wgt;
  wire [EDGE_W-1:0] edge_curr; // either buffered or from load mux

  // Small muxes to choose between newly loaded edge and buffered edges during CALC
  wire [2:0] next_buf_data; // {turn, node}
  // In CALC:
  // - if !calc_active -> no compute, next_buf_data = 0
  // - else if load_active -> next_buf_data = frontier_cur (frontier, using cur turn)
  // - else -> next_buf_data = frontier_next_buf[rd_ptr]
  assign next_buf_data = (cur_state != ST_CALC) ? 3'b0 :
                         (load_count < edge_count) ? {frontier_cur_turn, frontier_cur_nodes} :
                         frontier_next_buf[rd_ptr];

  // Choose the edge to process: during loading cycles we use graph_data packed,
  // otherwise we use the buffered value from rd_ptr.
  // edge_curr is 8-bit: {src[1:0], dst[1:0], wgt[3:0]}
  assign edge_curr = (cur_state != ST_CALC) ? 8'b0 :
                     (load_count < edge_count) ? graph_data[7:0] :
                     edge_ram[rd_ptr];

  assign e_src = edge_curr[7:6];
  assign e_dst = edge_curr[5:4];
  assign e_wgt = edge_curr[3:0]; // 4-bit weight (0 treated as 16 to be safe)

  // Control flags
  wire calc_active;
  assign calc_active = (cur_state == ST_CALC);
  wire load_active;
  assign load_active = calc_active && (load_count < edge_count);

  // --- State machine and datapath ---
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cur_state <= ST_IDLE;
      done <= 1'b0;
      infinity <= 1'b0;
      min_time <= 16'b0;

      wr_ptr <= 4'b0;
      rd_ptr <= 4'b0;
      load_count <= 4'b0;
      step <= 4'b0;

      // Reset memory content
      for (int i = 0; i < MAX_EDGES; i++) edge_ram[i] <= 8'b0;

      // Reset frontiers and buffers
      for (int i = 0; i < 8; i++) begin
        frontier_cur[i] <= 3'b0;
        frontier_next_buf[i] <= 3'b0;
      end

      // Reset best times
      for (int n = 0; n < 4; n++) best_time[n] <= 16'hFFFF; // unreachable initially

      // Reset found flags and internal min time
      found_step_valid <= 1'b0;
      found_step <= 4'b0;
      min_time_internal <= 16'b0;
    end else begin
      case (cur_state)
        ST_IDLE: begin
          // Initialize for a new run
          done <= 1'b0;
          infinity <= 1'b0;
          min_time <= 16'b0;

          wr_ptr <= 4'b0;
          rd_ptr <= 4'b0;
          load_count <= 4'b0;
          step <= 4'b0;

          for (int i = 0; i < 8; i++) frontier_next_buf[i] <= 3'b0;
          for (int n = 0; n < 4; n++) best_time[n] <= 16'hFFFF;
          found_step_valid <= 1'b0;
          found_step <= 4'b0;
          min_time_internal <= 16'b0;

          // Prime frontier with the start state at step 0 (left turn = 0)
          frontier_cur[0] <= {1'b0, start_node[1:0]}; // turn 0
          for (int i = 1; i < 8; i++) frontier_cur[i] <= 3'b0;

          if (start) begin
            cur_state <= ST_CALC;
          end
        end

        ST_CALC: begin
          // Edge loading control
          if (load_active) begin
            edge_ram[wr_ptr] <= graph_data[7:0]; // store 8-bit packed edge
            wr_ptr <= wr_ptr + 1'b1;
            load_count <= load_count + 1'b1;
          end else begin
            // No load; keep pointers stable
            wr_ptr <= wr_ptr;
            load_count <= load_count;
          end

          // RD pointer increments once we have all edges
          if (load_count == edge_count) begin
            if ((rd_ptr + 1'b1) < edge_count) rd_ptr <= rd_ptr + 1'b1;
            else rd_ptr <= rd_ptr; // hold at last
          end else begin
            rd_ptr <= 4'b0;
          end

          // Advance step counter (max 8 steps)
          if (step < 4'd8) step <= step + 1'b1;

          // Frontier "next" buffer shift: push new data at index load_count
          if (load_count < edge_count) begin
            frontier_next_buf[load_count] <= next_buf_data;
          end

          // Core BFS expansion and best time update
          if (load_active) begin
            // While still loading, we compare with the current frontier entry
            if (e_src == frontier_cur_nodes) begin
              // Evaluate time for destination node
              // t_node = step * 4 + wgt; since step==load_count here
              // Treat e_wgt==0 as weight 16 to be safe
              {found_step_valid, found_step, min_time_internal} <=
                update_best_time(frontier_cur_turn, e_dst, e_wgt,
                                 step, load_count, bed_node,
                                 found_step_valid, found_step, min_time_internal);
            end
          end else begin
            // After load completes, compare with buffered frontiers
            if (rd_ptr < edge_count) begin
              if (e_src == frontier_next_buf[rd_ptr][1:0]) begin
                {found_step_valid, found_step, min_time_internal} <=
                  update_best_time(frontier_next_buf[rd_ptr][2], e_dst, e_wgt,
                                   step, rd_ptr, bed_node,
                                   found_step_valid, found_step, min_time_internal);
              end
            end
          end

          // Finish condition: after we have processed step == 8 and all edges
          if ((step == 4'd8) && (load_count == edge_count) && (rd_ptr == (edge_count - 1))) begin
            cur_state <= ST_DONE;
            done <= 1'b1;
            if (found_step_valid) begin
              infinity <= 1'b0;
              min_time <= min_time_internal;
            end else begin
              infinity <= 1'b1;
              min_time <= 16'b0;
            end
          end
        end

        ST_DONE: begin
          // Hold outputs until next start or reset
          done <= 1'b1;
          infinity <= infinity;
          min_time <= min_time;
          if (start) begin
            // Allow immediate re-run
            cur_state <= ST_IDLE;
          end
        end

        default: cur_state <= ST_IDLE;
      endcase
    end
  end

  // Helper function-like task to compute best time and detect bed arrival
  // Implemented as a continuous assignment to emulate combinational function
  // Inputs: turn, dst, wgt, step, idx, bed, found_step_valid, found_step, min_time_internal
  // Outputs: found_step_valid, found_step, min_time_internal
  function [19:0] update_best_time;
    input       turn;          // 0:left, 1:right
    input [1:0] dst;
    input [3:0] wgt;
    input [3:0] step;          // current step number (0..8)
    input [3:0] idx;           // index in frontier being examined (also equals step during load)
    input [1:0] bed;
    input       found_step_valid_in;
    input [3:0] found_step_in;
    input [15:0] min_time_internal_in;

    reg [3:0] wgt_eff;
    reg [15:0] t_node;
    reg [15:0] t_best;
    reg [15:0] t_next;
    reg        bed_reached;
    reg [3:0]  cand_step;
    reg [15:0] cand_time;
    begin
      // Effective weight: if wgt == 0, treat as 16
      wgt_eff = (wgt == 4'b0) ? 4'd16 : wgt;
      t_node = ({12'b0, step} * 16'd4) + {12'b0, wgt_eff};

      // Determine the candidate result
      cand_step = idx;
      cand_time = t_node;

      // If we already found earlier, keep it
      if (found_step_valid_in) begin
        update_best_time = {1'b1, found_step_in, min_time_internal_in};
      end else begin
        // Bed reached if this is the bed_node
        bed_reached = (dst == bed);
        if (bed_reached) begin
          // Found at this step with candidate_time
          update_best_time = {1'b1, cand_step, cand_time};
        end else begin
          update_best_time = {1'b0, 4'b0, 16'b0};
        end
      end
    end
  endfunction

endmodule
