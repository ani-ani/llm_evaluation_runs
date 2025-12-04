module pikeman(
  input clk, // clock
  input rst_n, // active-low reset
  input start, // start computation
  input [3:0] N, // number of problems (max 8)
  input [15:0] T, // total contest time (max 65535)
  input [6:0] A, // generator param (max 127)
  input [6:0] B, // generator param (max 127)
  input [6:0] C, // generator param (max 127, C >= t0)
  input [6:0] t0, // initial time (max 127)
  output reg [3:0] num_problems, // solved count (0-8)
  output reg [29:0] penalty, // penalty mod 1000000007
  output reg done // high when computation complete
);

  // Constants
  localparam ST_IDLE       = 3'd0;
  localparam ST_GENERATE   = 3'd1;
  localparam ST_SORT       = 3'd2;
  localparam ST_ACCUMULATE = 3'd3;
  localparam ST_DONE       = 3'd4;
  localparam MAX_PBITS     = 7;     // max 7-bit times (1..127)
  localparam MAX_ELEMS     = 8;
  localparam MOD_VAL       = 30'd1000000007;

  // State and control
  reg [2:0] state, state_next;
  reg [3:0] g_cnt;     // generation counter (0..N)
  reg [3:0] s_i;       // bubble sort stage (0..6)
  reg [2:0] s_j;       // inner index (0..6)
  reg [2:0] s_j_max;
  reg [3:0] a_i;       // accumulation index (0..N-1)
  reg [15:0] a_sum;    // accumulated time for solve decision
  reg [29:0] a_pen;    // accumulated penalty (mod MOD_VAL)
  reg swap_flag;

  // Storage
  reg [MAX_PBITS-1:0] t [0:MAX_ELEMS-1];   // 7-bit times
  reg [15:0] T_reg;
  reg [3:0] N_reg;
  reg [6:0] A_reg, B_reg, C_reg, t0_reg;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= ST_IDLE;
    else        state <= state_next;
  end

  // Combinational next state and control
  always @(*) begin
    state_next = state;
    done = 1'b0;

    // Defaults for control signals
    g_cnt   = 4'd0;
    s_i     = 4'd0;
    s_j     = 3'd0;
    s_j_max = 3'd0;
    a_i     = 4'd0;
    a_sum   = 16'd0;
    a_pen   = 30'd0;
    swap_flag = 1'b0;

    // Per-state actions
    case (state)
      ST_IDLE: begin
        if (start) begin
          // Latch inputs
          T_reg   = T;
          N_reg   = N;
          A_reg   = A;
          B_reg   = B;
          C_reg   = C;
          t0_reg  = t0;

          // Init storage and counters
          t[0] = 7'd0; t[1] = 7'd0; t[2] = 7'd0; t[3] = 7'd0;
          t[4] = 7'd0; t[5] = 7'd0; t[6] = 7'd0; t[7] = 7'd0;
          g_cnt = 4'd0;
          s_i   = 4'd0;
          s_j   = 3'd0;
          a_i   = 4'd0;
          a_sum = 16'd0;
          a_pen = 30'd0;
          swap_flag = 1'b0;
          state_next = ST_GENERATE;
        end else begin
          state_next = ST_IDLE;
        end
      end

      ST_GENERATE: begin
        g_cnt   = g_cnt;   // hold
        s_i     = 4'd0;    // reset sort counters
        s_j     = 3'd0;
        a_i     = 4'd0;
        a_sum   = 16'd0;
        a_pen   = 30'd0;

        if (g_cnt < N_reg) begin
          if (g_cnt == 4'd0) begin
            t[0] = t0_reg;
          end else begin
            t[g_cnt] = ((A_reg * t[g_cnt-1] + B_reg) % C_reg) + 1;
          end
          g_cnt = g_cnt + 1;
          state_next = ST_GENERATE;
        end else begin
          // Prepare for sort
          s_i = 4'd0;
          s_j = 3'd0;
          s_j_max = (N_reg > 1) ? (N_reg - 2) : 3'd0;
          state_next = ST_SORT;
        end
      end

      ST_SORT: begin
        // Bubble sort pass in one cycle per compare
        if (s_i < (N_reg - 1)) begin
          if (s_j <= s_j_max) begin
            if (t[s_j] > t[s_j+1]) begin
              begin : swap_logic
                reg [MAX_PBITS-1:0] tmp;
                tmp        = t[s_j];
                t[s_j]     = t[s_j+1];
                t[s_j+1]   = tmp;
              end
              swap_flag = 1'b1;
            end
            s_j = s_j + 1;
          end else begin
            s_j = 3'd0;
            s_i = s_i + 1;
            s_j_max = (N_reg > (s_i + 2)) ? (N_reg - s_i - 2) : 3'd0;
          end
          state_next = ST_SORT;
        end else begin
          state_next = ST_ACCUMULATE;
        end
      end

      ST_ACCUMULATE: begin
        if (a_i < N_reg) begin
          if ((a_sum + t[a_i]) <= T_reg) begin
            a_sum = a_sum + t[a_i];
            a_pen = a_pen + t[a_i];
            a_i   = a_i + 1;
            state_next = ST_ACCUMULATE;
          end else begin
            // Can't add t[a_i] without exceeding T
            a_i   = a_i;
            a_sum = a_sum;
            a_pen = a_pen;
            state_next = ST_DONE;
          end
        end else begin
          // Processed all problems
          a_i   = a_i;
          a_sum = a_sum;
          a_pen = a_pen;
          state_next = ST_DONE;
        end
      end

      ST_DONE: begin
        done = 1'b1;
        state_next = ST_IDLE;
      end

      default: begin
        state_next = ST_IDLE;
      end
    endcase
  end

  // Output assignment (registered in FF to avoid glitches)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      num_problems <= 4'd0;
      penalty      <= 30'd0;
      done         <= 1'b0;
    end else begin
      if (state == ST_DONE) begin
        // Valid outputs
        num_problems <= a_i;
        penalty      <= a_pen % MOD_VAL;
        done         <= 1'b1;
      end else if (state == ST_IDLE) begin
        num_problems <= 4'd0;
        penalty      <= 30'd0;
        done         <= 1'b0;
      end
      // In other states, retain previous (optional) or force 0; choose retain:
      // Keep prior values by not assigning in other states.
    end
  end

endmodule
