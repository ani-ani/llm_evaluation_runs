module rolling_max (
  input clk,
  input rst_n,
  input start,
  input [2:0] array_len,
  input [7:0] input_array [0:7],
  output reg [7:0] result,
  output reg [2:0] index,
  output reg done,
  output reg valid
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [7:0] max_val;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      index <= 0;
      max_val <= 0;
      result <= 0;
      done <= 0;
      valid <= 0;
    end else begin
      current_state <= next_state;
      
      case (current_state)
        IDLE: begin
          if (start) begin
            index <= 0;
            max_val <= input_array[0];
            result <= input_array[0];
            valid <= 1;
            done <= 0;
          end
        end
        
        PROCESSING: begin
          if (index == array_len - 1) begin
            // Last element processed
            done <= 1;
            valid <= 0;
          end else begin
            index <= index + 1;
            if (input_array[index] > max_val) begin
              max_val <= input_array[index];
            end
            result <= max_val;
            valid <= 1;
            done <= 0;
          end
        end
        
        DONE: begin
          done <= 1;
          valid <= 0;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    
    case (current_state)
      IDLE: begin
        if (start) begin
          if (array_len == 0) begin
            next_state = DONE;
          end else begin
            next_state = PROCESSING;
          end
        end
      end
      
      PROCESSING: begin
        if (index == array_len - 1) begin
          next_state = DONE;
        end
      end
      
      DONE: begin
        if (!rst_n) begin
          next_state = IDLE;
        end
      end
    endcase
  end

endmodule