module vacation_rest_counter(
  input clk,
  input rst_n,
  input start,
  input [4:0] num_days,
  input [1:0] day_status [0:15],
  output reg [4:0] rest_count,
  output reg done
);

  // State encodings
  localparam IDLE = 2'b00;
  localparam PROCESS = 2'b01;
  localparam DONE = 2'b10;

  // Internal signals
  reg [1:0] state, next_state;
  reg [3:0] cycle_count, cycle_count_next;
  reg [1:0] prev_status;
  reg [4:0] rest_count_next;
  reg done_next;

  // State and register update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cycle_count <= 4'd0;
      prev_status <= 2'b00;
      rest_count <= 5'd0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      cycle_count <= cycle_count_next;
      // Reset prev_status when entering PROCESS from another state
      if (state != PROCESS && next_state == PROCESS) begin
        prev_status <= 2'b00;
      end else if (state == PROCESS) begin
        // Store current day's status for next cycle
        prev_status <= day_status[cycle_count];
      end
      rest_count <= rest_count_next;
      done <= done_next;
    end
  end

  // Combinational next-state and output logic
  always_comb begin
    // Default assignments (hold current values)
    next_state = state;
    rest_count_next = rest_count;
    done_next = done;
    cycle_count_next = cycle_count;

    case (state)
      IDLE: begin
        if (start) begin
          next_state = PROCESS;
          rest_count_next = 5'd0;
          done_next = 1'b0;
          cycle_count_next = 4'd0;
        end
      end

      PROCESS: begin
        // Compute rest days only for the days specified by num_days
        if (cycle_count < num_days) begin
          if ((day_status[cycle_count] != 2'b00) && (prev_status != 2'b00)) begin
            rest_count_next = rest_count + 1;
          end else begin
            rest_count_next = rest_count;
          end
        end
        // Increment the cycle counter
        cycle_count_next = cycle_count + 1;
        // After processing 16 days, move to DONE
        if (cycle_count == 4'd15) begin
          next_state = DONE;
          done_next = 1'b1;
        end
      end

      DONE: begin
        done_next = 1'b1;
        // Allow re-start
        if (start) begin
          next_state = PROCESS;
          rest_count_next = 5'd0;
          done_next = 1'b0;
          cycle_count_next = 4'd0;
        end
      end

      default: begin
        // Return to IDLE and reset internal counters
        next_state = IDLE;
        rest_count_next = 5'd0;
        done_next = 1'b0;
        cycle_count_next = 4'd0;
      end
    endcase
  end

endmodule