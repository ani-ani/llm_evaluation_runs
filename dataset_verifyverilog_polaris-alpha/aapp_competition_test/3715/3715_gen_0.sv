module vacation_rest_counter(
  input clk, // Clock input
  input rst_n, // Active-low reset
  input start, // Start computation
  input [4:0] num_days, // Number of days (1-16)
  input [1:0] day_status [0:15], // Day status array (2-bit values)
  output reg [4:0] rest_count, // Minimum rest count
  output reg done // High when computation completes
);

  // State encoding
  localparam [1:0]
    IDLE    = 2'b00,
    PROCESS = 2'b01,
    DONE    = 2'b10;

  reg [1:0] state, next_state;
  reg [4:0] day_idx;          // Current day index (0-15)
  reg [1:0] prev_activity;    // 00: rest, 01: contest, 10: sport

  reg [4:0] rest_count_next;
  reg [4:0] day_idx_next;
  reg [1:0] prev_activity_next;
  reg done_next;

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= IDLE;
      rest_count    <= 5'd0;
      day_idx       <= 5'd0;
      prev_activity <= 2'b00;
      done          <= 1'b0;
    end else begin
      state         <= next_state;
      rest_count    <= rest_count_next;
      day_idx       <= day_idx_next;
      prev_activity <= prev_activity_next;
      done          <= done_next;
    end
  end

  // Combinational next-state and output logic
  always @* begin
    // Default assignments
    next_state        = state;
    rest_count_next   = rest_count;
    day_idx_next      = day_idx;
    prev_activity_next= prev_activity;
    done_next         = done;

    case (state)
      IDLE: begin
        done_next       = 1'b0;
        rest_count_next = 5'd0;
        day_idx_next    = 5'd0;
        prev_activity_next = 2'b00; // start with "rest" as previous
        if (start) begin
          // Begin processing from day 0
          next_state = PROCESS;
        end
      end

      PROCESS: begin
        done_next = 1'b0;

        if (day_idx < num_days) begin
          // Read today's status
          // 00: rest, 01: contest, 10: sport, 11: both available
          reg [1:0] st;
          st = day_status[day_idx];

          // Decide today's activity based on available options and previous activity
          // Activities encoding: same as prev_activity
          // Priority when both available: choose different from previous if possible; otherwise rest.
          reg [1:0] today_activity;

          case (st)
            2'b00: begin
              // Forced rest
              today_activity    = 2'b00;
              rest_count_next   = rest_count + 5'd1;
            end

            2'b01: begin
              // Contest only; must rest if same as previous
              if (prev_activity == 2'b01) begin
                today_activity  = 2'b00;
                rest_count_next = rest_count + 5'd1;
              end else begin
                today_activity  = 2'b01;
              end
            end

            2'b10: begin
              // Sport only; must rest if same as previous
              if (prev_activity == 2'b10) begin
                today_activity  = 2'b00;
                rest_count_next = rest_count + 5'd1;
              end else begin
                today_activity  = 2'b10;
              end
            end

            2'b11: begin
              // Both available: choose an activity different from previous when possible
              if (prev_activity == 2'b01) begin
                today_activity = 2'b10; // switch to sport
              end else if (prev_activity == 2'b10) begin
                today_activity = 2'b01; // switch to contest
              end else begin
                // previous rest: choose any (e.g., contest)
                today_activity = 2'b01;
              end
            end

            default: begin
              today_activity    = 2'b00;
              rest_count_next   = rest_count + 5'd1;
            end
          endcase

          prev_activity_next = today_activity;
          day_idx_next       = day_idx + 5'd1;

          // If that was the last day, move to DONE
          if (day_idx_next >= num_days) begin
            next_state = DONE;
          end
        end else begin
          // No more days to process
          next_state = DONE;
        end
      end

      DONE: begin
        done_next = 1'b1;
        // Hold count and done until a new start (after optional reset)
        if (start) begin
          // Allow immediate restart without requiring external reset
          done_next          = 1'b0;
          rest_count_next    = 5'd0;
          day_idx_next       = 5'd0;
          prev_activity_next = 2'b00;
          next_state         = PROCESS;
        end
      end

      default: begin
        next_state        = IDLE;
        rest_count_next   = 5'd0;
        day_idx_next      = 5'd0;
        prev_activity_next= 2'b00;
        done_next         = 1'b0;
      end
    endcase
  end

endmodule