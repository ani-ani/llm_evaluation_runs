module group_trip_solver(
  input clk,
  input rst_n,
  input start,
  input [2:0] k,
  input [2:0] preferences [0:7],
  output reg [3:0] max_count,
  output reg done
);

  // State encoding
  localparam IDLE    = 3'd0;
  localparam ITERATE = 3'd1;
  localparam CHECK   = 3'd2;
  localparam COMPARE = 3'd3;
  localparam DONE    = 3'd4;

  reg [2:0] state, next_state;

  reg [7:0] subset;
  reg [8:0] cycle_cnt;          // To count up to at least 260 cycles if desired (not strictly needed for FSM)

  reg [3:0] current_count;
  reg       valid_subset;

  reg [2:0] check_idx;
  reg       iterating_dependencies;

  // Combinational: next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = ITERATE;
      end

      ITERATE: begin
        // Set up for dependency checking
        next_state = CHECK;
      end

      CHECK: begin
        // Wait until all dependencies checked
        if (!iterating_dependencies)
          next_state = COMPARE;
      end

      COMPARE: begin
        if (subset == 8'hFF)
          next_state = DONE;
        else
          next_state = ITERATE;
      end

      DONE: begin
        // Stay in DONE until reset or new start; requirement specifies done at 260 cycles.
        // We will hold DONE; external logic may deassert start/reset as needed.
        next_state = DONE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Count the number of set bits in subset (combinational)
  function automatic [3:0] popcount8(input [7:0] x);
    begin
      popcount8 = x[0] + x[1] + x[2] + x[3] + x[4] + x[5] + x[6] + x[7];
    end
  endfunction

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state                 <= IDLE;
      subset                <= 8'd0;
      max_count             <= 4'd0;
      done                  <= 1'b0;
      cycle_cnt             <= 9'd0;
      current_count         <= 4'd0;
      valid_subset          <= 1'b0;
      check_idx             <= 3'd0;
      iterating_dependencies<= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done          <= 1'b0;
          max_count     <= 4'd0;
          subset        <= 8'd0;
          cycle_cnt     <= 9'd0;
          current_count <= 4'd0;
          valid_subset  <= 1'b0;
          check_idx     <= 3'd0;
          iterating_dependencies <= 1'b0;
          if (start) begin
            // Start counting from subset 0 at next state
            cycle_cnt <= 9'd1; // first active cycle after start
          end
        end

        ITERATE: begin
          // Setup for checking current subset
          cycle_cnt <= cycle_cnt + 9'd1;
          valid_subset <= 1'b1;           // assume valid until proven otherwise
          check_idx <= 3'd0;
          iterating_dependencies <= 1'b1; // start dependency iteration
          current_count <= 4'd0;          // will be updated after dependencies check
        end

        CHECK: begin
          cycle_cnt <= cycle_cnt + 9'd1;
          if (iterating_dependencies) begin
            // Check dependency for participant check_idx
            if (subset[check_idx]) begin
              // preference index must be included in subset
              if (!subset[preferences[check_idx]]) begin
                valid_subset <= 1'b0;
              end
            end

            if (check_idx == 3'd7) begin
              iterating_dependencies <= 1'b0;
              // After finishing all checks in this cycle, compute size
              current_count <= popcount8(subset);
            end else begin
              check_idx <= check_idx + 3'd1;
            end
          end
        end

        COMPARE: begin
          cycle_cnt <= cycle_cnt + 9'd1;
          // Check bus capacity and update max_count if valid
          if (valid_subset && (current_count <= k)) begin
            if (current_count > max_count)
              max_count <= current_count;
          end

          // Move to next subset
          if (subset != 8'hFF)
            subset <= subset + 8'd1;
        end

        DONE: begin
          // Signal done after all subsets have been processed.
          done <= 1'b1;
          // cycle_cnt can continue or hold; not strictly necessary
          cycle_cnt <= cycle_cnt; // hold
        end

        default: begin
          // Fallback safe state
          state <= IDLE;
        end
      endcase
    end
  end

endmodule