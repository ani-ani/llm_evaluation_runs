module domino_tiling_maxsum(
  input clk,
  input rst_n,
  input start,
  input [19:0] row0_col0, row0_col1, row0_col2,
  input [19:0] row1_col0, row1_col1, row1_col2,
  input [19:0] row2_col0, row2_col1, row2_col2,
  input [19:0] row3_col0, row3_col1, row3_col2,
  output reg [23:0] max_sum,
  output reg done
);

  // Parameters
  localparam int NROWS = 4;
  localparam int NCOLS = 3;
  localparam int K     = 2; // exactly 2 dominoes

  // State encoding
  typedef enum logic [2:0] {
    IDLE      = 3'd0,
    CALC_ROW0 = 3'd1,
    CALC_ROW1 = 3'd2,
    CALC_ROW2 = 3'd3,
    CALC_ROW3 = 3'd4,
    DONE      = 3'd5
  } state_t;

  state_t state, next_state;

  // Signed versions of inputs (extend to 24-bit for safe arithmetic)
  wire signed [23:0] r0c0 = {{4{row0_col0[19]}}, row0_col0};
  wire signed [23:0] r0c1 = {{4{row0_col1[19]}}, row0_col1};
  wire signed [23:0] r0c2 = {{4{row0_col2[19]}}, row0_col2};
  wire signed [23:0] r1c0 = {{4{row1_col0[19]}}, row1_col0};
  wire signed [23:0] r1c1 = {{4{row1_col1[19]}}, row1_col1};
  wire signed [23:0] r1c2 = {{4{row1_col2[19]}}, row1_col2};
  wire signed [23:0] r2c0 = {{4{row2_col0[19]}}, row2_col0};
  wire signed [23:0] r2c1 = {{4{row2_col1[19]}}, row2_col1};
  wire signed [23:0] r2c2 = {{4{row2_col2[19]}}, row2_col2};
  wire signed [23:0] r3c0 = {{4{row3_col0[19]}}, row3_col0};
  wire signed [23:0] r3c1 = {{4{row3_col1[19]}}, row3_col1};
  wire signed [23:0] r3c2 = {{4{row3_col2[19]}}, row3_col2};

  // DP arrays:
  // We track per row-index i the maximum sum using exactly k dominoes with a given mask of occupied cells in row i.
  // mask: 3 bits for 3 columns (1 = occupied by vertical domino ending at this row).
  // For K=2, we only need k=0,1,2.

  // Current row DP
  reg signed [23:0] dp0_cur [0:7]; // k=0, mask=0..7
  reg signed [23:0] dp1_cur [0:7]; // k=1
  reg signed [23:0] dp2_cur [0:7]; // k=2

  // Next row DP
  reg signed [23:0] dp0_nxt [0:7];
  reg signed [23:0] dp1_nxt [0:7];
  reg signed [23:0] dp2_nxt [0:7];

  // Large negative constant for -infinity
  localparam signed [23:0] NEG_INF = -24'sd8000000;

  integer m;

  // Max function for 24-bit signed
  function automatic signed [23:0] fmax2(input signed [23:0] a, input signed [23:0] b);
    begin
      fmax2 = (a > b) ? a : b;
    end
  endfunction

  // Clear next DP to -INF
  task automatic clear_next_dp;
    integer i;
    begin
      for (i = 0; i < 8; i = i + 1) begin
        dp0_nxt[i] = NEG_INF;
        dp1_nxt[i] = NEG_INF;
        dp2_nxt[i] = NEG_INF;
      end
    end
  endtask

  // Initialize all current DP to -INF
  task automatic clear_cur_dp;
    integer i;
    begin
      for (i = 0; i < 8; i = i + 1) begin
        dp0_cur[i] = NEG_INF;
        dp1_cur[i] = NEG_INF;
        dp2_cur[i] = NEG_INF;
      end
    end
  endtask

  // Horizontal domino placements for a row's cell values
  function automatic signed [23:0] h01(input signed [23:0] c0, input signed [23:0] c1);
    begin
      h01 = c0 + c1;
    end
  endfunction
  function automatic signed [23:0] h12(input signed [23:0] c1, input signed [23:0] c2);
    begin
      h12 = c1 + c2;
    end
  endfunction
  function automatic signed [23:0] h02_12(input signed [23:0] c0, input signed [23:0] c1, input signed [23:0] c2);
    begin
      h02_12 = c0 + c1 + c1 + c2; // two horizontals: (0,1) and (1,2)
    end
  endfunction

  // DP transition for a given row's values (v0,v1,v2)
  task automatic dp_step(
    input  signed [23:0] v0,
    input  signed [23:0] v1,
    input  signed [23:0] v2
  );
    integer pm;
    reg signed [23:0] base0, base1, base2;
    reg signed [23:0] val;
    begin
      clear_next_dp();

      // For each previous mask pm, propagate with all valid placements in current row.
      for (pm = 0; pm < 8; pm = pm + 1) begin
        base0 = dp0_cur[pm];
        base1 = dp1_cur[pm];
        base2 = dp2_cur[pm];

        // Skip unreachable
        if (base0 == NEG_INF && base1 == NEG_INF && base2 == NEG_INF)
          continue;

        // Occupied from verticals coming from previous row
        // pm bit=1 means this cell in current row is occupied.

        // Case 1: no new domino in this row
        // next mask is 0 (no verticals created here)
        if (base0 != NEG_INF)
          dp0_nxt[0] = fmax2(dp0_nxt[0], base0);
        if (base1 != NEG_INF)
          dp1_nxt[0] = fmax2(dp1_nxt[0], base1);
        if (base2 != NEG_INF)
          dp2_nxt[0] = fmax2(dp2_nxt[0], base2);

        // Horizontal placements (within this row, cannot overlap occupied cells from pm)
        // h(0,1)
        if (!pm[0] && !pm[1]) begin
          // uses two cells; increase k by 1
          val = h01(v0, v1);
          if (base0 != NEG_INF)
            dp1_nxt[0] = fmax2(dp1_nxt[0], base0 + val);
          if (base1 != NEG_INF)
            dp2_nxt[0] = fmax2(dp2_nxt[0], base1 + val);
        end
        // h(1,2)
        if (!pm[1] && !pm[2]) begin
          val = h12(v1, v2);
          if (base0 != NEG_INF)
            dp1_nxt[0] = fmax2(dp1_nxt[0], base0 + val);
          if (base1 != NEG_INF)
            dp2_nxt[0] = fmax2(dp2_nxt[0], base1 + val);
        end
        // two horizontals (0,1) and (1,2): need col0,1,2 all free
        if (!pm[0] && !pm[1] && !pm[2]) begin
          val = h02_12(v0, v1, v2);
          if (base0 != NEG_INF)
            dp2_nxt[0] = fmax2(dp2_nxt[0], base0 + val);
        end

        // Vertical placements starting here (downwards), set corresponding bit in next mask
        // v at col0
        if (!pm[0]) begin
          val = v0;
          if (base0 != NEG_INF)
            dp1_nxt[3'b001] = fmax2(dp1_nxt[3'b001], base0 + val);
          if (base1 != NEG_INF)
            dp2_nxt[3'b001] = fmax2(dp2_nxt[3'b001], base1 + val);
        end
        // v at col1
        if (!pm[1]) begin
          val = v1;
          if (base0 != NEG_INF)
            dp1_nxt[3'b010] = fmax2(dp1_nxt[3'b010], base0 + val);
          if (base1 != NEG_INF)
            dp2_nxt[3'b010] = fmax2(dp2_nxt[3'b010], base1 + val);
        end
        // v at col2
        if (!pm[2]) begin
          val = v2;
          if (base0 != NEG_INF)
            dp1_nxt[3'b100] = fmax2(dp1_nxt[3'b100], base0 + val);
          if (base1 != NEG_INF)
            dp2_nxt[3'b100] = fmax2(dp2_nxt[3'b100], base1 + val);
        end

        // Note: no combination of horizontals and verticals on same cell; checks via pm & mask
        // Current formulation ensures verticals only use cells not in pm; horizontals only use cells not in pm.
      end

      // Move next -> cur
      for (pm = 0; pm < 8; pm = pm + 1) begin
        dp0_cur[pm] = dp0_nxt[pm];
        dp1_cur[pm] = dp1_nxt[pm];
        dp2_cur[pm] = dp2_nxt[pm];
      end
    end
  endtask

  // Special last row processing: verticals cannot start here; only use existing mask.
  task automatic dp_last_row(
    input  signed [23:0] v0,
    input  signed [23:0] v1,
    input  signed [23:0] v2
  );
    integer pm;
    reg signed [23:0] base0, base1, base2;
    reg signed [23:0] val;
    begin
      clear_next_dp();

      for (pm = 0; pm < 8; pm = pm + 1) begin
        base0 = dp0_cur[pm];
        base1 = dp1_cur[pm];
        base2 = dp2_cur[pm];
        if (base0 == NEG_INF && base1 == NEG_INF && base2 == NEG_INF)
          continue;

        // Cells occupied by verticals from previous row: pm bits

        // 1) no new domino, mask must be 0 at end for validity
        // We enforce mask 0 only when computing final result; here we still write only to mask 0.
        if (base0 != NEG_INF)
          dp0_nxt[0] = fmax2(dp0_nxt[0], base0);
        if (base1 != NEG_INF)
          dp1_nxt[0] = fmax2(dp1_nxt[0], base1);
        if (base2 != NEG_INF)
          dp2_nxt[0] = fmax2(dp2_nxt[0], base2);

        // 2) horizontals only where cells are free (pm bits 0)
        // h(0,1)
        if (!pm[0] && !pm[1]) begin
          val = h01(v0, v1);
          if (base0 != NEG_INF)
            dp1_nxt[0] = fmax2(dp1_nxt[0], base0 + val);
          if (base1 != NEG_INF)
            dp2_nxt[0] = fmax2(dp2_nxt[0], base1 + val);
        end
        // h(1,2)
        if (!pm[1] && !pm[2]) begin
          val = h12(v1, v2);
          if (base0 != NEG_INF)
            dp1_nxt[0] = fmax2(dp1_nxt[0], base0 + val);
          if (base1 != NEG_INF)
            dp2_nxt[0] = fmax2(dp2_nxt[0], base1 + val);
        end
        // two horizontals
        if (!pm[0] && !pm[1] && !pm[2]) begin
          val = h02_12(v0, v1, v2);
          if (base0 != NEG_INF)
            dp2_nxt[0] = fmax2(dp2_nxt[0], base0 + val);
        end
      end

      // Move next -> cur
      for (pm = 0; pm < 8; pm = pm + 1) begin
        dp0_cur[pm] = dp0_nxt[pm];
        dp1_cur[pm] = dp1_nxt[pm];
        dp2_cur[pm] = dp2_nxt[pm];
      end
    end
  endtask

  // FSM sequential
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= IDLE;
      done    <= 1'b0;
      max_sum <= 24'sd0;
      clear_cur_dp();
    end else begin
      state <= next_state;
    end
  end

  // FSM combinational next-state and DP control
  always @(*) begin
    next_state = state;
    done = 1'b0;
  end

  // DP and outputs controlled per-state on clock edges
  // Ensure total latency of 8 cycles: IDLE(wait) + CALC_ROW0 + CALC_ROW1 + CALC_ROW2 + CALC_ROW3 + DONE
  // Start triggers at IDLE; we perform one DP step per CALC_ROW* state.

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // already cleared in other block, but keep consistent
      max_sum <= 24'sd0;
      done    <= 1'b0;
      state   <= IDLE;
      clear_cur_dp();
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Initialize DP for before row0: only k=0, mask=0 is 0
            clear_cur_dp();
            dp0_cur[0] <= 24'sd0;
            // others already -INF
            next_state <= CALC_ROW0;
          end else begin
            next_state <= IDLE;
          end
        end

        CALC_ROW0: begin
          // process row0 values
          dp_step(r0c0, r0c1, r0c2);
          next_state <= CALC_ROW1;
        end

        CALC_ROW1: begin
          // process row1 values
          dp_step(r1c0, r1c1, r1c2);
          next_state <= CALC_ROW2;
        end

        CALC_ROW2: begin
          // process row2 values
          dp_step(r2c0, r2c1, r2c2);
          next_state <= CALC_ROW3;
        end

        CALC_ROW3: begin
          // last row: cannot start verticals
          dp_last_row(r3c0, r3c1, r3c2);

          // After final DP, compute result: k=2, mask=0
          max_sum <= dp2_cur[0];
          done    <= 1'b1;
          next_state <= DONE;
        end

        DONE: begin
          // Hold result and done until start deasserted and reasserted
          done <= 1'b1;
          if (!start)
            next_state <= IDLE;
        end

        default: begin
          next_state <= IDLE;
        end
      endcase
    end
  end

endmodule