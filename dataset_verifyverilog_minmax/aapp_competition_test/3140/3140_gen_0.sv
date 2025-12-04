module fish_point_counter (
  input clk,
  input rst_n,
  input start,
  input [1:0] x0,
  input [1:0] y0,
  input [4:0] k_val,
  input [4:0] l_val,
  input [4:0] t_grid [0:3][0:3],
  output reg [4:0] count,
  output reg done
);

  // 4x4 positions => 16 entries max
  // Each queue entry: 15 bits = 5(x) + 5(y) + 5(time)
  reg [14:0] q [0:15];
  reg [14:0] q_next [0:15];

  // BFS state machine
  typedef enum logic [1:0] { IDLE = 2'b00, BFS_EXPAND = 2'b01, BFS_CHECK = 2'b10, DONE = 2'b11 } state_t;
  state_t state, state_next;
  reg [4:0] shifts, shifts_next;        // count processed entries (0..16)
  reg count_en, count_clr;              // count control
  reg visited [0:15];                   // visited flags
  reg [14:0] p, p_next;                 // current point (x,y,time)
  reg [1:0] nx, ny;                     // neighbor coordinates
  reg [4:0] nt;                         // neighbor time
  reg p_valid_1q;                       // delayed p_valid for check stage
  reg p_valid, p_valid_next;            // p meets time constraints
  reg shift, shift_next;                // shift queue in BFS_CHECK
  reg ena, ena_next;                    // enqueue new point this cycle
  reg [14:0] enq_entry, enq_entry_next; // entry to enqueue
  reg [3:0] nidx, nidx_next;            // 0..3 neighbor index for expansion

  // Current point decode
  wire [1:0] px = p[14:10];
  wire [1:0] py = p[9:5];
  wire [4:0] pt = p[4:0];

  // Index for visited array
  function [3:0] idx;
    input [1:0] x, y;
    idx = {x, y}; // 0..15
  endfunction

  // Valid window: arrival >= t_grid[x][y] and arrival < t_grid + k_val
  function window_valid;
    input [1:0] x, y;
    input [4:0] arrival;
    input [4:0] k;
    reg [4:0] win_end;
  begin
    win_end = t_grid[x][y] + k;
    // Avoid overflow: 5-bit wrap-around is acceptable as we only need < check
    window_valid = (arrival >= t_grid[x][y]) && (arrival < win_end);
  end
  endfunction

  // Determine if p is valid
  always @(*) begin
    // Boundaries: px/py in 0..3 (guaranteed by construction), but keep guard
    p_valid = (px <= 2'd3) && (py <= 2'd3) && (pt <= l_val) && window_valid(px, py, pt, k_val);
  end

  // Neighbors (0:right, 1:left, 2:down, 3:up)
  always @(*) begin
    case (nidx)
      2'd0: begin nx = px + 1; ny = py; end // right
      2'd1: begin nx = px - 1; ny = py; end // left
      2'd2: begin nx = px;    ny = py + 1; end // down
      2'd3: begin nx = px;    ny = py - 1; end // up
      default: begin nx = 2'd0; ny = 2'd0; end
    endcase
    nt = pt + 1; // arrival time for neighbor
  end

  // Enqueue candidate build
  always @(*) begin
    enq_entry_next = {nx, ny, nt};
  end

  // Next-queue logic (shift register with 16 entries)
  integer i;
  always @(*) begin
    for (i = 0; i < 16; i++) q_next[i] = q[i];
    if (ena) q_next[15] = enq_entry_next; // enqueue at tail
  end

  // Sequential block
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      shifts <= 5'd0;
      count <= 5'd0;
      done <= 1'b0;
      p_valid_1q <= 1'b0;
      p <= 15'd0;
      shift <= 1'b0;
      ena <= 1'b0;
      nidx <= 4'd0;
      for (i = 0; i < 16; i++) begin
        q[i] <= 15'd0;
        visited[i] <= 1'b0;
      end
    end else begin
      state <= state_next;
      shifts <= shifts_next;
      p <= p_next;
      p_valid_1q <= p_valid;
      shift <= shift_next;
      ena <= ena_next;
      nidx <= nidx_next;
      for (i = 0; i < 16; i++) q[i] <= q_next[i];
      // Count update
      if (count_clr) count <= 5'd0;
      else if (count_en) count <= count + 1;
      // Done latch
      if (state_next == DONE) done <= 1'b1;
      else if (state == IDLE) done <= 1'b0;
    end
  end

  // Main FSM
  always @(*) begin
    // Defaults
    state_next = state;
    shifts_next = shifts;
    p_next = p;
    shift_next = 1'b0;
    ena_next = 1'b0;
    nidx_next = nidx;
    count_en = 1'b0;
    count_clr = 1'b0;

    case (state)
      IDLE: begin
        count_clr = 1'b1;
        ena_next = 1'b0;
        nidx_next = 4'd0;
        if (start) begin
          // Load start point at time 1
          p_next = {x0, y0, 5'd1};
          shifts_next = 5'd0;
          state_next = BFS_EXPAND;
        end else begin
          state_next = IDLE;
        end
      end

      BFS_EXPAND: begin
        // Count current point (if valid)
        if (p_valid) count_en = 1'b1;
        // Enqueue all valid neighbors in next 4 cycles (nidx 0..3)
        ena_next = 1'b0;
        nidx_next = nidx;
        if (nt <= l_val) begin
          ena_next = (nidx != 4'd4) && (nx <= 2'd3) && (ny <= 2'd3) &&
                     (~visited[idx(nx,ny)]) &&
                     window_valid(nx, ny, nt, k_val);
        end
        // Advance neighbor index each expand cycle
        if (nidx < 4'd3) nidx_next = nidx + 4'd1;
        else nidx_next = 4'd0;

        // After 1 cycle, go to BFS_CHECK and shift
        p_next = p;               // keep current point for next stage
        shifts_next = shifts;     // unchanged in BFS_EXPAND
        shift_next = 1'b0;
        state_next = BFS_CHECK;
      end

      BFS_CHECK: begin
        // Prepare for next entry
        p_next = q[0];            // head of queue
        // Shift the queue by 1 (discard head, pull new head next cycle)
        shift_next = 1'b1;
        shifts_next = shifts + 1;

        // Enqueue 4 neighbors (computed on previous BFS_EXPAND cycle)
        ena_next = 1'b0;
        if (nt <= l_val) begin
          ena_next = (nidx != 4'd0) && (nx <= 2'd3) && (ny <= 2'd3) &&
                     (~visited[idx(nx,ny)]) &&
                     window_valid(nx, ny, nt, k_val);
        end

        // Advance neighbor index across 4 check cycles
        nidx_next = (nidx < 4'd3) ? (nidx + 4'd1) : 4'd0;

        // Mark visited using the previous-cycle validity (p_valid_1q)
        // This is done via an explicit always block below.

        // Move to DONE after 16 shifts regardless of enqueues
        if (shifts >= 5'd15) state_next = DONE;
        else state_next = BFS_CHECK;
      end

      DONE: begin
        // Hold until start or reset
        state_next = DONE;
        ena_next = 1'b0;
        shift_next = 1'b0;
        p_next = p;
        shifts_next = shifts;
        nidx_next = nidx;
        count_en = 1'b0;
        count_clr = 1'b0;
      end

      default: begin
        state_next = IDLE;
        shifts_next = 5'd0;
        p_next = 15'd0;
        shift_next = 1'b0;
        ena_next = 1'b0;
        nidx_next = 4'd0;
        count_en = 1'b0;
        count_clr = 1'b1;
      end
    endcase
  end

  // Update visited flags (sync to allow de-assert in IDLE)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 0; i < 16; i++) visited[i] <= 1'b0;
    end else begin
      // In BFS_CHECK, mark visited based on previous cycle's p_valid
      if (state == BFS_CHECK && p_valid_1q) begin
        visited[idx(p[14:10], p[9:5])] <= 1'b1;
      end
      // In IDLE, clear visited
      if (state == IDLE) begin
        for (i = 0; i < 16; i++) visited[i] <= 1'b0;
      end
    end
  end

endmodule
