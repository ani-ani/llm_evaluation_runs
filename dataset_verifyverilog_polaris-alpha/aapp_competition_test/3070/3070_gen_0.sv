module train_refund_eligibility(
  input clk,
  input rst_n,
  input start,
  input [1:0] num_stations,
  input [1:0] num_trains,
  input [1:0] train_station [3:0],
  input [16:0] train_depart [3:0],
  input [16:0] train_arrive [3:0],
  input [16:0] train_delay [3:0],
  output reg [16:0] result,
  output reg done
);

  // Constants
  localparam [16:0] IMPOSSIBLE = 17'd131071;
  localparam [16:0] THRESHOLD  = 17'd1800;

  // State machine encoding
  typedef enum logic [2:0] {
    IDLE    = 3'd0,
    LOAD    = 3'd1,
    PROCESS = 3'd2,
    CHECK   = 3'd3,
    DONE    = 3'd4
  } state_t;

  state_t state, next_state;

  // Internal storage for inputs (latched on LOAD)
  reg [1:0]  st_num_stations;
  reg [1:0]  st_num_trains;
  reg [1:0]  st_train_station [3:0];
  reg [16:0] st_train_depart  [3:0];
  reg [16:0] st_train_arrive  [3:0];
  reg [16:0] st_train_delay   [3:0];

  // Candidate start times from station 1
  reg [16:0] cand_S   [3:0];
  reg [1:0]  cand_cnt;          // number of candidates (0-4)

  // Index for processing candidates
  reg [1:0]  cand_idx;          // which candidate we are testing

  // Per-candidate flags
  reg        cand_valid;        // candidate has at least one full path
  reg        cand_all;          // all-full-paths-satisfy flag

  // Path enumeration state
  reg [1:0]  p_idx [3:0];       // indices of trains selected per leg
  reg [1:0]  max_trains_m1;     // num_trains-1

  reg [16:0] S0;                // current candidate S
  reg [16:0] planned_total;     // sum(T-S) over legs
  reg [16:0] actual_final;      // final actual arrival time

  // Helper wires for dimensions
  wire [1:0] N = st_num_stations;  // 2-4
  wire [1:0] M = st_num_trains;    // 1-4

  // Synchronous state and registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= IDLE;
      result        <= IMPOSSIBLE;
      done          <= 1'b0;
      st_num_stations <= 2'd0;
      st_num_trains   <= 2'd0;
      cand_cnt      <= 2'd0;
      cand_idx      <= 2'd0;
      max_trains_m1 <= 2'd0;
      S0            <= 17'd0;
      planned_total <= 17'd0;
      actual_final  <= 17'd0;
      cand_valid    <= 1'b0;
      cand_all      <= 1'b0;
      p_idx[0]      <= 2'd0;
      p_idx[1]      <= 2'd0;
      p_idx[2]      <= 2'd0;
      p_idx[3]      <= 2'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done   <= 1'b0;
          result <= IMPOSSIBLE;
        end

        LOAD: begin
          // Latch inputs
          st_num_stations <= num_stations;
          st_num_trains   <= num_trains;
          st_train_station[0] <= train_station[0];
          st_train_station[1] <= train_station[1];
          st_train_station[2] <= train_station[2];
          st_train_station[3] <= train_station[3];
          st_train_depart[0]  <= train_depart[0];
          st_train_depart[1]  <= train_depart[1];
          st_train_depart[2]  <= train_depart[2];
          st_train_depart[3]  <= train_depart[3];
          st_train_arrive[0]  <= train_arrive[0];
          st_train_arrive[1]  <= train_arrive[1];
          st_train_arrive[2]  <= train_arrive[2];
          st_train_arrive[3]  <= train_arrive[3];
          st_train_delay[0]   <= train_delay[0];
          st_train_delay[1]   <= train_delay[1];
          st_train_delay[2]   <= train_delay[2];
          st_train_delay[3]   <= train_delay[3];

          // Initialize candidate collection
          cand_cnt      <= 2'd0;
          cand_idx      <= 2'd0;
          max_trains_m1 <= (num_trains == 0) ? 2'd0 : (num_trains - 1'b1);
          cand_valid    <= 1'b0;
          cand_all      <= 1'b0;
        end

        PROCESS: begin
          // Build list of candidate start times from station 1 (station index = 2'b01)
          // Do once at entry to PROCESS: when cand_cnt==0 and cand_idx==0
          if (cand_cnt == 2'd0 && cand_idx == 2'd0) begin
            // Collect departures of trains starting at station 1
            cand_cnt <= 2'd0;
            if (st_train_station[0] == 2'd1) begin
              cand_S[0] <= st_train_depart[0];
              cand_cnt  <= cand_cnt + 1'b1;
            end
            if (st_train_station[1] == 2'd1) begin
              cand_S[cand_cnt] <= st_train_depart[1];
              cand_cnt         <= cand_cnt + 1'b1;
            end
            if (st_train_station[2] == 2'd1) begin
              cand_S[cand_cnt] <= st_train_depart[2];
              cand_cnt         <= cand_cnt + 1'b1;
            end
            if (st_train_station[3] == 2'd1) begin
              cand_S[cand_cnt] <= st_train_depart[3];
              cand_cnt         <= cand_cnt + 1'b1;
            end
          end else begin
            // Prepare for next state's checking
            cand_valid <= 1'b0;
            cand_all   <= 1'b1; // will AND with each path check

            // Initialize path index for current candidate
            p_idx[0] <= 2'd0;
            p_idx[1] <= 2'd0;
            p_idx[2] <= 2'd0;
            p_idx[3] <= 2'd0;

            if (cand_idx < cand_cnt)
              S0 <= cand_S[cand_idx];
            else
              S0 <= 17'd0;

            planned_total <= 17'd0;
            actual_final  <= 17'd0;
          end
        end

        CHECK: begin
          if (cand_idx < cand_cnt) begin
            // Enumerate all combinations of trains for legs 1..N-1
            // Using p_idx as nested counters; we step one combination per cycle
            integer i;
            reg path_ok;
            reg any_leg_fail;
            reg [16:0] cur_start_time;
            reg [16:0] cur_planned_total;
            reg [16:0] cur_actual_time;

            path_ok        = 1'b1;
            any_leg_fail   = 1'b0;
            cur_start_time = S0;
            cur_planned_total = 17'd0;

            // For each leg k from 1 to N-1
            for (i = 0; i < 3; i = i + 1) begin
              if (i < (N - 1)) begin
                // Select train index idx = p_idx[i]
                reg [1:0] idx;
                reg [1:0] from_st;
                reg [1:0] to_st;
                reg [16:0] dep;
                reg [16:0] arr;
                reg [16:0] delay;

                idx    = p_idx[i];
                from_st = st_train_station[idx];
                // to_st = from_st + 1 (sequential stations)
                to_st  = from_st + 1'b1;
                dep    = st_train_depart[idx];
                arr    = st_train_arrive[idx];
                delay  = st_train_delay[idx];

                // Check if this leg's train is compatible:
                // - from correct station
                // - departure >= arrival of previous leg
                // For first leg: from station 1, dep == S0
                if (i == 0) begin
                  if (from_st != 2'd1 || dep != S0) begin
                    any_leg_fail = 1'b1;
                  end
                end else begin
                  // station index should be (i+1)
                  if (from_st != (i[1:0] + 2'd1)) begin
                    any_leg_fail = 1'b1;
                  end
                  // require dep >= previous actual arrival
                  if (dep < cur_actual_time)
                    any_leg_fail = 1'b1;
                end

                if (!any_leg_fail) begin
                  cur_planned_total = cur_planned_total + (arr - dep);
                  cur_actual_time   = arr + delay;
                end

              end
            end

            if (any_leg_fail) begin
              path_ok = 1'b0;
            end else begin
              // Verify last leg arrived at station N
              if ((N > 1) && (st_train_station[p_idx[N-2]] + 1'b1 != N)) begin
                path_ok = 1'b0;
              end else begin
                // final times already in cur_planned_total, cur_actual_time
                if ((cur_actual_time - cur_planned_total) < THRESHOLD)
                  path_ok = 1'b0;
              end
            end

            // Update candidate flags
            if (path_ok) begin
              cand_valid <= 1'b1;
            end
            if (!path_ok) begin
              cand_all <= 1'b0;
            end

            // Increment combination index (nested counter)
            // We iterate full M^(N-1) space; invalid combos are filtered above.
            if (N > 1) begin
              // Increment p_idx[0]
              if (p_idx[0] < max_trains_m1) begin
                p_idx[0] <= p_idx[0] + 1'b1;
              end else begin
                p_idx[0] <= 2'd0;
                if (N > 2) begin
                  if (p_idx[1] < max_trains_m1) begin
                    p_idx[1] <= p_idx[1] + 1'b1;
                  end else begin
                    p_idx[1] <= 2'd0;
                    if (N > 3) begin
                      if (p_idx[2] < max_trains_m1) begin
                        p_idx[2] <= p_idx[2] + 1'b1;
                      end else begin
                        p_idx[2] <= 2'd0;
                        // All combinations tried for this candidate
                      end
                    end
                  end
                end
              end
            end

          end
        end

        DONE: begin
          done <= 1'b1;
        end

        default: ;
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;

    case (state)
      IDLE: begin
        if (start)
          next_state = LOAD;
      end

      LOAD: begin
        next_state = PROCESS;
      end

      PROCESS: begin
        // After building candidates and initializing for first candidate, go to CHECK
        next_state = CHECK;
      end

      CHECK: begin
        // Control progression over candidates within fixed latency budget.
        // For simplicity and determinism (8 + 2*M cycles), we limit to linear scan
        // evaluating one candidate over a bounded number of cycles.
        // Here, on each visit we decide whether to move to next candidate or DONE.

        if (cand_idx < cand_cnt) begin
          // Decide acceptance of current candidate when counters wrap to zero,
          // i.e., last combination done. Detect by all p_idx == 0 after increment.
          if ((p_idx[0] == 2'd0) && (p_idx[1] == 2'd0) &&
              (p_idx[2] == 2'd0) && (p_idx[3] == 2'd0)) begin
            // All combinations checked for this candidate
            if (cand_valid && cand_all) begin
              // Found earliest valid S
              next_state = DONE;
            end else begin
              // Move to next candidate
              next_state = PROCESS;
            end
          end else begin
            next_state = CHECK;
          end
        end else begin
          // No candidates or finished all without success
          next_state = DONE;
        end
      end

      DONE: begin
        if (!start)
          next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Result update: capture earliest valid candidate when transitioning to DONE
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= IMPOSSIBLE;
    end else begin
      if (state == CHECK && next_state == DONE) begin
        if (cand_valid && cand_all && cand_idx < cand_cnt) begin
          result <= S0;
        end else begin
          result <= IMPOSSIBLE;
        end
      end else if (state == LOAD) begin
        result <= IMPOSSIBLE;
      end
    end
  end

endmodule