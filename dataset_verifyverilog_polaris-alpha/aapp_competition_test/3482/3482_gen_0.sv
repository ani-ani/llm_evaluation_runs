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

  // State encoding
  typedef enum logic [1:0] {
    IDLE       = 2'b00,
    LOAD_DATA  = 2'b01,
    CALCULATE  = 2'b10,
    DONE_STATE = 2'b11
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [3:0] day_idx;               // current day index (1..t)
  reg [15:0] dp [0:16];            // dp[day]: minimal cost up to 'day'
  reg [15:0] dp_next;
  reg [15:0] prefix_days [0:7];    // cumulative threshold days for price levels
  reg [2:0] level;                 // selected price level index
  reg [15:0] skipped_mask;         // bitmask: 1 if day is skipped (trip day)

  // Unpacked trips (4 trips max, each 4 bits a, 4 bits b)
  reg [3:0] a_arr [0:3];
  reg [3:0] b_arr [0:3];

  // Counters
  reg [2:0] idx;

  // Combinational: next state
  always @(*) begin
    case (state)
      IDLE: begin
        if (start)
          next_state = LOAD_DATA;
        else
          next_state = IDLE;
      end
      LOAD_DATA: begin
        // After loading prefix and trips, move to CALCULATE
        next_state = CALCULATE;
      end
      CALCULATE: begin
        if (day_idx >= t)
          next_state = DONE_STATE;
        else
          next_state = CALCULATE;
      end
      DONE_STATE: begin
        if (!start)
          next_state = IDLE;
        else
          next_state = DONE_STATE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Helper: compute price level for a given used_days
  function automatic [2:0] get_level;
    input [15:0] used_days;
    input [2:0] l_local;
    input [15:0] prefix [0:7];
    integer i;
    begin
      get_level = 3'd0;
      if (l_local == 0) begin
        get_level = 3'd0;
      end else begin
        for (i = 0; i < 8; i = i + 1) begin
          if (i < l_local) begin
            if (used_days < prefix[i]) begin
              get_level = i[2:0];
              disable for_loop_break;
            end
          end
        end
        // If not found in loop, use last level (l_local-1)
        for_loop_break: begin end
        if (used_days >= prefix[l_local-1]) begin
          get_level = (l_local-1)[2:0];
        end
      end
    end
  endfunction

  // Helper: check if a given day is skipped
  function automatic is_skipped_day;
    input [3:0] day;
    input [15:0] mask;
    begin
      is_skipped_day = (mask[day] == 1'b1);
    end
  endfunction

  // Sequential logic
  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      total_cost <= 16'd0;
      done <= 1'b0;
      day_idx <= 4'd0;
      skipped_mask <= 16'd0;
      for (i = 0; i <= 16; i = i + 1) begin
        dp[i] <= 16'd0;
      end
      for (i = 0; i < 8; i = i + 1) begin
        prefix_days[i] <= 16'd0;
      end
      for (i = 0; i < 4; i = i + 1) begin
        a_arr[i] <= 4'd0;
        b_arr[i] <= 4'd0;
      end
    end else begin
      state <= next_state;
      case (state)
        IDLE: begin
          done <= 1'b0;
          total_cost <= 16'd0;
          if (start) begin
            // Clear data structures when starting
            skipped_mask <= 16'd0;
            for (i = 0; i <= 16; i = i + 1) begin
              dp[i] <= 16'd0;
            end
            for (i = 0; i < 8; i = i + 1) begin
              prefix_days[i] <= 16'd0;
            end
          end
        end

        LOAD_DATA: begin
          // Unpack trips
          a_arr[0] <= trips[3:0];
          b_arr[0] <= trips[7:4];
          a_arr[1] <= trips[15:12];
          b_arr[1] <= trips[19:16];
          a_arr[2] <= trips[27:24];
          b_arr[2] <= trips[31:28];
          a_arr[3] <= trips[39:36];
          b_arr[3] <= trips[43:40];

          // Initialize skipped days mask based on trips and n
          skipped_mask <= 16'd0;
          for (i = 0; i < 4; i = i + 1) begin
            if (i < n) begin
              if (b_arr[i] >= a_arr[i]) begin
                integer d_idx;
                for (d_idx = 0; d_idx < 16; d_idx = d_idx + 1) begin
                  if ((d_idx >= a_arr[i]) && (d_idx <= b_arr[i])) begin
                    skipped_mask[d_idx] <= 1'b1;
                  end
                end
              end
            end
          end

          // Build prefix_days from d[] and l
          if (l > 0) begin
            prefix_days[0] <= d[0];
            for (i = 1; i < 8; i = i + 1) begin
              if (i < l)
                prefix_days[i] <= prefix_days[i-1] + d[i];
              else
                prefix_days[i] <= prefix_days[i-1];
            end
          end

          // Initialize DP base case
          dp[0] <= 16'd0;
          day_idx <= 4'd0;
        end

        CALCULATE: begin
          if (day_idx < t) begin
            reg [3:0] next_day;
            reg [15:0] used_days;
            reg [2:0] lvl;
            reg [15:0] price;

            next_day = day_idx + 1;

            // If day is skipped (trip day), cost stays the same
            if (is_skipped_day(next_day, skipped_mask)) begin
              dp[next_day] <= dp[day_idx];
            end else begin
              // Count non-skipped days up to next_day
              integer cnt;
              integer k;
              cnt = 0;
              for (k = 1; k <= next_day; k = k + 1) begin
                if (!skipped_mask[k])
                  cnt = cnt + 1;
              end
              used_days = cnt[15:0];

              // Determine price level
              lvl = get_level(used_days, l, prefix_days);
              price = p[lvl];

              dp[next_day] <= dp[day_idx] + price;
            end

            day_idx <= next_day;
          end
        end

        DONE_STATE: begin
          total_cost <= dp[t];
          done <= 1'b1;
        end
      endcase
    end
  end

endmodule