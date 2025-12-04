module snake_path_finder(
    input clk, // clock signal
    input rst_n, // active-low reset
    input start, // start computation
    input [23:0] snake_data, // [7:0]=x, [15:8]=y, [23:16]=d (scaled values)
    input snake_valid, // high when snake_data is valid
    input [7:0] snake_count, // number of snakes (0-16)
    output reg [15:0] entry_exit, // [7:0]=entry_y, [15:8]=exit_y (scaled)
    output reg valid_out, // high when result valid
    output reg bitten // 1=no safe path, 0=path exists
);

  // Constants
  localparam MAX_SNAKES = 16;
  localparam WIDTH      = 256;
  localparam HEIGHT     = 256;

  // FSM states
  localparam ST_IDLE        = 2'b00;
  localparam ST_LOAD_SNAKES = 2'b01;
  localparam ST_PROCESS     = 2'b10;
  localparam ST_DONE        = 2'b11;

  // Snake storage: x, y, d (8-bit each), precomputed squared radius d2
  reg [7:0] snakes_x [0:MAX_SNAKES-1];
  reg [7:0] snakes_y [0:MAX_SNAKES-1];
  reg [7:0] snakes_d [0:MAX_SNAKES-1];
  reg [15:0] snakes_d2 [0:MAX_SNAKES-1]; // store d^2 to avoid recomputing

  // Load control
  reg [4:0] load_count;  // counts how many snakes have been loaded (0..16)
  reg [4:0] load_ptr;    // write pointer into snake arrays

  // Processing control
  reg [9:0] proc_counter;       // 0..1023 (10 bits)
  reg [3:0] i_snake;            // current snake index during check (0..15)
  reg [3:0] i_candidate;        // which of 16 y candidates (0..15)
  reg [7:0] cand_y;             // current y candidate (0..255)
  reg [7:0] best_entry_y;       // best (highest) safe y on west side
  reg [7:0] best_exit_y;        // best (highest) safe y on east side
  reg found;                    // at least one safe path found
  reg cand_safe;                // is current cand_y safe?
  reg [1:0] state, next_state;

  // Distance check temps (max value fits in 17 bits: (255^2)*2 = 130050 < 2^17)
  reg [16:0] dx, dy, dist2;

  // Sequential state update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= ST_IDLE;
      valid_out <= 1'b0;
      bitten <= 1'b1;          // default to no safe path until proven otherwise
      entry_exit <= 16'h0;
      load_count <= 5'd0;
      load_ptr <= 5'd0;
      proc_counter <= 10'd0;
      i_snake <= 4'd0;
      i_candidate <= 4'd0;
      cand_y <= 8'd0;
      best_entry_y <= 8'd0;
      best_exit_y <= 8'd0;
      found <= 1'b0;
      cand_safe <= 1'b0;
    end else begin
      // Defaults for combinational outputs used in same cycle
      valid_out <= 1'b0;
      bitten <= bitten; // hold
      entry_exit <= entry_exit;
      found <= found;
      best_entry_y <= best_entry_y;
      best_exit_y <= best_exit_y;
      cand_safe <= 1'b0; // recomputed in PROCESS
      proc_counter <= proc_counter;
      i_snake <= i_snake;
      i_candidate <= i_candidate;
      cand_y <= cand_y;
      state <= next_state;

      case (state)
        ST_IDLE: begin
          // Wait for start
          if (start) begin
            // Prepare for loading; snake_count assumed <= 16
            load_count <= {1'b0, snake_count[4:0]}; // ensure 5-bit width
            load_ptr <= 5'd0;
            // Clear memory of previous run (only up to new count for robustness)
            // No need to clear beyond load_count; new loads will overwrite
          end
        end

        ST_LOAD_SNAKES: begin
          if (snake_valid && (load_ptr < load_count)) begin
            snakes_x[load_ptr] <= snake_data[7:0];
            snakes_y[load_ptr] <= snake_data[15:8];
            snakes_d[load_ptr] <= snake_data[23:16];
            snakes_d2[load_ptr] <= $unsigned(snake_data[23:16]) * $unsigned(snake_data[23:16]);
            load_ptr <= load_ptr + 1'b1;
          end
          // Proceed to PROCESS when we've loaded all snakes
          if (load_ptr >= load_count) begin
            proc_counter <= 10'd0;
            i_snake <= 4'd0;
            i_candidate <= 4'd0;
            best_entry_y <= 8'd0;
            best_exit_y <= 8'd0;
            found <= 1'b0;
          end
        end

        ST_PROCESS: begin
          // 1024 cycles guaranteed; check 16 y candidates * 16 snakes * 4 iterations
          if (proc_counter < 10'd1023) begin
            proc_counter <= proc_counter + 1'b1;
          end

          // Determine y candidate from i_candidate and phase (iteration)
          // Map 0..15 to 0..255 in steps of 16: 0,16,32,...,240
          cand_y <= {i_candidate, 4'b0000};

          // Start a new candidate every 16 cycles (i_snake loops 0..15)
          if (i_snake == 4'd0) begin
            // Evaluate safety of current candidate for west (x=0) and east (x=255)
            // Check against all snakes; if any violation, candidate is unsafe
            cand_safe <= 1'b1; // assume safe until a violation is found
          end

          // Distance check at current snake i_snake
          // If cand_safe is already 0, we still need to finish the loop; no need to compute further, but we do for simplicity
          if (i_snake < load_count) begin
            // West side check: x0=0
            dx <= $unsigned(cand_x0()) - $unsigned(snakes_x[i_snake]); // 0 - x_s = -x_s; use unsigned magnitude next
            dx <= $unsigned(snakes_x[i_snake]); // magnitude
            dy <= ($unsigned(cand_y) >= $unsigned(snakes_y[i_snake]))
                  ? ($unsigned(cand_y) - $unsigned(snakes_y[i_snake]))
                  : ($unsigned(snakes_y[i_snake]) - $unsigned(cand_y));
            dist2 <= dx * dx + dy * dy;
            if (dist2 < snakes_d2[i_snake]) begin
              cand_safe <= 1'b0;
            end

            // East side check: x1=255
            dx <= 8'd255 - snakes_x[i_snake]; // 255 - x_s
            dy <= ($unsigned(cand_y) >= $unsigned(snakes_y[i_snake]))
                  ? ($unsigned(cand_y) - $unsigned(snakes_y[i_snake]))
                  : ($unsigned(snakes_y[i_snake]) - $unsigned(cand_y));
            dist2 <= dx * dx + dy * dy;
            if (dist2 < snakes_d2[i_snake]) begin
              cand_safe <= 1'b0;
            end
          end

          // Next snake index
          if (i_snake < (load_count - 1)) begin
            i_snake <= i_snake + 1'b1;
          end else begin
            // Candidate completed: update best if safe
            if (cand_safe) begin
              // Record the highest (most northerly/highest numeric y) entry and exit
              // We evaluate a candidate only once per 16 cycles
              if (($unsigned(cand_y) > $unsigned(best_entry_y)) &&
                  ($unsigned(cand_y) > $unsigned(best_exit_y))) begin
                best_entry_y <= cand_y;
                best_exit_y <= cand_y;
                found <= 1'b1;
              end
            end
            // Move to next candidate
            if (i_candidate < 4'd15) begin
              i_candidate <= i_candidate + 1'b1;
              i_snake <= 4'd0;
            end else begin
              // All 16 candidates checked; after this cycle, PROCESS completes
              i_candidate <= 4'd0;
              i_snake <= 4'd0;
              // Prepare to leave PROCESS in next clock
              valid_out <= 1'b1;
              bitten <= ~found; // 1 if no safe path, 0 if path exists
              entry_exit <= {best_exit_y, best_entry_y};
              state <= ST_DONE;
            end
          end
        end

        ST_DONE: begin
          // Hold outputs until next start; valid_out remains high for one cycle (as per spec event)
          valid_out <= 1'b1;
          bitten <= bitten;
          entry_exit <= entry_exit;
        end

        default: state <= ST_IDLE;
      endcase
    end
  end

  // Helper function (combinational) for west x=0 (constant)
  function [7:0] cand_x0();
    cand_x0 = 8'd0;
  endfunction

  // Combinational next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      ST_IDLE:        next_state = start ? ST_LOAD_SNAKES : ST_IDLE;
      ST_LOAD_SNAKES: next_state = (load_ptr >= load_count) ? ST_PROCESS : ST_LOAD_SNAKES;
      ST_PROCESS:     next_state = (proc_counter >= 10'd1023) ? ST_DONE : ST_PROCESS;
      ST_DONE:        next_state = start ? ST_LOAD_SNAKES : ST_DONE; // allow re-run
      default:        next_state = ST_IDLE;
    endcase
  end

endmodule