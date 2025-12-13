module app_installer(
  input  clk,
  input  rst_n,
  input  start,
  input  [9:0] c,
  input  [9:0] d1, input [9:0] s1,
  input  [9:0] d2, input [9:0] s2,
  input  [9:0] d3, input [9:0] s3,
  input  [9:0] d4, input [9:0] s4,
  input  [9:0] d5, input [9:0] s5,
  input  [9:0] d6, input [9:0] s6,
  input  [9:0] d7, input [9:0] s7,
  input  [9:0] d8, input [9:0] s8,
  output reg [3:0] max_count,
  output reg [3:0] order [0:7],
  output reg       done
);

  // Internal types
  typedef struct packed {
    logic [9:0] d;
    logic [9:0] s;
    logic [3:0] idx; // 1..8
    logic signed [10:0] diff; // s-d
  } app_t;

  // State machine
  typedef enum logic [1:0] {
    ST_IDLE  = 2'b00,
    ST_WAIT  = 2'b01,
    ST_DONE  = 2'b10
  } state_t;

  state_t state, next_state;

  // Latched inputs at start
  reg [9:0] c_reg;
  app_t app_in [0:7];

  // Sorted apps (combinational)
  app_t sorted [0:7];

  // Install computation (combinational)
  reg [9:0] space_after [0:8];
  reg [3:0] count_next;
  reg [3:0] order_next [0:7];

  // Cycle counter to enforce 12-cycle completion
  reg [3:0] cycle_cnt;

  // Capture inputs and initialize on start
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= ST_IDLE;
      cycle_cnt  <= 4'd0;
      max_count  <= 4'd0;
      done       <= 1'b0;
      order[0]   <= 4'd0;
      order[1]   <= 4'd0;
      order[2]   <= 4'd0;
      order[3]   <= 4'd0;
      order[4]   <= 4'd0;
      order[5]   <= 4'd0;
      order[6]   <= 4'd0;
      order[7]   <= 4'd0;
    end else begin
      state <= next_state;

      case (state)
        ST_IDLE: begin
          done <= 1'b0;
          cycle_cnt <= 4'd0;

          if (start) begin
            // Latch capacity
            c_reg <= c;

            // Latch app data with indices and diffs
            app_in[0].d    <= d1;
            app_in[0].s    <= s1;
            app_in[0].idx  <= 4'd1;
            app_in[0].diff <= $signed({1'b0,s1}) - $signed({1'b0,d1});

            app_in[1].d    <= d2;
            app_in[1].s    <= s2;
            app_in[1].idx  <= 4'd2;
            app_in[1].diff <= $signed({1'b0,s2}) - $signed({1'b0,d2});

            app_in[2].d    <= d3;
            app_in[2].s    <= s3;
            app_in[2].idx  <= 4'd3;
            app_in[2].diff <= $signed({1'b0,s3}) - $signed({1'b0,d3});

            app_in[3].d    <= d4;
            app_in[3].s    <= s4;
            app_in[3].idx  <= 4'd4;
            app_in[3].diff <= $signed({1'b0,s4}) - $signed({1'b0,d4});

            app_in[4].d    <= d5;
            app_in[4].s    <= s5;
            app_in[4].idx  <= 4'd5;
            app_in[4].diff <= $signed({1'b0,s5}) - $signed({1'b0,d5});

            app_in[5].d    <= d6;
            app_in[5].s    <= s6;
            app_in[5].idx  <= 4'd6;
            app_in[5].diff <= $signed({1'b0,s6}) - $signed({1'b0,d6});

            app_in[6].d    <= d7;
            app_in[6].s    <= s7;
            app_in[6].idx  <= 4'd7;
            app_in[6].diff <= $signed({1'b0,s7}) - $signed({1'b0,d7});

            app_in[7].d    <= d8;
            app_in[7].s    <= s8;
            app_in[7].idx  <= 4'd8;
            app_in[7].diff <= $signed({1'b0,s8}) - $signed({1'b0,d8});
          end
        end

        ST_WAIT: begin
          // Increment cycle counter
          if (cycle_cnt < 4'd15)
            cycle_cnt <= cycle_cnt + 4'd1;

          // At cycle 11 (0-based), update outputs so done pulses at cycle 12
          if (cycle_cnt == 4'd10) begin
            max_count <= count_next;
            order[0]  <= order_next[0];
            order[1]  <= order_next[1];
            order[2]  <= order_next[2];
            order[3]  <= order_next[3];
            order[4]  <= order_next[4];
            order[5]  <= order_next[5];
            order[6]  <= order_next[6];
            order[7]  <= order_next[7];
          end

          // Pulse done high at cycle 11->12 boundary
          if (cycle_cnt == 4'd11)
            done <= 1'b1;
          else if (cycle_cnt == 4'd12)
            done <= 1'b0;
        end

        ST_DONE: begin
          // Hold done low; wait for next start
          done <= 1'b0;
          cycle_cnt <= 4'd0;
        end

        default: begin
          done <= 1'b0;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      ST_IDLE: begin
        if (start)
          next_state = ST_WAIT;
      end
      ST_WAIT: begin
        // Complete exactly after 12 cycles from start (cycle_cnt from 0)
        if (cycle_cnt >= 4'd12)
          next_state = ST_DONE;
      end
      ST_DONE: begin
        if (start)
          next_state = ST_WAIT;
      end
      default: next_state = ST_IDLE;
    endcase
  end

  // Combinational sorting network (by diff, then by original index for stability)
  // Implemented as a fixed sequence of compare-and-swap stages (bitonic-style).

  function automatic app_t min_app(input app_t a, input app_t b);
    begin
      if (a.diff < b.diff)
        min_app = a;
      else if (a.diff > b.diff)
        min_app = b;
      else begin
        // tie-breaker: lower original index first
        if (a.idx <= b.idx)
          min_app = a;
        else
          min_app = b;
      end
    end
  endfunction

  function automatic app_t max_app(input app_t a, input app_t b);
    begin
      if (a.diff > b.diff)
        max_app = a;
      else if (a.diff < b.diff)
        max_app = b;
      else begin
        // tie-breaker: higher index later
        if (a.idx > b.idx)
          max_app = a;
        else
          max_app = b;
      end
    end
  endfunction

  // Wires for stages
  app_t st0 [0:7];
  app_t st1 [0:7];
  app_t st2 [0:7];
  app_t st3 [0:7];
  app_t st4 [0:7];
  app_t st5 [0:7];

  // Stage 0: load from app_in
  assign st0[0] = app_in[0];
  assign st0[1] = app_in[1];
  assign st0[2] = app_in[2];
  assign st0[3] = app_in[3];
  assign st0[4] = app_in[4];
  assign st0[5] = app_in[5];
  assign st0[6] = app_in[6];
  assign st0[7] = app_in[7];

  // Stage 1: (0,1) (2,3) (4,5) (6,7) ascending
  assign {st1[0], st1[1]} = {min_app(st0[0], st0[1]), max_app(st0[0], st0[1])};
  assign {st1[2], st1[3]} = {min_app(st0[2], st0[3]), max_app(st0[2], st0[3])};
  assign {st1[4], st1[5]} = {min_app(st0[4], st0[5]), max_app(st0[4], st0[5])};
  assign {st1[6], st1[7]} = {min_app(st0[6], st0[7]), max_app(st0[6], st0[7])};

  // Stage 2: (0,2) (1,3) (4,6) (5,7) ascending
  assign {st2[0], st2[2]} = {min_app(st1[0], st1[2]), max_app(st1[0], st1[2])};
  assign {st2[1], st2[3]} = {min_app(st1[1], st1[3]), max_app(st1[1], st1[3])};
  assign {st2[4], st2[6]} = {min_app(st1[4], st1[6]), max_app(st1[4], st1[6])};
  assign {st2[5], st2[7]} = {min_app(st1[5], st1[7]), max_app(st1[5], st1[7])};

  // Stage 3: (1,2) (5,6) ascending
  assign {st3[0]} = {st2[0]};
  assign {st3[3]} = {st2[3]};
  assign {st3[4]} = {st2[4]};
  assign {st3[7]} = {st2[7]};
  assign {st3[1], st3[2]} = {min_app(st2[1], st2[2]), max_app(st2[1], st2[2])};
  assign {st3[5], st3[6]} = {min_app(st2[5], st2[6]), max_app(st2[5], st2[6])};

  // Stage 4: (0,4) (1,5) (2,6) (3,7) ascending
  assign {st4[0], st4[4]} = {min_app(st3[0], st3[4]), max_app(st3[0], st3[4])};
  assign {st4[1], st4[5]} = {min_app(st3[1], st3[5]), max_app(st3[1], st3[5])};
  assign {st4[2], st4[6]} = {min_app(st3[2], st3[6]), max_app(st3[2], st3[6])};
  assign {st4[3], st4[7]} = {min_app(st3[3], st3[7]), max_app(st3[3], st3[7])};

  // Stage 5: (2,4) (3,5) ascending; (1,2) (3,4) (5,6) ascending; (0,1) (2,3) (4,5) (6,7) ascending
  // Break into sub-steps for clarity using st5 as final.

  app_t st4a [0:7];
  app_t st4b [0:7];

  // Step 5.1: (2,4) (3,5)
  assign st4a[0] = st4[0];
  assign st4a[1] = st4[1];
  assign {st4a[2], st4a[4]} = {min_app(st4[2], st4[4]), max_app(st4[2], st4[4])};
  assign {st4a[3], st4a[5]} = {min_app(st4[3], st4[5]), max_app(st4[3], st4[5])};
  assign st4a[6] = st4[6];
  assign st4a[7] = st4[7];

  // Step 5.2: (1,2) (3,4) (5,6)
  assign {st4b[1], st4b[2]} = {min_app(st4a[1], st4a[2]), max_app(st4a[1], st4a[2])};
  assign {st4b[3], st4b[4]} = {min_app(st4a[3], st4a[4]), max_app(st4a[3], st4a[4])};
  assign {st4b[5], st4b[6]} = {min_app(st4a[5], st4a[6]), max_app(st4a[5], st4a[6])};
  assign st4b[0] = st4a[0];
  assign st4b[7] = st4a[7];

  // Step 5.3: (0,1) (2,3) (4,5) (6,7)
  assign {st5[0], st5[1]} = {min_app(st4b[0], st4b[1]), max_app(st4b[0], st4b[1])};
  assign {st5[2], st5[3]} = {min_app(st4b[2], st4b[3]), max_app(st4b[2], st4b[3])};
  assign {st5[4], st5[5]} = {min_app(st4b[4], st4b[5]), max_app(st4b[4], st4b[5])};
  assign {st5[6], st5[7]} = {min_app(st4b[6], st4b[7]), max_app(st4b[6], st4b[7])};

  // Final sorted array
  assign sorted[0] = st5[0];
  assign sorted[1] = st5[1];
  assign sorted[2] = st5[2];
  assign sorted[3] = st5[3];
  assign sorted[4] = st5[4];
  assign sorted[5] = st5[5];
  assign sorted[6] = st5[6];
  assign sorted[7] = st5[7];

  // Combinational installation computation based on sorted and c_reg
  integer i;
  always @(*) begin
    // Initial available space
    space_after[0] = c_reg;
    count_next     = 4'd0;

    // Default order_next to zero
    for (i = 0; i < 8; i = i + 1) begin
      order_next[i] = 4'd0;
    end

    // Try to install each app in sorted order
    for (i = 0; i < 8; i = i + 1) begin
      if (space_after[i] >= ((sorted[i].d > sorted[i].s) ? sorted[i].d : sorted[i].s)) begin
        // Installable
        space_after[i+1] = space_after[i] - sorted[i].s;
        order_next[count_next] = sorted[i].idx;
        count_next = count_next + 4'd1;
      end else begin
        // Not installable; skip, keep space the same
        space_after[i+1] = space_after[i];
      end
    end
  end

endmodule