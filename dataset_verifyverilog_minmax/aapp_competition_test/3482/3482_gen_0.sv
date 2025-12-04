module transit_card_minimizer(
  input clk, // system clock
  input rst_n, // active-low reset
  input start, // start calculation
  input [2:0] l, // number of price levels (1-8)
  input [11:0] p [0:7], // price levels (12-bit each)
  input [11:0] d [0:6], // threshold days (12-bit each)
  input [3:0] n, // number of trips (0-4)
  input [3:0] t, // total days (1-16)
  input [63:0] trips, // packed trip data (4 trips * 8 bits: 4b a + 4b b)
  output reg [15:0] total_cost, // minimized total cost
  output reg done // high when calculation complete
);

  // Unpack trips into two 4-bit arrays a[0..3] and b[0..3]
  reg [3:0] a [0:3];
  reg [3:0] b [0:3];
  always @(*) begin
    a[0] = trips[3:0];
    b[0] = trips[7:4];
    a[1] = trips[11:8];
    b[1] = trips[15:12];
    a[2] = trips[19:16];
    b[2] = trips[23:20];
    a[3] = trips[27:24];
    b[3] = trips[31:28];
  end

  // FSM states
  localparam IDLE      = 2'b00;
  localparam LOAD_DATA = 2'b01;
  localparam CALCULATE = 2'b10;
  localparam DONE      = 2'b11;

  reg [1:0] state, next_state;

  // Sequential state update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else        state <= next_state;
  end

  // Data storage for calculation
  reg [3:0] trips_left;
  reg [3:0] trip_a [0:3];
  reg [3:0] trip_b [0:3];
  reg [3:0] cur_day;      // 1..t
  reg [3:0] next_boundary;
  reg       have_next;
  reg [15:0] dp [0:15];   // memoization array per day
  reg       dp_valid [0:15];

  // Helper: check if a given day is within any remaining trip [a,b]
  function is_trip_day;
    input [3:0] day;
    input [3:0] trips_remaining;
    input [3:0] ta [0:3];
    input [3:0] tb [0:3];
    integer i;
    begin
      is_trip_day = 1'b0;
      for (i = 0; i < 4; i = i + 1) begin
        if (i < trips_remaining) begin
          if (day >= ta[i] && day <= tb[i]) begin
            is_trip_day = 1'b1;
          end
        end
      end
    end
  endfunction

  // Helper: compute price index for a given day (1-based day count)
  function [2:0] price_index_for_day;
    input [3:0] day; // 1..16
    input [2:0] levels; // 1..8
    input [11:0] p [0:7];
    input [11:0] d [0:6];
    reg [11:0] cum [0:6];
    integer i;
    begin
      price_index_for_day = 3'd0;
      // Precompute cumulative thresholds (l-1 of them)
      cum[0] = d[0];
      for (i = 1; i < 6; i = i + 1) begin
        cum[i] = cum[i-1] + d[i];
      end
      if (levels > 1) begin
        for (i = 0; i < 7; i = i + 1) begin
          if (i < (levels - 1)) begin
            if (day > cum[i]) begin
              price_index_for_day = i + 1;
            end
          end
        end
      end
      // Clamp to available levels
      if (price_index_for_day >= levels) price_index_for_day = levels - 1;
    end
  endfunction

  // NSL and output logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        done = 1'b0;
        if (start) next_state = LOAD_DATA;
      end
      LOAD_DATA: begin
        done = 1'b0;
        next_state = CALCULATE;
      end
      CALCULATE: begin
        done = 1'b0;
        if (cur_day > t) next_state = DONE;
      end
      DONE: begin
        done = 1'b1;
        if (!start) next_state = IDLE;
      end
      default: begin
        done = 1'b0;
        next_state = IDLE;
      end
    endcase
  end

  // Latch-based data loading and combinatorial compute
  always @(*) begin
    if (state == LOAD_DATA) begin
      total_cost = 16'd0;
      trips_left = n;
      trip_a[0] = a[0]; trip_b[0] = b[0];
      trip_a[1] = a[1]; trip_b[1] = b[1];
      trip_a[2] = a[2]; trip_b[2] = b[2];
      trip_a[3] = a[3]; trip_b[3] = b[3];
      cur_day   = 4'd1;
      have_next = (n > 0);
      next_boundary = have_next ? b[0] : 4'd0;
      dp[0] = 16'd0; dp_valid[0] = 1'b1;
      dp[1] = 16'd0; dp_valid[1] = 1'b0;
      dp[2] = 16'd0; dp_valid[2] = 1'b0;
      dp[3] = 16'd0; dp_valid[3] = 1'b0;
      dp[4] = 16'd0; dp_valid[4] = 1'b0;
      dp[5] = 16'd0; dp_valid[5] = 1'b0;
      dp[6] = 16'd0; dp_valid[6] = 1'b0;
      dp[7] = 16'd0; dp_valid[7] = 1'b0;
      dp[8] = 16'd0; dp_valid[8] = 1'b0;
      dp[9] = 16'd0; dp_valid[9] = 1'b0;
      dp[10] = 16'd0; dp_valid[10] = 1'b0;
      dp[11] = 16'd0; dp_valid[11] = 1'b0;
      dp[12] = 16'd0; dp_valid[12] = 1'b0;
      dp[13] = 16'd0; dp_valid[13] = 1'b0;
      dp[14] = 16'd0; dp_valid[14] = 1'b0;
      dp[15] = 16'd0; dp_valid[15] = 1'b0;
    end else if (state == CALCULATE) begin
      // Compute one day per cycle using latched state
      total_cost = total_cost;
      trips_left = trips_left;
      trip_a[0] = trip_a[0]; trip_b[0] = trip_b[0];
      trip_a[1] = trip_a[1]; trip_b[1] = trip_b[1];
      trip_a[2] = trip_a[2]; trip_b[2] = trip_b[2];
      trip_a[3] = trip_a[3]; trip_b[3] = trip_b[3];
      cur_day   = cur_day;
      have_next = have_next;
      next_boundary = next_boundary;
      dp[0] = dp[0]; dp_valid[0] = dp_valid[0];
      dp[1] = dp[1]; dp_valid[1] = dp_valid[1];
      dp[2] = dp[2]; dp_valid[2] = dp_valid[2];
      dp[3] = dp[3]; dp_valid[3] = dp_valid[3];
      dp[4] = dp[4]; dp_valid[4] = dp_valid[4];
      dp[5] = dp[5]; dp_valid[5] = dp_valid[5];
      dp[6] = dp[6]; dp_valid[6] = dp_valid[6];
      dp[7] = dp[7]; dp_valid[7] = dp_valid[7];
      dp[8] = dp[8]; dp_valid[8] = dp_valid[8];
      dp[9] = dp[9]; dp_valid[9] = dp_valid[9];
      dp[10] = dp[10]; dp_valid[10] = dp_valid[10];
      dp[11] = dp[11]; dp_valid[11] = dp_valid[11];
      dp[12] = dp[12]; dp_valid[12] = dp_valid[12];
      dp[13] = dp[13]; dp_valid[13] = dp_valid[13];
      dp[14] = dp[14]; dp_valid[14] = dp_valid[14];
      dp[15] = dp[15]; dp_valid[15] = dp_valid[15];

      if (trips_left == 0 || cur_day > t) begin
        // No trips or done (shouldn't reach here due to NSL, but safe)
        total_cost = total_cost;
      end else begin
        if (cur_day == next_boundary) begin
          trips_left = trips_left - 1;
          have_next = (trips_left > 0);
          next_boundary = have_next ? b[4 - trips_left] : 4'd0;
        end
        if (is_trip_day(cur_day, trips_left + 1, trip_a, trip_b)) begin
          // Trip day: no charge
          total_cost = total_cost;
        end else begin
          // Non-trip day: pay current price
          total_cost = total_cost + p[price_index_for_day(cur_day, l, p, d)];
        end
        cur_day = cur_day + 1;
      end
    end else begin
      // IDLE and DONE: hold outputs as-is
      total_cost = total_cost;
      trips_left = trips_left;
      trip_a[0] = trip_a[0]; trip_b[0] = trip_b[0];
      trip_a[1] = trip_a[1]; trip_b[1] = trip_b[1];
      trip_a[2] = trip_a[2]; trip_b[2] = trip_b[2];
      trip_a[3] = trip_a[3]; trip_b[3] = trip_b[3];
      cur_day   = cur_day;
      have_next = have_next;
      next_boundary = next_boundary;
      dp[0] = dp[0]; dp_valid[0] = dp_valid[0];
      dp[1] = dp[1]; dp_valid[1] = dp_valid[1];
      dp[2] = dp[2]; dp_valid[2] = dp_valid[2];
      dp[3] = dp[3]; dp_valid[3] = dp_valid[3];
      dp[4] = dp[4]; dp_valid[4] = dp_valid[4];
      dp[5] = dp[5]; dp_valid[5] = dp_valid[5];
      dp[6] = dp[6]; dp_valid[6] = dp_valid[6];
      dp[7] = dp[7]; dp_valid[7] = dp_valid[7];
      dp[8] = dp[8]; dp_valid[8] = dp_valid[8];
      dp[9] = dp[9]; dp_valid[9] = dp_valid[9];
      dp[10] = dp[10]; dp_valid[10] = dp_valid[10];
      dp[11] = dp[11]; dp_valid[11] = dp_valid[11];
      dp[12] = dp[12]; dp_valid[12] = dp_valid[12];
      dp[13] = dp[13]; dp_valid[13] = dp_valid[13];
      dp[14] = dp[14]; dp_valid[14] = dp_valid[14];
      dp[15] = dp[15]; dp_valid[15] = dp_valid[15];
    end
  end

  // Reset behavior: outputs to zero, done low
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      total_cost <= 16'd0;
      done <= 1'b0;
      // Initialize arrays to avoid unintended latches in simulation
      trips_left <= 4'd0;
      cur_day   <= 4'd0;
      have_next <= 1'b0;
      next_boundary <= 4'd0;
      trip_a[0] <= 4'd0; trip_b[0] <= 4'd0;
      trip_a[1] <= 4'd0; trip_b[1] <= 4'd0;
      trip_a[2] <= 4'd0; trip_b[2] <= 4'd0;
      trip_a[3] <= 4'd0; trip_b[3] <= 4'd0;
      dp[0] <= 16'd0; dp_valid[0] <= 1'b1;
      dp[1] <= 16'd0; dp_valid[1] <= 1'b0;
      dp[2] <= 16'd0; dp_valid[2] <= 1'b0;
      dp[3] <= 16'd0; dp_valid[3] <= 1'b0;
      dp[4] <= 16'd0; dp_valid[4] <= 1'b0;
      dp[5] <= 16'd0; dp_valid[5] <= 1'b0;
      dp[6] <= 16'd0; dp_valid[6] = 1'b0;
      dp[7] <= 16'd0; dp_valid[7] <= 1'b0;
      dp[8] <= 16'd0; dp_valid[8] <= 1'b0;
      dp[9] <= 16'd0; dp_valid[9] <= 1'b0;
      dp[10] <= 16'd0; dp_valid[10] <= 1'b0;
      dp[11] <= 16'd0; dp_valid[11] <= 1'b0;
      dp[12] <= 16'd0; dp_valid[12] <= 1'b0;
      dp[13] <= 16'd0; dp_valid[13] <= 1'b0;
      dp[14] <= 16'd0; dp_valid[14] <= 1'b0;
      dp[15] <= 16'd0; dp_valid[15] <= 1'b0;
    end else begin
      // Registered outputs already updated in latched blocks above
    end
  end

endmodule