module min_clique_steps(
  input  wire        clk,
  input  wire        rst_n,
  input  reg         start,
  input  reg  [2:0]  n,
  input  reg  [4:0]  m,
  input  reg  [2:0]  u_in,
  input  reg  [2:0]  v_in,
  input  reg         edge_valid,
  output reg  [3:0]  step_count,
  output reg  [2:0]  guest_steps [0:7],
  output reg         done
);

  // Parameters
  localparam MAXN        = 8;
  localparam MAX_MASK    = 1 << MAXN; // 256
  localparam INF         = 4'd15;     // larger than max steps (8)

  // FSM states
  typedef enum logic [2:0] {
    S_IDLE       = 3'd0,
    S_LOAD       = 3'd1,
    S_INIT_DP    = 3'd2,
    S_DP         = 3'd3,
    S_RECON      = 3'd4,
    S_DONE       = 3'd5
  } state_t;

  state_t state, next_state;

  // Registers
  reg [2:0]   n_reg;
  reg [4:0]   m_reg;

  reg [7:0]   adj [0:7];     // adjacency bitmasks: adj[i][j]=1 if edge i-j

  // DP arrays
  reg  [3:0]  dp      [0:MAX_MASK-1];  // minimal steps for mask
  reg  [7:0]  prev_m  [0:MAX_MASK-1];  // previous mask in optimal path
  reg  [2:0]  prev_g  [0:MAX_MASK-1];  // guest chosen to reach this mask

  // control counters
  reg [4:0]   edge_cnt;      // up to 28
  reg [7:0]   init_idx;      // 0..255
  reg [7:0]   dp_mask;       // current mask in DP sweep
  reg [2:0]   dp_guest;      // current guest index in DP
  reg [7:0]   full_mask;     // (1<<n_reg)-1

  // reconstruction
  reg [7:0]   cur_mask;
  reg [2:0]   recon_idx;     // index into guest_steps

  // internal wires/regs
  reg [7:0]   mask_next;
  reg [3:0]   new_cost;

  // compute full_mask combinationally based on n_reg
  always @(*) begin
    if (n_reg == 0)
      full_mask = 8'b0000_0000;
    else
      full_mask = (8'b0000_0001 << n_reg) - 1'b1;
  end

  // FSM: state register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
    end else begin
      state <= next_state;
    end
  end

  // FSM: next state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_LOAD;
      end
      S_LOAD: begin
        // wait until m edges received
        if (edge_cnt == m_reg && m_reg != 0)
          next_state = S_INIT_DP;
        else if (m_reg == 0 && edge_cnt == 0)
          next_state = S_INIT_DP;
      end
      S_INIT_DP: begin
        if (init_idx == (MAX_MASK-1))
          next_state = S_DP;
      end
      S_DP: begin
        // dp_mask sweeps all masks; when done, go reconstruct
        if (dp_mask == full_mask && dp_guest == (n_reg-1))
          next_state = S_RECON;
      end
      S_RECON: begin
        // reconstruct until mask 0 or all steps filled
        if (cur_mask == 0 || recon_idx == 3'd7)
          next_state = S_DONE;
      end
      S_DONE: begin
        // stay done until next start
        if (start)
          next_state = S_LOAD;
      end
      default: next_state = S_IDLE;
    endcase
  end

  integer i;

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // reset
      n_reg      <= 3'd0;
      m_reg      <= 5'd0;
      edge_cnt   <= 5'd0;
      init_idx   <= 8'd0;
      dp_mask    <= 8'd0;
      dp_guest   <= 3'd0;
      cur_mask   <= 8'd0;
      recon_idx  <= 3'd0;
      step_count <= 4'd0;
      done       <= 1'b0;
      for (i = 0; i < 8; i = i + 1) begin
        adj[i] <= 8'd0;
        guest_steps[i] <= 3'd0;
      end
      for (i = 0; i < MAX_MASK; i = i + 1) begin
        dp[i]     <= INF;
        prev_m[i] <= 8'd0;
        prev_g[i] <= 3'd0;
      end
    end else begin
      case (state)
        S_IDLE: begin
          done <= 1'b0;
          step_count <= 4'd0;
          if (start) begin
            // latch n,m
            n_reg    <= n;
            m_reg    <= m;
            edge_cnt <= 5'd0;
            // clear adjacency
            for (i = 0; i < 8; i = i + 1) begin
              adj[i] <= 8'd0;
            end
          end
        end

        S_LOAD: begin
          done <= 1'b0;
          // capture edges when valid until m_reg edges
          if (edge_valid && edge_cnt < m_reg) begin
            edge_cnt <= edge_cnt + 1'b1;
            if (u_in < MAXN && v_in < MAXN && u_in != v_in) begin
              adj[u_in][v_in] <= 1'b1;
              adj[v_in][u_in] <= 1'b1;
            end
          end
          // if m_reg==0, no edges to read; state machine will move by next_state
          if (state != next_state) begin
            // prepare for init
            init_idx <= 8'd0;
          end
        end

        S_INIT_DP: begin
          done <= 1'b0;
          // initialize dp table over multiple cycles
          dp[init_idx]     <= INF;
          prev_m[init_idx] <= 8'd0;
          prev_g[init_idx] <= 3'd0;
          if (init_idx == (MAX_MASK-1)) begin
            // set base states when finishing init
            // base: empty mask has 0 steps
            dp[0] <= 4'd0;
            // also singletons reachable in 1 step (optional); here rely on DP from 0
            dp_mask   <= 8'd0;
            dp_guest  <= 3'd0;
          end
          if (init_idx != (MAX_MASK-1))
            init_idx <= init_idx + 1'b1;
        end

        S_DP: begin
          done <= 1'b0;

          // Only consider masks within current n_reg (ignore higher bits)
          if (dp_mask < (1 << n_reg)) begin
            if (dp[dp_mask] != INF) begin
              // try adding each guest g not in mask
              if (dp_guest < n_reg) begin
                if (!dp_mask[dp_guest]) begin
                  // construct new mask by adding guest and all its friends in current mask
                  mask_next = dp_mask;
                  // add chosen guest
                  mask_next[dp_guest] = 1'b1;
                  // add friends of chosen guest that are already in mask or create connections
                  // Here we simply close under adjacency between new guest and existing members
                  for (i = 0; i < n_reg; i = i + 1) begin
                    if (adj[dp_guest][i]) begin
                      mask_next[i] = 1'b1;
                    end
                  end
                  new_cost = dp[dp_mask] + 1'b1;
                  if (new_cost < dp[mask_next]) begin
                    dp[mask_next]     <= new_cost;
                    prev_m[mask_next] <= dp_mask;
                    prev_g[mask_next] <= dp_guest;
                  end
                end
              end
            end
          end

          // advance guest index / mask
          if (dp_guest < (n_reg-1)) begin
            dp_guest <= dp_guest + 1'b1;
          end else begin
            dp_guest <= 3'd0;
            if (dp_mask < (MAX_MASK-1)) begin
              dp_mask <= dp_mask + 1'b1;
            end
          end

          // when finishing target full_mask range, prepare recon
          if (state != next_state) begin
            cur_mask  <= full_mask;
            recon_idx <= 3'd0;
            step_count <= (dp[full_mask] == INF) ? 4'd0 : dp[full_mask];
            // clear guest_steps
            for (i = 0; i < 8; i = i + 1) begin
              guest_steps[i] <= 3'd0;
            end
          end
        end

        S_RECON: begin
          done <= 1'b0;
          // reconstruct path from full_mask back to 0 using prev_m/prev_g
          if (cur_mask != 0 && recon_idx < 8 && dp[cur_mask] != INF) begin
            guest_steps[recon_idx] <= prev_g[cur_mask];
            cur_mask               <= prev_m[cur_mask];
            recon_idx              <= recon_idx + 1'b1;
          end
        end

        S_DONE: begin
          done <= 1'b1;
          // hold results; allow restart on new start pulse
          if (start) begin
            done       <= 1'b0;
            step_count <= 4'd0;
            edge_cnt   <= 5'd0;
            init_idx   <= 8'd0;
            dp_mask    <= 8'd0;
            dp_guest   <= 3'd0;
            cur_mask   <= 8'd0;
            recon_idx  <= 3'd0;
            // clear adjacency for new run
            for (i = 0; i < 8; i = i + 1) begin
              adj[i] <= 8'd0;
            end
          end
        end

        default: begin
        end
      endcase
    end
  end

endmodule