module array_sum (
  input clk,
  input rst_n,
  input start,
  input [2:0] array_length,
  input [7:0] array_data [7:0],
  output reg [15:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    LOAD,
    PROCESSING,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [15:0] accumulator;
  reg [2:0] index;
  reg [2:0] cycle_counter;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      accumulator <= 16'b0;
      index <= 3'b0;
      cycle_counter <= 3'b0;
      result <= 16'b0;
      done <= 1'b0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = LOAD;
      end
      LOAD: begin
        next_state = PROCESSING;
      end
      PROCESSING: begin
        if (index == array_length - 1) begin
          next_state = DONE;
        end
      end
      DONE: begin
        if (cycle_counter == 2'd1) begin
          next_state = IDLE;
        end
      end
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      accumulator <= 16'b0;
      index <= 3'b0;
      cycle_counter <= 3'b0;
      result <= 16'b0;
      done <= 1'b0;
    end else begin
      case (current_state)
        LOAD: begin
          accumulator <= 16'b0;
          index <= 3'b0;
          cycle_counter <= 3'b0;
          done <= 1'b0;
        end
        PROCESSING: begin
          if (index < array_length) begin
            accumulator <= accumulator + array_data[index];
            index <= index + 1'b1;
          end
        end
        DONE: begin
          if (cycle_counter == 2'd0) begin
            result <= accumulator;
            done <= 1'b1;
            cycle_counter <= cycle_counter + 1'b1;
          end else if (cycle_counter == 2'd1) begin
            cycle_counter <= cycle_counter + 1'b1;
          end
        end
        default: begin
          result <= 16'b0;
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule