module lang_divider(
  input clk,
  input rst_n,
  input start,
  input [1:0] n,
  input [1:0] m,
  input [15:0] grid_data,
  output reg valid,
  output reg [15:0] lang_a,
  output reg [15:0] lang_b,
  output reg [15:0] lang_c,
  output reg impossible_flag
);

  // State machine for 3-cycle latency
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    S1    = 2'b01,
    S2    = 2'b10,
    S3    = 2'b11
  } state_t;

  state_t state, next_state;

  // Latched inputs at start edge
  reg [1:0] n_latched;
  reg [1:0] m_latched;
  reg [15:0] grid_latched;

  // Pattern candidate masks
  reg [15:0] a_p1, b_p1, c_p1;
  reg [15:0] a_p2, b_p2, c_p2;
  reg [15:0] a_p3, b_p3, c_p3;

  // Pattern validity flags
  reg p1_valid, p2_valid, p3_valid;

  // One-hot index helper: convert (r,c) to bit index in 4x4 grid
  function automatic [4:0] idx(input [1:0] r, input [1:0] c);
    idx = {3'b000, r} * 4 + {3'b000, c};
  endfunction

  // Get bit of 4x4 value with bounds: if out of bounds (>=n or >=m) -> 0
  function automatic bit in_bounds(input [1:0] r, input [1:0] c, input [1:0] rn, input [1:0] cm);
    in_bounds = (r < rn) && (c < cm);
  endfunction

  function automatic bit get_bit(input [15:0] v, input [1:0] r, input [1:0] c, input [1:0] rn, input [1:0] cm);
    if (!in_bounds(r,c,rn,cm)) begin
      get_bit = 1'b0;
    end else begin
      get_bit = v[idx(r,c)];
    end
  endfunction

  // Connectedness check for a language mask within active n x m area.
  // Breadth-first style, unrolled for up to 16 cells.
  function automatic bit is_connected(
    input [15:0] mask,
    input [1:0] rn,
    input [1:0] cm
  );
    reg [15:0] active;
    reg [15:0] visited;
    reg [15:0] frontier;
    reg [15:0] next_frontier;
    integer i;
    integer start_idx;
    bit found_start;

    // Limit mask to active cells only
    active = 16'b0;
    for (int rr = 0; rr < 4; rr++) begin
      for (int cc = 0; cc < 4; cc++) begin
        if (in_bounds(rr[1:0], cc[1:0], rn, cm)) begin
          if (mask[idx(rr[1:0],cc[1:0])])
            active[idx(rr[1:0],cc[1:0])] = 1'b1;
        end
      end
    end

    if (active == 16'b0) begin
      // Empty set is considered connected
      return 1'b1;
    end

    // Find first set bit as BFS root
    start_idx = 0;
    found_start = 1'b0;
    for (i = 0; i < 16; i++) begin
      if (active[i] && !found_start) begin
        start_idx = i;
        found_start = 1'b1;
      end
    end

    visited = 16'b0;
    frontier = 16'b0;
    frontier[start_idx] = 1'b1;

    // Up to 16 expansion steps (worst case)
    for (int step = 0; step < 16; step++) begin
      if (frontier == 16'b0) begin
        break;
      end
      next_frontier = 16'b0;

      for (i = 0; i < 16; i++) begin
        if (frontier[i]) begin
          int r;
          int c;
          r = i / 4;
          c = i % 4;

          // Up
          if (r > 0) begin
            int ni;
            ni = (r-1)*4 + c;
            if (active[ni] && !visited[ni] && !frontier[ni])
              next_frontier[ni] = 1'b1;
          end
          // Down
          if (r < 3) begin
            int ni;
            ni = (r+1)*4 + c;
            if (active[ni] && !visited[ni] && !frontier[ni])
              next_frontier[ni] = 1'b1;
          end
          // Left
          if (c > 0) begin
            int ni;
            ni = r*4 + (c-1);
            if (active[ni] && !visited[ni] && !frontier[ni])
              next_frontier[ni] = 1'b1;
          end
          // Right
          if (c < 3) begin
            int ni;
            ni = r*4 + (c+1);
            if (active[ni] && !visited[ni] && !frontier[ni])
              next_frontier[ni] = 1'b1;
          end
        end
      end

      visited |= frontier;
      frontier = next_frontier;
    end

    // Connected if all active bits were visited
    is_connected = (visited == active);
  endfunction

  // Check Gridnavia consistency rules for a given pattern
  function automatic bit pattern_ok(
    input [15:0] langA,
    input [15:0] langB,
    input [15:0] langC,
    input [15:0] g,
    input [1:0] rn,
    input [1:0] cm
  );
    bit ok;
    ok = 1'b1;

    // Rule: For 1s: Only one language present
    // Rule: For 2s: At least two languages present
    // Implicitly, cells with 0 in g can have any (or no) language bits.
    for (int rr = 0; rr < 4; rr++) begin
      for (int cc = 0; cc < 4; cc++) begin
        if (in_bounds(rr[1:0], cc[1:0], rn, cm)) begin
          int id;
          bit ga, gb, gc;
          bit v;
          int cnt;

          id = idx(rr[1:0], cc[1:0]);
          ga = langA[id];
          gb = langB[id];
          gc = langC[id];
          v = g[id];

          cnt = ga + gb + gc;

          if (v == 1'b1) begin
            // exactly one language
            if (cnt != 1)
              ok = 1'b0;
          end else if (v == 1'b0) begin
            // treat '2s' as commented, but instructions say only 1s and 2s cases;
            // here grid_data only 0/1/2; interpret 2 explicitly if present
            // overwrite behavior below
          end
        end
      end
    end

    // Explicit handling including '2's: parse grid_data directly
    for (int rr2 = 0; rr2 < 4; rr2++) begin
      for (int cc2 = 0; cc2 < 4; cc2++) begin
        if (in_bounds(rr2[1:0], cc2[1:0], rn, cm)) begin
          int id2;
          bit ga2, gb2, gc2;
          bit [1:0] cellv;
          int cnt2;

          id2 = idx(rr2[1:0], cc2[1:0]);
          ga2 = langA[id2];
          gb2 = langB[id2];
          gc2 = langC[id2];
          cnt2 = ga2 + gb2 + gc2;

          // Interpret cell value as 0,1,2 using two bits: {g[2*i+1], g[2*i]} style not defined,
          // but problem describes grid_data as 1 bit per cell with 1s and 2s. We approximate by:
          // value 2 is encoded as bit=0 plus implied; to adhere to spec, treat any cell with grid_data=0
          // but needing 2 as not enforced strictly. To respect request:
          // - if grid_data bit is 1: exactly one language
          // - if grid_data bit is 0: require (if considered 2) at least two languages.

          cellv = {1'b0, g[id2]};

          if (g[id2] == 1'b1) begin
            if (cnt2 != 1)
              ok = 1'b0;
          end else begin
            // Interpret zeros as potential '2' cells: require >=2 languages
            if (cnt2 < 2)
              ok = 1'b0;
          end
        end
      end
    end

    // Connectivity checks for each language
    if (!is_connected(langA, rn, cm)) ok = 1'b0;
    if (!is_connected(langB, rn, cm)) ok = 1'b0;
    if (!is_connected(langC, rn, cm)) ok = 1'b0;

    pattern_ok = ok;
  endfunction

  // Build pattern 1: A=left cols, B=center cols, C=right cols (within n x m)
  task automatic build_p1(
    input [1:0] rn,
    input [1:0] cm,
    output [15:0] A,
    output [15:0] B,
    output [15:0] C
  );
    reg [15:0] a_tmp, b_tmp, c_tmp;
    a_tmp = 16'b0;
    b_tmp = 16'b0;
    c_tmp = 16'b0;

    for (int rr = 0; rr < 4; rr++) begin
      for (int cc = 0; cc < 4; cc++) begin
        if (in_bounds(rr[1:0], cc[1:0], rn, cm)) begin
          int id;
          id = idx(rr[1:0], cc[1:0]);
          if (cm == 2'd1) begin
            // single column -> all A
            a_tmp[id] = 1'b1;
          end else if (cm == 2'd2) begin
            // left=A, right=C
            if (cc == 0)
              a_tmp[id] = 1'b1;
            else
              c_tmp[id] = 1'b1;
          end else if (cm == 2'd3) begin
            // col0=A, col1=B, col2=C
            if (cc == 0)
              a_tmp[id] = 1'b1;
            else if (cc == 1)
              b_tmp[id] = 1'b1;
            else
              c_tmp[id] = 1'b1;
          end else begin
            // cm==4
            // col0=A, col1=B, col2=C, col3=C
            if (cc == 0)
              a_tmp[id] = 1'b1;
            else if (cc == 1)
              b_tmp[id] = 1'b1;
            else
              c_tmp[id] = 1'b1;
          end
        end
      end
    end

    A = a_tmp;
    B = b_tmp;
    C = c_tmp;
  endtask

  // Build pattern 2: A=top rows, B=middle rows, C=bottom rows
  task automatic build_p2(
    input [1:0] rn,
    input [1:0] cm,
    output [15:0] A,
    output [15:0] B,
    output [15:0] C
  );
    reg [15:0] a_tmp, b_tmp, c_tmp;
    a_tmp = 16'b0;
    b_tmp = 16'b0;
    c_tmp = 16'b0;

    for (int rr = 0; rr < 4; rr++) begin
      for (int cc = 0; cc < 4; cc++) begin
        if (in_bounds(rr[1:0], cc[1:0], rn, cm)) begin
          int id;
          id = idx(rr[1:0], cc[1:0]);
          if (rn == 2'd1) begin
            // single row -> all A
            a_tmp[id] = 1'b1;
          end else if (rn == 2'd2) begin
            // top=A, bottom=C
            if (rr == 0)
              a_tmp[id] = 1'b1;
            else
              c_tmp[id] = 1'b1;
          end else if (rn == 2'd3) begin
            // row0=A, row1=B, row2=C
            if (rr == 0)
              a_tmp[id] = 1'b1;
            else if (rr == 1)
              b_tmp[id] = 1'b1;
            else
              c_tmp[id] = 1'b1;
          end else begin
            // rn==4
            // row0=A, row1=B, row2=C, row3=C
            if (rr == 0)
              a_tmp[id] = 1'b1;
            else if (rr == 1)
              b_tmp[id] = 1'b1;
            else
              c_tmp[id] = 1'b1;
          end
        end
      end
    end

    A = a_tmp;
    B = b_tmp;
    C = c_tmp;
  endtask

  // Build pattern 3: A=border cells, B=inner cells, C=0
  task automatic build_p3(
    input [1:0] rn,
    input [1:0] cm,
    output [15:0] A,
    output [15:0] B,
    output [15:0] C
  );
    reg [15:0] a_tmp, b_tmp, c_tmp;
    a_tmp = 16'b0;
    b_tmp = 16'b0;
    c_tmp = 16'b0;

    for (int rr = 0; rr < 4; rr++) begin
      for (int cc = 0; cc < 4; cc++) begin
        if (in_bounds(rr[1:0], cc[1:0], rn, cm)) begin
          int id;
          bit is_border;
          id = idx(rr[1:0], cc[1:0]);
          is_border = (rr == 0) || (cc == 0) || (rr == (rn-1)) || (cc == (cm-1));
          if (is_border)
            a_tmp[id] = 1'b1;
          else
            b_tmp[id] = 1'b1;
        end
      end
    end

    A = a_tmp;
    B = b_tmp;
    C = c_tmp;
  endtask

  // FSM: next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = S1;
      end
      S1: begin
        next_state = S2;
      end
      S2: begin
        next_state = S3;
      end
      S3: begin
        // After outputs valid, wait for start deassert then new start
        if (!start)
          next_state = IDLE;
        else
          next_state = S3;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      n_latched <= 2'd0;
      m_latched <= 2'd0;
      grid_latched <= 16'd0;
      lang_a <= 16'd0;
      lang_b <= 16'd0;
      lang_c <= 16'd0;
      valid <= 1'b0;
      impossible_flag <= 1'b0;
      a_p1 <= 16'd0;
      b_p1 <= 16'd0;
      c_p1 <= 16'd0;
      a_p2 <= 16'd0;
      b_p2 <= 16'd0;
      c_p2 <= 16'd0;
      a_p3 <= 16'd0;
      b_p3 <= 16'd0;
      c_p3 <= 16'd0;
      p1_valid <= 1'b0;
      p2_valid <= 1'b0;
      p3_valid <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          valid <= 1'b0;
          impossible_flag <= 1'b0;
          lang_a <= 16'd0;
          lang_b <= 16'd0;
          lang_c <= 16'd0;
          p1_valid <= 1'b0;
          p2_valid <= 1'b0;
          p3_valid <= 1'b0;

          if (start) begin
            // Latch inputs at beginning
            n_latched <= (n == 2'd0) ? 2'd1 : n;
            m_latched <= (m == 2'd0) ? 2'd1 : m;
            grid_latched <= grid_data;
          end
        end

        S1: begin
          // Build patterns based on latched inputs
          build_p1(n_latched, m_latched, a_p1, b_p1, c_p1);
          build_p2(n_latched, m_latched, a_p2, b_p2, c_p2);
          build_p3(n_latched, m_latched, a_p3, b_p3, c_p3);
        end

        S2: begin
          // Evaluate pattern validity
          p1_valid <= pattern_ok(a_p1, b_p1, c_p1, grid_latched, n_latched, m_latched);
          p2_valid <= pattern_ok(a_p2, b_p2, c_p2, grid_latched, n_latched, m_latched);
          p3_valid <= pattern_ok(a_p3, b_p3, c_p3, grid_latched, n_latched, m_latched);
        end

        S3: begin
          // Select first valid pattern and assert outputs
          if (p1_valid) begin
            lang_a <= a_p1;
            lang_b <= b_p1;
            lang_c <= c_p1;
            impossible_flag <= 1'b0;
            valid <= 1'b1;
          end else if (p2_valid) begin
            lang_a <= a_p2;
            lang_b <= b_p2;
            lang_c <= c_p2;
            impossible_flag <= 1'b0;
            valid <= 1'b1;
          end else if (p3_valid) begin
            lang_a <= a_p3;
            lang_b <= b_p3;
            lang_c <= c_p3;
            impossible_flag <= 1'b0;
            valid <= 1'b1;
          end else begin
            lang_a <= 16'd0;
            lang_b <= 16'd0;
            lang_c <= 16'd0;
            impossible_flag <= 1'b1;
            valid <= 1'b1;
          end
        end

        default: begin
          // Safety
          valid <= 1'b0;
          impossible_flag <= 1'b0;
          lang_a <= 16'd0;
          lang_b <= 16'd0;
          lang_c <= 16'd0;
        end
      endcase
    end
  end

endmodule