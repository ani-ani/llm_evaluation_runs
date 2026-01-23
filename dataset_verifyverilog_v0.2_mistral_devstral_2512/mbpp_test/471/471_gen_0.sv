module find_remainder (
  input clk,
  input rst_n,
  input start,
  input [7:0] n,
  input [2:0] arr_len,
  input [7:0] arr [0:7],
  output reg [7:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [2:0] index;
  reg [15:0] accumulator;
  reg [15:0] temp;
  reg [7:0] current_element;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      index <= 0;
      accumulator <= 1;
      result <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = PROCESSING;
        else next_state = IDLE;
      end
      PROCESSING: begin
        if (index == arr_len - 1) next_state = DONE;
        else next_state = PROCESSING;
      end
      DONE: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      index <= 0;
      accumulator <= 1;
      result <= 0;
      done <= 0;
    end else begin
      case (current_state)
        IDLE: begin
          if (start) begin
            index <= 0;
            accumulator <= 1;
            done <= 0;
          end
        end
        PROCESSING: begin
          current_element = arr[index];
          // Compute temp = (current_element % n)
          if (n == 1) temp = 0;
          else temp = current_element % n;
          // Compute accumulator = (accumulator * temp) % n
          if (n == 1) accumulator <= 0;
          else accumulator <= (accumulator * temp) % n;
          // Increment index
          if (index == arr_len - 1) begin
            index <= 0;
          end else begin
            index <= index + 1;
          end
        end
        DONE: begin
          result <= accumulator[7:0];
          done <= 1;
        end
      endcase
    end
  end

endmodule