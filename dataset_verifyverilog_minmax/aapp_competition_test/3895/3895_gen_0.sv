module function_decomposition(
  input clk,
  input rst_n,
  input start,
  input [2:0] f [0:7],
  output reg [2:0] m,
  output reg [2:0] g [0:7],
  output reg [2:0] h [0:7],
  output reg valid_out
);

  // 2 bits are enough to count 0..8
  typedef enum logic [1:0] {
    S_RST    = 2'd0,
    S_CHECK1 = 2'd1,
    S_CHECK2 = 2'd2,
    S_BUILD  = 2'd3
  } state_t;

  state_t state_q, state_d;
  reg [2:0] i_q, i_d;
  reg [2:0] h_local_q [0:7];
  reg [2:0] h_local_d [0:7];
  reg [3:0] m_cnt_q, m_cnt_d; // up to 8
  reg valid_q, valid_d;
  reg [2:0] j_q, j_d;
  reg [2:0] g_temp_q [0:7];
  reg [2:0] g_temp_d [0:7];

  integer k;

  // State & pipeline registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q <= S_RST;
      i_q <= 3'd0;
      m_cnt_q <= 4'd0;
      valid_q <= 1'b0;
      j_q <= 3'd0;
      for (k = 0; k < 8; k++) begin
        h_local_q[k] <= 3'd0;
        g_temp_q[k] <= 3'd0;
      end
    end else begin
      state_q <= state_d;
      i_q <= i_d;
      m_cnt_q <= m_cnt_d;
      valid_q <= valid_d;
      j_q <= j_d;
      for (k = 0; k < 8; k++) begin
        h_local_q[k] <= h_local_d[k];
        g_temp_q[k] <= g_temp_d[k];
      end
    end
  end

  // FSM + datapath
  always @* begin
    // defaults
    state_d = state_q;
    i_d = i_q;
    m_cnt_d = m_cnt_q;
    valid_d = valid_q;
    j_d = j_q;
    for (k = 0; k < 8; k++) begin
      h_local_d[k] = h_local_q[k];
      g_temp_d[k] = g_temp_q[k];
    end

    // outputs default: hold current values (registered)
    m = m_cnt_q[2:0];
    for (k = 0; k < 8; k++) begin
      g[k] = g_temp_q[k];
      h[k] = h_local_q[k];
    end
    valid_out = valid_q;

    case (state_q)
      S_RST: begin
        // reset internal and outputs
        m_cnt_d = 4'd0;
        valid_d = 1'b0;
        i_d = 3'd0;
        j_d = 3'd0;
        for (k = 0; k < 8; k++) begin
          h_local_d[k] = 3'd0;
          g_temp_d[k] = 3'd0;
        end
        m = 3'd0;
        for (k = 0; k < 8; k++) begin
          g[k] = 3'd0;
          h[k] = 3'd0;
        end
        valid_out = 1'b0;

        if (start) begin
          state_d = S_CHECK1;
          i_d = 3'd0;
        end
      end

      S_CHECK1: begin
        // Check: f[f[i]] == f[i] (property 1) AND f[i] is a fixed point (property 2)
        if (f[f[i]][2:0] == f[i][2:0] && f[i][2:0] == i[2:0]) begin
          i_d = i_q + 1;
          if (i_q == 3'd7) begin
            // all passed: collect fixed points into h_local
            m_cnt_d = 4'd0;
            for (k = 0; k < 8; k++) h_local_d[k] = 3'd0;
            for (k = 0; k < 8; k++) begin
              if (f[k][2:0] == k[2:0]) begin
                h_local_d[m_cnt_d[2:0]] = k[2:0];
                m_cnt_d = m_cnt_d + 1;
              end
            end
            // Compute m (1..8) and keep g_temp in this stage if we want 1 extra cycle.
            // Per spec, do g in next stage (S_BUILD) for 5-cycle total.
            state_d = S_CHECK2;
            valid_d = 1'b1; // provisional; will be validated in CHECK2
          end
        end else begin
          // Immediate fail
          state_d = S_CHECK2;
          valid_d = 1'b0;
        end
      end

      S_CHECK2: begin
        // Final domain check: every f[i] must be one of the fixed points (i.e., in h_local)
        valid_d = 1'b0;
        for (k = 0; k < m_cnt_q; k++) begin
          if (h_local_q[k] == f[i_q][2:0]) begin
            valid_d = 1'b1;
            break;
          end
        end
        j_d = 3'd0; // prepare for g construction
        state_d = S_BUILD;
      end

      S_BUILD: begin
        if (valid_q) begin
          // Construct g[j] = index of f[j] in h + 1 (1-based)
          for (j_d = 0; j_d < 3'd8; j_d++) begin
            // no else to keep inferred latches from case
          end
        end
        // Perform a single g[j_q] construction this cycle
        for (k = 0; k < 8; k++) g_temp_d[k] = g_temp_q[k]; // default hold
        for (k = 0; k < m_cnt_q; k++) begin
          if (h_local_q[k] == f[j_q][2:0]) begin
            g_temp_d[j_q] = k[2:0] + 3'd1; // 1-based
          end
        end
        if (j_q == 3'd7) begin
          // finished
          state_d = S_RST; // next start will restart; outputs remain valid
        end else begin
          j_d = j_q + 1;
        end
      end

      default: begin
        state_d = S_RST;
      end
    endcase
  end
endmodule
