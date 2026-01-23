module min_people_finder (
  input clk,
  input rst_n,
  input start,
  input [63:0] events,
  input [5:0] length,
  output reg [7:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    CALCULATE,
    DONE
  } state_t;

  state_t state;
  reg [5:0] loop_counter;
  reg [7:0] running_counter;
  reg [7:0] min_val;
  reg [7:0] max_val;

  // Reset state
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      loop_counter <= 0;
      running_counter <= 0;
      min_val <= 0;
      max_val <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PROCESSING;
            loop_counter <= 0;
            running_counter <= 0;
            min_val <= 0;
            max_val <= 0;
          end
        end
        PROCESSING: begin
          if (loop_counter < length) begin
            if (events[63 - loop_counter]) begin
              running_counter <= running_counter + 1;
            end else begin
              running_counter <= running_counter - 1;
            end
            if (running_counter < min_val) begin
              min_val <= running_counter;
            end
            if (running_counter > max_val) begin
              max_val <= running_counter;
            end
            loop_counter <= loop_counter + 1;
          end else begin
            state <= CALCULATE;
          end
        end
        CALCULATE: begin
          result <= max_val - min_val;
          state <= DONE;
        end
        DONE: begin
          done <= 1;
          if (start) begin
            state <= PROCESSING;
            loop_counter <= 0;
            running_counter <= 0;
            min_val <= 0;
            max_val <= 0;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule