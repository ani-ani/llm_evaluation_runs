module mps_receiver(
  input clk,
  input rst_n,
  input start,
  input [1:0] beacon_count,
  input [9:0] x[0:3],
  input [9:0] y[0:3],
  input [11:0] d[0:3],
  output reg [9:0] x_r,
  output reg [9:0] y_r,
  output reg [1:0] status
);

  // Localparams for state machine
  localparam S_IDLE    = 3'd0;
  localparam S_SEARCH  = 3'd1;
  localparam S_CALC    = 3'd2;
  localparam S_CHECK   = 3'd3;
  localparam S_DONE    = 3'd4;

  // Search grid size and limits
  localparam GRID_SIZE = 1024;
  localparam MIN_COORD = -512;
  localparam MAX_COORD = 511;

  // State and iteration counters
  reg [2:0] state;
  reg [9:0] x_cnt; // 0..1023 -> maps to -512..511
  reg [9:0] y_cnt; // 0..1023 -> maps to -512..511
  reg [9:0] cycle_cnt; // 0..1023 (max 1024 cycles to complete)

  // Candidate coordinates (signed intermediate values)
  shortint x_cand, y_cand;

  // Distance/validity check signals
  reg [11:0] dist_short;
  reg match;
  reg valid_candidate;
  reg [1:0] beacon_idx;

  // Results
  reg [9:0] first_x;
  reg [9:0] first_y;
  reg [9:0] second_x;
  reg [9:0] second_y;
  reg [1:0] solutions_count; // 0,1,2+ (capped at 2 to detect >1)

  // Convert counter value to signed coordinate
  function [10:0] to_coord;
    input [9:0] cnt;
    // Sign-extend 10-bit cnt to 11-bit then add MIN_COORD
    to_coord = $signed({1'b0, cnt}) + MIN_COORD;
  endfunction

  // Update Manhattan distance checking for a given candidate
  always @(*) begin
    // Default values
    dist_short = '0;
    match      = 1'b0;
    // Current candidate (signed)
    x_cand = $signed(to_coord(x_cnt));
    y_cand = $signed(to_coord(y_cnt));

    // Beacon loop
    match = 1'b1; // assume pass until a failure found
    for (beacon_idx = 2'd0; beacon_idx < 2'd4; beacon_idx = beacon_idx + 1'b1) begin
      if (beacon_idx < beacon_count) begin
        // Compute Manhattan distance for this beacon
        dist_short = $unsigned($abs($signed(x[beacon_idx]) - x_cand) +
                                $abs($signed(y[beacon_idx]) - y_cand));
        // Compare with measured distance (unsigned)
        if (dist_short != d[beacon_idx]) begin
          match = 1'b0;
        end
      end
    end
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= S_IDLE;
      x_cnt         <= 10'd0;
      y_cnt         <= 10'd0;
      cycle_cnt     <= 10'd0;
      status        <= 2'b00; // computing by default after start
      x_r           <= 10'd0;
      y_r           <= 10'd0;
      first_x       <= 10'd0;
      first_y       <= 10'd0;
      second_x      <= 10'd0;
      second_y      <= 10'd0;
      solutions_count <= 2'd0;
    end else begin
      case (state)
        S_IDLE: begin
          if (start) begin
            // Initialize for search
            x_cnt             <= 10'd0;
            y_cnt             <= 10'd0;
            cycle_cnt         <= 10'd0;
            status            <= 2'b00; // computing
            first_x           <= 10'd0;
            first_y           <= 10'd0;
            second_x          <= 10'd0;
            second_y          <= 10'd0;
            solutions_count   <= 2'd0;
            if (beacon_count == 2'd0) begin
              // No beacons provided: impossible immediately
              status  <= 2'b11; // impossible
              state   <= S_DONE;
            end else begin
              state   <= S_SEARCH;
            end
          end else begin
            status <= 2'b00; // idle -> computing (ready)
          end
        end

        S_SEARCH: begin
          if (cycle_cnt >= 10'd1023) begin
            // Time budget reached -> finalize result
            state <= S_DONE;
          end else begin
            cycle_cnt <= cycle_cnt + 1'b1;
            state     <= S_CALC;
          end
        end

        S_CALC: begin
          // Evaluate current candidate
          valid_candidate <= match;
          state           <= S_CHECK;
        end

        S_CHECK: begin
          if (valid_candidate) begin
            if (solutions_count == 2'd0) begin
              // First solution found
              first_x  <= x_cnt;
              first_y  <= y_cnt;
              solutions_count <= 2'd1;
            end else if (solutions_count == 2'd1) begin
              // Second solution found -> mark as uncertain
              second_x <= x_cnt;
              second_y <= y_cnt;
              solutions_count <= 2'd2; // 2 or more
            end
          end
          // Advance to next coordinate or finish
          if (cycle_cnt >= 10'd1023) begin
            state <= S_DONE;
          end else begin
            // Move to next position in raster order
            if (x_cnt == (GRID_SIZE - 1)) begin
              x_cnt <= 10'd0;
              y_cnt <= (y_cnt == (GRID_SIZE - 1)) ? 10'd0 : (y_cnt + 1'b1);
            end else begin
              x_cnt <= x_cnt + 1'b1;
            end
            state <= S_SEARCH;
          end
        end

        S_DONE: begin
          // Finalize outputs based on number of solutions found
          if (solutions_count == 2'd0) begin
            status <= 2'b11; // impossible
            x_r    <= 10'd0;
            y_r    <= 10'd0;
          end else if (solutions_count == 2'd1) begin
            status <= 2'b01; // unique
            x_r    <= first_x;
            y_r    <= first_y;
          end else begin
            status <= 2'b10; // uncertain
            x_r    <= first_x;
            y_r    <= first_y;
          end
          // Hold done state until a new start or reset
          if (!start) begin
            // Allow returning to IDLE when start is deasserted
            state <= S_IDLE;
          end
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule