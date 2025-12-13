module max_diff_calculator(
  input  logic              clk,
  input  logic              rst_n,
  input  logic              start,
  input  logic signed [7:0] arr [7:0],
  output reg        [8:0]  max_diff,
  output reg               done
);

  // State encoding
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    RUN   = 2'b01,
    DONE  = 2'b10
  } state_t;

  state_t           state, next_state;
  reg signed [7:0]  min_val, max_val;
  reg        [2:0]  idx; // counts from 0 to 7

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state    <= IDLE;
      min_val  <= '0;
      max_val  <= '0;
      idx      <= 3'd0;
      max_diff <= 9'd0;
      done     <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Initialize with first element
            min_val <= arr[0];
            max_val <= arr[0];
            idx     <= 3'd1; // next index to process
          end
        end

        RUN: begin
          // Process one element per cycle
          if (idx < 3'd8) begin
            if (arr[idx] < min_val)
              min_val <= arr[idx];
            if (arr[idx] > max_val)
              max_val <= arr[idx];
            idx <= idx + 3'd1;
          end
        end

        DONE: begin
          // Hold done high for one cycle, values already computed
          done <= 1'b0;
        end

        default: begin
        end
      endcase

      // Compute outputs on state transitions where needed
      if (state == RUN && idx == 3'd7) begin
        // Next cycle (after last element processed) compute result
        // Note: use updated min/max after processing idx=7
        // The computation is combinational w.r.t. min_val/max_val here
        // but registered into max_diff below on this same clock edge
        if (arr[idx] < min_val)
          min_val <= arr[idx];
        if (arr[idx] > max_val)
          max_val <= arr[idx];
      end

      // When entering DONE state, compute and assert done
      if (state == RUN && next_state == DONE) begin
        max_diff <= max_val - min_val;
        done     <= 1'b1;
      end
    end
  end

  // Next state logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = RUN;
      end

      RUN: begin
        if (idx == 3'd8) begin
          next_state = DONE;
        end
      end

      DONE: begin
        // Single-cycle done pulse, then return to IDLE
        next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule