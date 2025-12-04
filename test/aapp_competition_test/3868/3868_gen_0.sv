module flight_scheduler(
  input clk,
  input rst_n,
  input start,
  input [15:0] k_days,
  input [3:0] num_flights,
  input [3:0][15:0] flight_days,
  input [3:0][2:0] flight_from,
  input [3:0][2:0] flight_to,
  input [3:0][31:0] flight_cost,
  output reg [31:0] min_cost,
  output reg done,
  output reg impossible
);

  // Internal parameters
  localparam IDLE       = 2'd0;
  localparam PROCESSING = 2'd1;
  localparam DONE       = 2'd2;

  localparam CITY_COUNT = 4; // cities 1..4

  // Internal registers
  reg [1:0] state, next_state;

  reg [4:0] cycle_cnt;         // up to 31
  reg [4:0] flight_idx;        // up to 31 (we use only up to 15)

  // Arrival (to city 0) and departure (from city 0) trackers
  // Index by city 1..4 (0 unused)
  reg [31:0] min_arr_cost   [0:CITY_COUNT];
  reg [15:0] best_arr_day   [0:CITY_COUNT];
  reg        has_arr        [0:CITY_COUNT];

  reg [31:0] min_dep_cost   [0:CITY_COUNT];
  reg [15:0] best_dep_day   [0:CITY_COUNT];
  reg        has_dep        [0:CITY_COUNT];

  // Phase: 0 = process arrivals (to city 0), 1 = process departures (from city 0)
  reg phase;

  // Local signals for current flight
  reg [15:0] cur_day;
  reg [2:0]  cur_from;
  reg [2:0]  cur_to;
  reg [31:0] cur_cost;

  // Combinational next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = PROCESSING;
      end
      PROCESSING: begin
        // After 32 cycles, move to DONE
        if (cycle_cnt == 5'd31)
          next_state = DONE;
      end
      DONE: begin
        // Wait for next start to restart
        if (start)
          next_state = PROCESSING;
      end
      default: next_state = IDLE;
    endcase
  end

  // Helper task-like functions (SystemVerilog functions for array init/check)
  // Note: Using localparams for INF like value
  localparam [31:0] INF_COST = 32'h7FFFFFFF;

  integer i;

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      cycle_cnt   <= 5'd0;
      flight_idx  <= 5'd0;
      phase       <= 1'b0;
      done        <= 1'b0;
      impossible  <= 1'b0;
      min_cost    <= 32'hFFFFFFFF;

      for (i = 0; i <= CITY_COUNT; i = i + 1) begin
        min_arr_cost[i] <= INF_COST;
        best_arr_day[i] <= 16'hFFFF;
        has_arr[i]      <= 1'b0;
        min_dep_cost[i] <= INF_COST;
        best_dep_day[i] <= 16'h0000;
        has_dep[i]      <= 1'b0;
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done       <= 1'b0;
          impossible <= 1'b0;

          if (start) begin
            // Initialize for new run
            cycle_cnt  <= 5'd0;
            flight_idx <= 5'd0;
            phase      <= 1'b0; // start with arrivals
            min_cost   <= 32'hFFFFFFFF;

            for (i = 0; i <= CITY_COUNT; i = i + 1) begin
              min_arr_cost[i] <= INF_COST;
              best_arr_day[i] <= 16'hFFFF;
              has_arr[i]      <= 1'b0;
              min_dep_cost[i] <= INF_COST;
              best_dep_day[i] <= 16'h0000;
              has_dep[i]      <= 1'b0;
            end
          end
        end

        PROCESSING: begin
          // Default increments
          cycle_cnt <= cycle_cnt + 5'd1;

          // Guard on actual flights
          if (flight_idx < {1'b0, num_flights}) begin
            // Decode which packed element to use: 0..3
            case (flight_idx[1:0])
              2'd0: begin
                cur_day  <= flight_days[0];
                cur_from <= flight_from[0];
                cur_to   <= flight_to[0];
                cur_cost <= flight_cost[0];
              end
              2'd1: begin
                cur_day  <= flight_days[1];
                cur_from <= flight_from[1];
                cur_to   <= flight_to[1];
                cur_cost <= flight_cost[1];
              end
              2'd2: begin
                cur_day  <= flight_days[2];
                cur_from <= flight_from[2];
                cur_to   <= flight_to[2];
                cur_cost <= flight_cost[2];
              end
              2'd3: begin
                cur_day  <= flight_days[3];
                cur_from <= flight_from[3];
                cur_to   <= flight_to[3];
                cur_cost <= flight_cost[3];
              end
            endcase

            // Process according to phase using previous cycle's decoded values
            // To avoid 1-cycle decode latency complication, directly use arrays with index
            // computed from flight_idx in this clock (single-cycle combinational read)
            // Effective index in the 4-wide vectors
            begin : flight_access
              reg [1:0] idx4;
              reg [15:0] f_day;
              reg [2:0] f_from;
              reg [2:0] f_to;
              reg [31:0] f_cost;

              idx4  = flight_idx[1:0];
              f_day  = flight_days[idx4];
              f_from = flight_from[idx4];
              f_to   = flight_to[idx4];
              f_cost = flight_cost[idx4];

              if (phase == 1'b0) begin
                // Phase 0: process incoming to city 0 (Metropolis)
                // For each city c (1..4), we look at flights from c -> 0
                if ((f_to == 3'd0) && (f_from >= 3'd1) && (f_from <= 3'd4)) begin
                  if (!has_arr[f_from] || (f_cost < min_arr_cost[f_from]) ||
                      ((f_cost == min_arr_cost[f_from]) && (f_day < best_arr_day[f_from]))) begin
                    has_arr[f_from]      <= 1'b1;
                    min_arr_cost[f_from] <= f_cost;
                    best_arr_day[f_from] <= f_day;
                  end
                end
              end else begin
                // Phase 1: process outgoing from city 0 -> city c
                if ((f_from == 3'd0) && (f_to >= 3'd1) && (f_to <= 3'd4)) begin
                  if (!has_dep[f_to] || (f_cost < min_dep_cost[f_to]) ||
                      ((f_cost == min_dep_cost[f_to]) && (f_day > best_dep_day[f_to]))) begin
                    has_dep[f_to]      <= 1'b1;
                    min_dep_cost[f_to] <= f_cost;
                    best_dep_day[f_to] <= f_day;
                  end
                end
              end
            end

            // Move to next flight
            flight_idx <= flight_idx + 5'd1;

            // When we've consumed all given flights for current phase, switch phase
            if (flight_idx + 5'd1 >= {1'b0, num_flights}) begin
              if (phase == 1'b0) begin
                // Switch to departure processing
                phase      <= 1'b1;
                flight_idx <= 5'd0;
              end
              // If already in phase 1, we simply stop reading; remaining cycles idle
            end
          end
        end

        DONE: begin
          // Compute result combinationally on entry; latch outputs.
          // We ensure outputs valid while in DONE.
          if (start) begin
            // Re-init for new run handled by IDLE->PROCESSING transition logic
            done       <= 1'b0;
            impossible <= 1'b0;
            cycle_cnt  <= 5'd0;
            flight_idx <= 5'd0;
            phase      <= 1'b0;
            min_cost   <= 32'hFFFFFFFF;

            for (i = 0; i <= CITY_COUNT; i = i + 1) begin
              min_arr_cost[i] <= INF_COST;
              best_arr_day[i] <= 16'hFFFF;
              has_arr[i]      <= 1'b0;
              min_dep_cost[i] <= INF_COST;
              best_dep_day[i] <= 16'h0000;
              has_dep[i]      <= 1'b0;
            end
          end else begin
            // Hold outputs stable in DONE
            done       <= done;
            impossible <= impossible;
            min_cost   <= min_cost;
          end
        end

        default: ;
      endcase

      // Post-processing when entering DONE (one-time computation)
      if (state == PROCESSING && next_state == DONE) begin
        // Verify feasibility and compute minimal cost
        reg all_ok;
        reg [31:0] sum_arr;
        reg [31:0] sum_dep;
        reg [31:0] total_cost;
        reg [15:0] min_depart_day;
        reg [15:0] max_arrive_day;

        all_ok = 1'b1;
        sum_arr = 32'd0;
        sum_dep = 32'd0;
        min_depart_day = 16'hFFFF;
        max_arrive_day = 16'h0000;

        for (i = 1; i <= CITY_COUNT; i = i + 1) begin
          if (!has_arr[i] || !has_dep[i]) begin
            all_ok = 1'b0;
          end else begin
            sum_arr = sum_arr + min_arr_cost[i];
            sum_dep = sum_dep + min_dep_cost[i];
            if (best_arr_day[i] > max_arrive_day)
              max_arrive_day = best_arr_day[i];
            if (best_dep_day[i] < min_depart_day)
              min_depart_day = best_dep_day[i];
          end
        end

        if (all_ok) begin
          // Check k-day window: departure_day >= arrival_day + k_days + 1
          // Using worst-case bound: min_depart_day vs max_arrive_day
          if (min_depart_day >= (max_arrive_day + k_days + 16'd1)) begin
            total_cost = sum_arr + sum_dep;
            min_cost   <= total_cost;
            impossible <= 1'b0;
          end else begin
            min_cost   <= 32'hFFFFFFFF;
            impossible <= 1'b1;
          end
        end else begin
          min_cost   <= 32'hFFFFFFFF;
          impossible <= 1'b1;
        end

        done <= 1'b1;
      end
    end
  end

endmodule