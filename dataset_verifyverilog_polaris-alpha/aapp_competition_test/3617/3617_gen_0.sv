module pikeman(
  input clk, // clock
  input rst_n, // active-low reset
  input start, // start computation (pulse)
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

  // State encoding
  localparam IDLE       = 3'd0;
  localparam GENERATE   = 3'd1;
  localparam SORT       = 3'd2;
  localparam ACCUMULATE = 3'd3;
  localparam DONE       = 3'd4;

  reg [2:0] state, next_state;

  // Internal registers
  reg [6:0] t_arr [0:7];       // time array
  reg [3:0] gen_idx;           // generation index
  reg [3:0] sort_i;            // bubble sort pass counter
  reg [2:0] sort_j;            // bubble sort index within pass
  reg [6:0] prev_t;            // previous t for generator

  reg [15:0] T_latched;
  reg [3:0]  N_latched;
  reg [6:0]  A_latched, B_latched, C_latched;

  reg [15:0] acc_time;         // accumulated time
  reg [29:0] penalty_reg;      // internal penalty
  reg [3:0]  solved_cnt;       // internal solved counter

  // Constant MOD = 1000000007 (fits in 30 bits as given requirement comment)
  localparam [29:0] MOD = 30'd1000000007;

  integer k;

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = GENERATE;
      end
      GENERATE: begin
        if ((N_latched == 0) || (gen_idx == (N_latched - 1)))
          next_state = SORT;
      end
      SORT: begin
        // 7-stage bubble sort for up to 8 elements
        if (sort_i == 4'd7)
          next_state = ACCUMULATE;
      end
      ACCUMULATE: begin
        next_state = DONE;
      end
      DONE: begin
        if (!start)
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= IDLE;
      done          <= 1'b0;
      num_problems  <= 4'd0;
      penalty       <= 30'd0;
      gen_idx       <= 4'd0;
      sort_i        <= 4'd0;
      sort_j        <= 3'd0;
      acc_time      <= 16'd0;
      penalty_reg   <= 30'd0;
      solved_cnt    <= 4'd0;
      T_latched     <= 16'd0;
      N_latched     <= 4'd0;
      A_latched     <= 7'd0;
      B_latched     <= 7'd0;
      C_latched     <= 7'd1;
      prev_t        <= 7'd0;
      for (k = 0; k < 8; k = k + 1) begin
        t_arr[k] <= 7'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done         <= 1'b0;
          num_problems <= 4'd0;
          penalty      <= 30'd0;
          penalty_reg  <= 30'd0;
          solved_cnt   <= 4'd0;
          acc_time     <= 16'd0;
          sort_i       <= 4'd0;
          sort_j       <= 3'd0;

          if (start) begin
            // Latch inputs
            T_latched <= T;
            N_latched <= (N > 4'd8) ? 4'd8 : N; // cap N to 8
            A_latched <= A;
            B_latched <= B;
            // Ensure C_latched is non-zero to avoid modulo-by-zero
            C_latched <= (C == 7'd0) ? 7'd1 : C;

            // Initialize generator
            prev_t    <= t0;
            // Initialize first element if N_latched != 0 (handled in GENERATE)
            for (k = 0; k < 8; k = k + 1) begin
              t_arr[k] <= 7'd0;
            end
            gen_idx <= 4'd0;
          end
        end

        GENERATE: begin
          if (N_latched == 0) begin
            // Nothing to generate
          end else begin
            if (gen_idx == 4'd0) begin
              // First element directly from prev_t
              t_arr[0] <= prev_t;
              if (N_latched > 1) begin
                // Prepare for next index
                // Compute next t
                // (A*prev_t + B) % C + 1
                // Use extended width for multiplication
                reg [13:0] mult;
                reg [13:0] tmp;
                mult = A_latched * prev_t;
                tmp  = mult + B_latched;
                if (C_latched != 0)
                  tmp = tmp % C_latched;
                prev_t <= tmp[6:0] + 7'd1;
                gen_idx <= 4'd1;
              end
            end else if (gen_idx < N_latched) begin
              // Store current prev_t at gen_idx
              t_arr[gen_idx] <= prev_t;
              if (gen_idx < (N_latched - 1)) begin
                // Compute next prev_t for following cycle
                reg [13:0] mult2;
                reg [13:0] tmp2;
                mult2 = A_latched * prev_t;
                tmp2  = mult2 + B_latched;
                if (C_latched != 0)
                  tmp2 = tmp2 % C_latched;
                prev_t <= tmp2[6:0] + 7'd1;
                gen_idx <= gen_idx + 1'b1;
              end
            end
          end
        end

        SORT: begin
          // Bubble sort across multiple cycles
          if (N_latched <= 1) begin
            // Nothing to sort
            sort_i <= 4'd7; // force transition to ACCUMULATE
          end else begin
            if (sort_i < 4'd7) begin
              // Perform one compare-swap per cycle
              if (sort_j < (N_latched - 1)) begin
                if (t_arr[sort_j] > t_arr[sort_j + 1]) begin
                  reg [6:0] tmp_swap;
                  tmp_swap               = t_arr[sort_j];
                  t_arr[sort_j]          <= t_arr[sort_j + 1];
                  t_arr[sort_j + 1]      <= tmp_swap;
                end
                sort_j <= sort_j + 1'b1;
              end else begin
                // End of pass, start next pass
                sort_j <= 3'd0;
                sort_i <= sort_i + 1'b1;
              end
            end
          end
        end

        ACCUMULATE: begin
          // Single-pass accumulate over sorted times
          acc_time     <= 16'd0;
          penalty_reg  <= 30'd0;
          solved_cnt   <= 4'd0;

          if (N_latched != 0) begin
            integer i;
            reg [15:0] cur_acc;
            reg [29:0] cur_pen;
            reg [3:0]  cur_cnt;

            cur_acc = 16'd0;
            cur_pen = 30'd0;
            cur_cnt = 4'd0;

            for (i = 0; i < 8; i = i + 1) begin
              if (i < N_latched) begin
                if (cur_acc + t_arr[i] <= T_latched) begin
                  cur_acc = cur_acc + t_arr[i];
                  cur_cnt = cur_cnt + 1'b1;
                  cur_pen = cur_pen + cur_acc;
                  if (cur_pen >= MOD)
                    cur_pen = cur_pen - MOD;
                end
              end
            end

            acc_time    <= cur_acc;
            penalty_reg <= cur_pen;
            solved_cnt  <= cur_cnt;
          end
        end

        DONE: begin
          done         <= 1'b1;
          num_problems <= solved_cnt;
          penalty      <= penalty_reg;
          // Hold results until next start deasserted then asserted (handled by FSM)
        end

        default: begin
          // Should not occur; safe defaults
          done         <= 1'b0;
          num_problems <= 4'd0;
          penalty      <= 30'd0;
        end
      endcase
    end
  end

endmodule