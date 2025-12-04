module rectangle_extensions (
  input clk,                    // clock
  input rst_n,                  // active-low reset
  input start,                  // pulse high to start computation
  input [31:0] a, b, h, w,      // target rectangle and initial field sizes
  input [15:0][31:0] factors,   // 16 extension factors (max problem size)
  input [4:0] num_factors,      // actual number of factors (1-16)
  output reg [4:0] min_count,   // minimal extensions needed (0-16 or 31 for -1)
  output reg done               // high when computation completes
);

  localparam MAXN = 16;
  localparam NEG_ONE = 5'd31;    // sentinel for -1

  // FSM states
  typedef enum logic [2:0] { IDLE = 3'b000, SORT = 3'b001, PROCESS = 3'b010, CHECK = 3'b011, DONE = 3'b100 } state_t;
  state_t state, next_state;

  // Factor storage (descending)
  reg [31:0] f_sorted [0:MAXN-1];
  reg [4:0]  fcnt;               // convenience alias for num_factors

  // Current and next frontier of dimension pairs
  reg [31:0] cur_h [0:MAXN-1];
  reg [31:0] cur_w [0:MAXN-1];
  reg [MAXN-1:0] cur_valid;      // 1 = entry is active
  reg [31:0] nxt_h [0:MAXN-1];
  reg [31:0] nxt_w [0:MAXN-1];
  reg [MAXN-1:0] nxt_valid;

  // Extension counter and indices
  reg [4:0] ext_count;           // number of extensions applied (1..num_factors)
  reg [4:0] i_idx, j_idx, n_idx;

  // Sorting pipeline state
  reg sort_active;
  reg [4:0] sort_step;  // 0..15, controls inner compare/swap

  // Initialization of arrays at reset
  integer k;
  initial begin
    for (k = 0; k < MAXN; k = k + 1) begin
      cur_h[k] = 0; cur_w[k] = 0;
      nxt_h[k] = 0; nxt_w[k] = 0;
    end
  end

  // Sequential FSM and datapath
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      done        <= 1'b0;
      min_count   <= 5'd0;
      fcnt        <= 5'd0;
      ext_count   <= 5'd0;
      i_idx       <= 5'd0;
      j_idx       <= 5'd0;
      n_idx       <= 5'd0;
      sort_active <= 1'b0;
      sort_step   <= 5'd0;
      for (k = 0; k < MAXN; k = k + 1) begin
        cur_h[k]    <= 32'd0;
        cur_w[k]    <= 32'd0;
        nxt_h[k]    <= 32'd0;
        nxt_w[k]    <= 32'd0;
        f_sorted[k] <= 32'd0;
      end
      cur_valid <= 1'b0;
      nxt_valid <= 1'b0;
    end else begin
      // Defaults (in case we stay in state)
      i_idx       <= 5'd0;
      j_idx       <= 5'd0;
      n_idx       <= 5'd0;
      sort_active <= 1'b0;
      sort_step   <= 5'd0;
      fcnt        <= num_factors;
      done        <= 1'b0;   // will be overridden in DONE
      // State machine and datapath
      case (state)
        IDLE: begin
          if (start) begin
            // Prime initial frontier with (h,w) and (w,h)
            cur_h[0] <= h;
            cur_w[0] <= w;
            cur_h[1] <= w;
            cur_w[1] <= h;
            cur_valid <= 2'b11;
            // Clear the rest
            for (k = 2; k < MAXN; k = k + 1) begin
              cur_h[k] <= 32'd0;
              cur_w[k] <= 32'd0;
            end
            // Initialize sorting
            for (k = 0; k < MAXN; k = k + 1) begin
              if (k < num_factors) begin
                f_sorted[k] <= factors[k];
              end else begin
                f_sorted[k] <= 32'd0;
              end
            end
            state        <= SORT;
            sort_active  <= 1'b1;
            sort_step    <= 5'd0;
            ext_count    <= 5'd0;
            fcnt         <= num_factors;
            done         <= 1'b0;
            min_count    <= 5'd0;
          end else begin
            state <= IDLE;
          end
        end

        SORT: begin
          // Bubble sort inner step for descending order
          if (num_factors > 1) begin
            if (sort_step < (num_factors - 1)) begin
              if (f_sorted[sort_step] < f_sorted[sort_step + 1]) begin
                // Swap to maintain descending order
                f_sorted[sort_step]   <= f_sorted[sort_step + 1];
                f_sorted[sort_step+1] <= f_sorted[sort_step];
              end
              sort_step <= sort_step + 1;
              state     <= SORT;
            end else begin
              // This pass finished, go to next pass if not at end
              if (sort_step < num_factors - 1) begin
                sort_step <= 5'd0;
                state     <= SORT;
              end else begin
                state <= PROCESS;
                i_idx <= 5'd0;
                n_idx <= 5'd0;
              end
            end
          end else begin
            // Nothing to sort for 0 or 1 factor
            state <= PROCESS;
            i_idx <= 5'd0;
            n_idx <= 5'd0;
          end
        end

        PROCESS: begin
          // If no more factors to apply, go to final check
          if (ext_count >= fcnt) begin
            state <= CHECK;
          end else begin
            // Reset next frontier
            n_idx <= 5'd0;
            for (k = 0; k < MAXN; k = k + 1) begin
              nxt_h[k]    <= 32'd0;
              nxt_w[k]    <= 32'd0;
              nxt_valid[k]<= 1'b0;
            end
            // Loop over all current valid configurations
            for (k = 0; k < MAXN; k = k + 1) begin
              if (cur_valid[k] && n_idx < MAXN) begin
                // Apply factor to height and width
                // Height-first
                nxt_h[n_idx]   <= cur_h[k] * f_sorted[ext_count];
                nxt_w[n_idx]   <= cur_w[k] * f_sorted[ext_count];
                nxt_valid[n_idx] <= 1'b1;
                n_idx <= n_idx + 1;

                // Width-first (if new entry available)
                if ((n_idx + 1) < MAXN) begin
                  nxt_h[n_idx]   <= cur_h[k] * f_sorted[ext_count];
                  nxt_w[n_idx]   <= cur_w[k] * f_sorted[ext_count];
                  nxt_valid[n_idx] <= 1'b1;
                  n_idx <= n_idx + 1;
                end
              end
            end
            // Prepare for CHECK
            state <= CHECK;
            j_idx <= 5'd0;
          end
        end

        CHECK: begin
          // Scan current frontier for any (h,w) satisfying (h>=a && w>=b) || (h>=b && w>=a)
          if (j_idx < MAXN && cur_valid[j_idx]) begin
            if ((cur_h[j_idx] >= a && cur_w[j_idx] >= b) ||
                (cur_h[j_idx] >= b && cur_w[j_idx] >= a)) begin
              min_count <= ext_count;  // solution found at current extension count
              done      <= 1'b1;
              state     <= DONE;
            end else begin
              j_idx <= j_idx + 1;
            end
          end else begin
            // No solution in current frontier; determine if we have factors left
            if (ext_count < fcnt) begin
              // Move next frontier to current and continue to PROCESS
              for (k = 0; k < MAXN; k = k + 1) begin
                cur_h[k]    <= nxt_h[k];
                cur_w[k]    <= nxt_w[k];
                cur_valid[k]<= nxt_valid[k];
              end
              ext_count <= ext_count + 1;
              i_idx     <= 5'd0;
              n_idx     <= 5'd0;
              state     <= PROCESS;
            end else begin
              // All factors applied; no solution
              min_count <= NEG_ONE;
              done      <= 1'b1;
              state     <= DONE;
            end
          end
        end

        DONE: begin
          // Hold outputs until next start; deassert done when start returns
          done <= 1'b0;
          if (!start) begin
            state <= IDLE;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

  // Optional combinatorial next-state logic (kept simple; sequential path is explicit above)
  always_comb begin
    next_state = state;
    // This block intentionally left minimal; transitions handled in sequential always_ff
  end

endmodule
