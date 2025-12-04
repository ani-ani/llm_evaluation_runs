module train_refund_eligibility(
  input clk,  // clock signal
  input rst_n,  // active-low reset
  input start,  // start computation
  input [1:0] num_stations,  // N (2-4 stations)
  input [1:0] num_trains,  // M (1-4 trains)
  input [1:0] train_station [3:0],  // [M-1:0] X (starting station)
  input [16:0] train_depart [3:0],  // [M-1:0] S (planned departure)
  input [16:0] train_arrive [3:0],  // [M-1:0] T (planned arrival)
  input [16:0] train_delay [3:0],  // [M-1:0] L (delay duration)
  output reg [16:0] result,  // earliest valid start time (131071=impossible)
  output reg done  // high when computation complete
);

  // Local parameters
  localparam IMPOSSIBLE = 17'd131071;
  localparam THRESH = 17'd1800;

  // State machine
  typedef enum logic [2:0] {IDLE=3'b000, LOAD=3'b001, PROCESS=3'b010, CHECK=3'b011, DONE=3'b100} state_t;
  state_t state, next_state;

  // Latched inputs
  reg [1:0] l_num_stations;
  reg [1:0] l_num_trains;
  reg [1:0] l_train_station [3:0];
  reg [16:0] l_train_depart [3:0];
  reg [16:0] l_train_arrive [3:0];
  reg [16:0] l_train_delay [3:0];

  // FSM datapath
  reg [16:0] cand_s;           // candidate S under test
  reg [16:0] best_s;           // earliest eligible S found
  reg found_any;               // whether any eligible S exists

  // Combinatorial path enumeration helpers
  reg [16:0] bin_left;         // start index for current step enumeration
  reg [16:0] bin_right;        // end index (inclusive) for current step enumeration
  reg [16:0] cur_path;         // linear index being checked this cycle
  reg       cur_path_valid;
  reg [16:0] cur_delay;        // accumulated delay for current path at current step
  reg [16:0] min_delay;        // min delay among all valid paths for current S
  reg       has_any_path;      // whether any path was found for current S

  // Cycle counter to meet (8 + 2*M) cycles latency when done=1
  reg [4:0] cycle;             // up to 16 cycles safe for M<=4

  // State register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else        state <= next_state;
  end

  // Next-state and datapath
  always_comb begin
    next_state = state;
    // Defaults for combinatorial variables (safe defaults)
    bin_left  = 17'h0;
    bin_right = 17'h0;
    cur_path  = 17'h0;
    cur_path_valid = 1'b0;
    cur_delay = 17'h0;
    min_delay = 17'h0;
    has_any_path = 1'b0;

    case (state)
      IDLE: begin
        result = IMPOSSIBLE;
        done   = 1'b0;
        best_s = IMPOSSIBLE;
        found_any = 1'b0;
        cand_s = 17'h0;
        cycle  = 5'h0;
        if (start) begin
          result = IMPOSSIBLE;
          done   = 1'b0;
          best_s = IMPOSSIBLE;
          found_any = 1'b0;
          cand_s = 17'h0;
          next_state = LOAD;
        end
      end

      LOAD: begin
        // Latch inputs once
        l_num_stations   = num_stations;
        l_num_trains     = num_trains;
        for (int i = 0; i < 4; i++) begin
          l_train_station[i] = train_station[i];
          l_train_depart[i]  = train_depart[i];
          l_train_arrive[i]  = train_arrive[i];
          l_train_delay[i]   = train_delay[i];
        end
        cand_s = 17'h0;
        best_s = IMPOSSIBLE;
        found_any = 1'b0;
        cycle  = 5'h0;
        next_state = PROCESS;
      end

      PROCESS: begin
        // cycle at this step
        cycle = cycle + 1;

        // Determine enumeration range for this step
        // k = step index in [0 .. N-2]
        // left  = 2^k
        // right = 2^(k+1) - 1
        if (cycle == 1) begin
          bin_left  = 1;    // 2^0
          bin_right = 1;    // 2^1 - 1
        end else begin
          bin_left  = (17'b1 << cycle);         // 2^cycle
          bin_right = (17'b1 << (cycle + 1)) - 1; // 2^(cycle+1) - 1
        end

        // clamp by total paths: 2^(N-1)
        if (bin_left >= (17'b1 << (l_num_stations))) begin
          bin_left  = (17'b1 << (l_num_stations));
          bin_right = (17'b1 << (l_num_stations));
        end
        if (bin_right >= (17'b1 << (l_num_stations))) begin
          bin_right = (17'b1 << (l_num_stations)) - 1;
        end

        cur_path = bin_left;
        cur_path_valid = 1'b0;
        cur_delay = 17'h0;

        if (cur_path <= bin_right) begin
          // Decode current path at this step
          // step k examines the k least-significant digits
          int k_cycle;
          k_cycle = int'(cycle) - 1; // step index 0..N-2
          if (k_cycle < 0) k_cycle = 0;

          // Determine all leg choices (train indices) for this path at this step
          int base_idx;
          reg [1:0] train_idx [3:0];
          reg [1:0] n_trains;
          n_trains = l_num_trains;
          base_idx = 0;
          for (int i = 0; i < 4; i++) train_idx[i] = 2'b0;
          // Gather all trains for station (k+1)
          for (int t = 0; t < 4; t++) begin
            if (t < n_trains && l_train_station[t] == (k_cycle + 1)) begin
              train_idx[base_idx] = t[1:0];
              base_idx++;
            end
          end
          // digit at position k in cur_path
          int digit;
          digit = int'(cur_path >> k_cycle) & 1;
          if (base_idx == 0) begin
            // No trains from this station: no valid paths at this step
            cur_path_valid = 1'b0;
            cur_delay = 17'h0;
          end else begin
            if (digit >= base_idx) begin
              // Out-of-range digit -> invalid path at this step
              cur_path_valid = 1'b0;
              cur_delay = 17'h0;
            end else begin
              // Choose the train specified by digit
              reg [1:0] tidx;
              tidx = train_idx[digit];
              reg [16:0] start_time;
              start_time = (k_cycle == 0) ? cand_s : (l_train_arrive[tidx]);
              if (l_train_depart[tidx] < start_time) begin
                // Cannot catch this train: invalid path at this step
                cur_path_valid = 1'b0;
                cur_delay = 17'h0;
              end else begin
                // Accumulate delay for this leg
                cur_path_valid = 1'b1;
                cur_delay = l_train_delay[tidx];
              end
            end
          end
        end

        // Update running min_delay and has_any_path for current S
        if (cur_path == bin_left) begin
          // First path at this step
          if (cur_path_valid) begin
            min_delay = cur_delay;
            has_any_path = 1'b1;
          end else begin
            min_delay = 17'h0;
            has_any_path = 1'b0;
          end
        end else begin
          if (cur_path_valid) begin
            if (!has_any_path) begin
              min_delay = cur_delay;
              has_any_path = 1'b1;
            end else begin
              if (cur_delay < min_delay) min_delay = cur_delay;
            end
          end
        end

        // If we are at the last step (2^(N-1) processed) or cycle limit reached, go to CHECK
        // Total paths = 2^(N-1). We process one per cycle in PROCESS.
        if (cycle >= (17'b1 << (l_num_stations - 1))) begin
          next_state = CHECK;
        end
      end

      CHECK: begin
        // Determine eligibility for current cand_s:
        // All compatible paths must have total delay >= THRESH, and at least one path must exist.
        if (has_any_path && (min_delay >= THRESH)) begin
          if (!found_any) begin
            best_s = cand_s;
            found_any = 1'b1;
          end
        end
        cand_s = cand_s + 1;
        // Continue to next S or finish after scanning [0..131071]
        if (cand_s == 0) begin
          // Overflow happened: finished scanning
          next_state = DONE;
        end else begin
          next_state = PROCESS;
        end
      end

      DONE: begin
        result = best_s;
        done   = 1'b1;
        if (!start) next_state = IDLE; // wait for start release to go back to IDLE
      end

      default: next_state = IDLE;
    endcase
  end
endmodule
