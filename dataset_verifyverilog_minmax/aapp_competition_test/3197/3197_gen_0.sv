module group_trip_solver(
  input clk,
  input rst_n,
  input start,
  input [2:0] k,
  input [2:0] preferences [0:7],  // 8 participants, each with 3-bit dependency
  output reg [3:0] max_count,
  output reg done
);

  // State machine enum
  typedef enum logic [2:0] {
    IDLE     = 3'd0,
    ITERATE  = 3'd1,
    CHECK    = 3'd2,
    COMPARE  = 3'd3,
    DONE     = 3'd4
  } state_t;

  state_t state, next_state;

  // Iteration control
  reg [7:0] subset;     // 8-bit mask representing current subset (0..255)
  reg [7:0] subset_next;
  reg [8:0] cycle_cnt;  // counts 0..259 (260 cycles)
  reg stay_in_done;     // hold DONE for one extra cycle to meet latency

  // Temporary values captured in CHECK and used in COMPARE
  reg [7:0] subset_r;
  reg [3:0] subset_size_r;
  reg [3:0] current_max_r;
  reg [7:0] dep_mask_r;

  // Popcount for 8-bit vector
  function [3:0] popcount8;
    input [7:0] vec;
    integer i;
    begin
      popcount8 = 4'd0;
      for (i = 0; i < 8; i = i + 1) begin
        if (vec[i]) popcount8 = popcount8 + 1;
      end
    end
  endfunction

  // Build dependency mask for a given participant index using the 3-bit preferences array
  function [7:0] dep_mask_for;
    input [2:0] idx;
    input [2:0] preferences [0:7];
    reg [7:0] mask;
    begin
      mask = 8'h00;
      mask[preferences[0]] = 1'b1;
      mask[preferences[1]] = 1'b1;
      mask[preferences[2]] = 1'b1;
      dep_mask_for = mask;
    end
  endfunction

  // Sequential logic: state update and data registers
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= IDLE;
      subset       <= 8'd0;
      cycle_cnt    <= 9'd0;
      max_count    <= 4'd0;
      done         <= 1'b0;
      stay_in_done <= 1'b0;
      subset_r     <= 8'd0;
      subset_size_r<= 4'd0;
      current_max_r<= 4'd0;
      dep_mask_r   <= 8'd0;
    end else begin
      // Defaults (avoid latches)
      subset       <= subset_next;
      subset_r     <= subset_r;
      subset_size_r<= subset_size_r;
      current_max_r<= current_max_r;
      dep_mask_r   <= dep_mask_r;
      stay_in_done <= stay_in_done;

      // Cycle counter increments when iterating
      if (state == ITERATE) begin
        cycle_cnt <= cycle_cnt + 1;
      end else if (state == IDLE) begin
        cycle_cnt <= 9'd0;
      end

      // State machine
      case (state)
        IDLE: begin
          subset       <= 8'd0;
          max_count    <= 4'd0;
          done         <= 1'b0;
          stay_in_done <= 1'b0;
          if (start) begin
            subset       <= 8'd0;
            cycle_cnt    <= 9'd0;
            current_max_r<= 4'd0;
          end
        end

        ITERATE: begin
          // Move to CHECK in same cycle with current subset
          subset_r     <= subset;
          subset_size_r<= popcount8(subset);
          dep_mask_r   <= dep_mask_for(subset_r, preferences);
          current_max_r<= max_count; // carry-forward current best
          // Advance subset for next cycle
          subset_next  <= subset + 1;
        end

        CHECK: begin
          // All computation done in this cycle; results captured in registers
        end

        COMPARE: begin
          // Update best size if constraints satisfied and size is larger
          if (subset_size_r <= k) begin
            if ((subset_r & dep_mask_r) == subset_r) begin
              if (subset_size_r > max_count) begin
                max_count <= subset_size_r;
              end
            end
          end
        end

        DONE: begin
          done <= 1'b1;
          stay_in_done <= 1'b1;
          if (!stay_in_done) begin
            // In the first DONE cycle, hold outputs as is
          end
        end
      endcase
    end
  end

  // Next-state logic
  always_comb begin
    next_state = state; // default
    case (state)
      IDLE: begin
        if (start) next_state = ITERATE;
        else       next_state = IDLE;
      end

      ITERATE: begin
        next_state = CHECK;
      end

      CHECK: begin
        next_state = COMPARE;
      end

      COMPARE: begin
        if (cycle_cnt >= 9'd260) begin
          next_state = DONE;
        end else begin
          next_state = ITERATE;
        end
      end

      DONE: begin
        // Remain in DONE for one cycle, then go to IDLE
        if (stay_in_done) next_state = IDLE;
        else              next_state = DONE;
      end
    endcase
  end

  // Update state machine state
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

endmodule