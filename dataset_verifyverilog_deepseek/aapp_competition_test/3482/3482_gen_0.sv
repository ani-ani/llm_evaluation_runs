module transit_card_minimizer(
  input clk,
  input rst_n,
  input start,
  input [2:0] l,
  input [11:0] p [0:7],
  input [11:0] d [0:6],
  input [3:0] n,
  input [3:0] t,
  input [63:0] trips,
  output reg [15:0] total_cost,
  output reg done
);

  // State machine definitions
  enum logic [1:0] {IDLE, LOAD_DATA, CALCULATE, DONE} state;

  // Internal storage
  reg [15:0] memo [0:15]; // DP array
  reg [3:0] current_day;
  reg [3:0] a [0:3];      // trip start days
  reg [3:0] b [0:3];      // trip end days
  reg [11:0] thresholds [0:7]; // cumulative thresholds for price levels

  // FSM and computation logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      total_cost <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          total_cost <= 0;
          if (start) state <= LOAD_DATA;
        end

        LOAD_DATA: begin
          // Unpack trip data
          for (int i=0; i<4; i++) begin
            a[i] <= trips[8*i +: 4];
            b[i] <= trips[8*i+4 +: 4];
          end

          // Compute cumulative thresholds
          thresholds[0] <= 0;
          for (int i=1; i<8; i++) begin
            if (i < l) thresholds[i] <= thresholds[i-1] + d[i-1];
            else thresholds[i] <= 0;
          end

          state <= CALCULATE;
          current_day <= 1;
          memo[0] <= 0;
        end

        CALCULATE: begin
          if (current_day > t) begin
            state <= DONE;
          end else begin
            // Check if current day falls within any trip
            logic skip_day;
            skip_day = 0;
            for (int i=0; i<n; i++) begin
              if ((current_day >= a[i]) && (current_day <= b[i])) skip_day = 1;
            end

            if (skip_day) begin
              memo[current_day] <= memo[current_day-1];
            end else begin
              // Find applicable price level
              logic [2:0] price_level;
              price_level = l-1;
              for (int i=l-1; i>=0; i--) begin
                if (current_day >= thresholds[i]) begin
                  price_level = i;
                  break;
                end
              end
              memo[current_day] <= memo[current_day-1] + p[price_level];
            end

            current_day <= current_day + 1;
          end
        end

        DONE: begin
          total_cost <= memo[t > 0 ? t-1 : 0];  // Handle t=0 (would be undefined)
          done <= 1;
          if (!start) state <= IDLE;
        end
      endcase
    end
  end

endmodule