module gas_station_optimizer(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [15:0] g,
  input [15:0] d [0:7],
  input [15:0] c [0:7],
  output reg [31:0] total_cost,
  output reg error,
  output reg done
);

  // State encoding
  localparam IDLE        = 3'b000;
  localparam INIT        = 3'b001;
  localparam FIND_CHEAPER= 3'b010;
  localparam REFUEL      = 3'b011;
  localparam UPDATE      = 3'b100;
  localparam DONE        = 3'b101;

  reg [2:0] state, state_next;
  // Internal datapath
  reg [15:0] fuel;           // current fuel (0..g)
  reg [15:0] dist_between;   // distance to next station
  reg [15:0] dist_needed;    // fuel needed to next cheaper
  reg [15:0] remaining_range;// remaining range from current station
  reg [15:0] cost_sum;       // running cost (32-bit via extension)
  reg [2:0] i, j;            // station indices
  reg [2:0] target;          // target index for next action
  reg cheap_found;           // cheaper station found flag
  reg [15:0] cheapest_cost;  // cheapest cost found within range
  reg [2:0] cheapest_idx;    // index of cheapest station
  reg invalid_param;         // input validation flag

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      fuel <= 16'd0;
      dist_between <= 16'd0;
      dist_needed <= 16'd0;
      remaining_range <= 16'd0;
      cost_sum <= 16'd0;
      i <= 3'd0;
      j <= 3'd0;
      target <= 3'd0;
      cheap_found <= 1'b0;
      cheapest_cost <= 16'd0;
      cheapest_idx <= 3'd0;
      invalid_param <= 1'b0;
      error <= 1'b0;
      done <= 1'b0;
      total_cost <= 32'd0;
    end else begin
      state <= state_next;

      case (state)
        IDLE: begin
          fuel <= g;               // preload tank at position 0
          dist_between <= 16'd0;
          dist_needed <= 16'd0;
          remaining_range <= 16'd0;
          cost_sum <= 16'd0;
          i <= 3'd0;
          j <= 3'd0;
          target <= 3'd0;
          cheap_found <= 1'b0;
          cheapest_cost <= 16'd0;
          cheapest_idx <= 3'd0;
          invalid_param <= (n == 4'd0) || (n > 4'd8);
          error <= 1'b0;
          done <= 1'b0;
          total_cost <= 32'd0;
        end

        INIT: begin
          // We are at station i with full tank (fuel==g)
          // Check reachability to the next station
          if (i >= n-1) begin
            // Past last station -> trip complete
            state <= DONE;
          end else begin
            dist_between <= (d[i+1] >= d[i]) ? (d[i+1] - d[i]) : 16'd0;
            if (fuel < ((d[i+1] >= d[i]) ? (d[i+1] - d[i]) : 16'd0)) begin
              // Cannot move to next station
              error <= 1'b1;
              done <= 1'b1;
              total_cost <= 32'hFFFFFFFF;
              state <= DONE;
            end else begin
              state <= FIND_CHEAPER;
            end
          end
        end

        FIND_CHEAPER: begin
          // Search for the cheapest station within current fuel range (>= i+1)
          // Start with default: no cheaper found, target = full at current
          cheap_found <= 1'b0;
          cheapest_cost <= 16'hFFFF; // max unsigned 16-bit
          cheapest_idx <= i;

          // Scan stations from i+1 to min(n-1, i + fuel) inclusive
          // remaining_range = fuel; we add distance to each next station cumulatively
          remaining_range <= fuel;
          j <= i + 1;
          dist_needed <= 16'd0; // running sum of distances from i
          state <= REFUEL; // enter REFUEL for next-state computation (loop in UPDATE)
        end

        REFUEL: begin
          // Wait state to allow UPDATE to perform the search iteration
          // No action; state will be set in UPDATE
        end

        UPDATE: begin
          // Perform one iteration of the search: either move to next j or finalize target
          if (j < n) begin
            // Update dist_needed with leg j-1 -> j
            if (j == i+1) begin
              dist_needed <= (d[j] >= d[i]) ? (d[j] - d[i]) : 16'd0;
            end else begin
              // dist_needed[j-1] + (d[j] - d[j-1]), wrapped
              dist_needed <= dist_needed + ((d[j] >= d[j-1]) ? (d[j] - d[j-1]) : 16'd0);
            end

            if (dist_needed <= remaining_range) begin
              // Station j is within current range
              if (c[j] < cheapest_cost) begin
                cheapest_cost <= c[j];
                cheapest_idx <= j;
                cheap_found <= 1'b1;
              end
              j <= j + 1;
              state <= REFUEL; // continue searching next station
            end else begin
              // Exceeded range; finalize target
              if (cheap_found) begin
                target <= cheapest_idx; // next cheaper within range
              end else begin
                target <= i;            // refuel to full at current station
              end
              state <= REFUEL; // move to refuel decision
            end
          end else begin
            // Reached last station within range or exhausted stations
            if (cheap_found) begin
              target <= cheapest_idx;
            end else begin
              target <= i;
            end
            state <= REFUEL;
          end
        end

        REFUEL: begin
          if (target == i) begin
            // No cheaper within range; refuel to full at current station
            if (fuel < g) begin
              // buy (g - fuel) at current cost c[i]
              cost_sum <= cost_sum + ((g >= fuel) ? (g - fuel) : 16'd0) * c[i];
              fuel <= g;
            end
            // Travel to next station (i+1)
            if (i < n-1) begin
              fuel <= fuel - ((d[i+1] >= d[i]) ? (d[i+1] - d[i]) : 16'd0);
              i <= i + 1;
            end
            state <= INIT;
          end else begin
            // There is a cheaper station within range (target)
            // Compute fuel needed to reach target (from current i)
            // dist_needed was computed up to j, recompute to target safely:
            if (target == i+1) begin
              dist_needed <= (d[i+1] >= d[i]) ? (d[i+1] - d[i]) : 16'd0;
            end else begin
              // Summation from i to target
              // Since n <= 8 and 16-bit arithmetic, perform wrapping addition
              if (target > i) begin
                dist_needed <= ((d[i+1] >= d[i]) ? (d[i+1] - d[i]) : 16'd0) +
                               ((d[i+2] >= d[i+1]) ? (d[i+2] - d[i+1]) : 16'd0) +
                               ((d[i+3] >= d[i+2]) ? (d[i+3] - d[i+2]) : 16'd0) +
                               ((d[i+4] >= d[i+3]) ? (d[i+4] - d[i+3]) : 16'd0) +
                               ((d[i+5] >= d[i+4]) ? (d[i+5] - d[i+4]) : 16'd0) +
                               ((d[i+6] >= d[i+5]) ? (d[i+6] - d[i+5]) : 16'd0) +
                               ((d[i+7] >= d[i+6]) ? (d[i+7] - d[i+6]) : 16'd0);
                // Mask to 16-bit (wrap)
                dist_needed <= dist_needed & 16'hFFFF;
              end else begin
                dist_needed <= 16'hFFFF; // unreachable; will error out next
              end
            end

            // Buy just enough to reach target (min amount to have fuel >= dist_needed)
            if (dist_needed > fuel) begin
              // amount = dist_needed - fuel (wrapped by subtraction semantics)
              cost_sum <= cost_sum + ((dist_needed >= fuel) ? (dist_needed - fuel) : 16'd0) * c[i];
              fuel <= dist_needed; // now have exactly dist_needed fuel
            end

            // Travel to target, ensuring the next leg is always to target
            // Subtract dist_needed from fuel (wrap)
            fuel <= fuel - dist_needed;
            i <= target;
            state <= INIT;
          end
        end

        DONE: begin
          // Hold outputs; allow reset to re-start
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    state_next = state;
    case (state)
      IDLE:        state_next = (start && !invalid_param) ? INIT : IDLE;
      INIT:        state_next = (error || done) ? DONE : FIND_CHEAPER;
      FIND_CHEAPER:state_next = REFUEL;
      REFUEL:      state_next = UPDATE;
      UPDATE:      begin
                     // stay in UPDATE loop until target is finalized; handled by UPDATE block
                     // After UPDATE computes target, loop back to REFUEL to perform refuel
                     state_next = REFUEL;
                   end
      DONE:        state_next = DONE;
      default:     state_next = IDLE;
    endcase
  end

endmodule
