module max_executives(
  input clk,
  input rst_n,
  input start,
  input [3:0] N,
  input [15:0] bananas [0:7],
  output reg [3:0] k,
  output reg done
);
  // State encoding
  localparam IDLE = 3'b000;
  localparam INIT = 3'b001;
  localparam ACCUM = 3'b010;
  localparam COMPARE = 3'b011;
  localparam DONE = 3'b100;

  // Internal registers
  reg [2:0] state, next_state;
  reg [15:0] current_sum;
  reg [15:0] last_sum;
  reg [2:0] index;
  reg [3:0] valid_segments;
  reg start_d;
  wire start_pulse = start && !start_d;

  // Synchronous state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_sum <= 16'b0;
      last_sum <= 16'b0;
      index <= 3'b0;
      valid_segments <= 4'b0;
      k <= 4'b0;
      done <= 1'b0;
      start_d <= 1'b0;
    end else begin
      // Capture start signal
      start_d <= start;

      // Default: keep next_state unchanged
      next_state <= state;

      // State machine logic
      case (state)
        IDLE: begin
          if (start_pulse) next_state <= INIT;
        end
        INIT: begin
          // Reset all counters
          current_sum <= 16'b0;
          last_sum <= 16'b0;
          index <= 3'b0;
          valid_segments <= 4'b0;
          next_state <= ACCUM;
        end
        ACCUM: begin
          // Accumulate bananas[index] into current_sum
          current_sum <= current_sum + bananas[index];
          next_state <= COMPARE;
        end
        COMPARE: begin
          if (current_sum >= last_sum) begin
            valid_segments <= valid_segments + 1'b1;
            last_sum <= current_sum;
            current_sum <= 16'b0;
          end
          // Determine if the last briefcase has been processed
          if (index == (N - 1)) begin
            next_state <= DONE;
          end else begin
            index <= index + 1'b1;
            next_state <= ACCUM;
          end
        end
        DONE: begin
          // Allow a new start pulse to restart the computation
          if (start_pulse) next_state <= INIT;
          else next_state <= DONE;
        end
        default: next_state <= IDLE;
      endcase

      // Update state
      state <= next_state;

      // Update outputs
      if (next_state == DONE) begin
        k <= valid_segments;
        done <= 1'b1;
      end else begin
        k <= 4'b0;
        done <= 1'b0;
      end
    end
  end

endmodule