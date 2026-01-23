module list_splitter (
  input clk,
  input rst_n,
  input start,
  input [3:0] step,
  input [4:0] num_elements,
  input [7:0] data_in,
  input data_valid,
  output reg [1:0] buffer_id,
  output reg [4:0] buffer_index,
  output reg [7:0] data_out,
  output reg write_enable,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    READ_ELEMENT,
    PROCESS,
    COMPLETE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [4:0] element_counter;
  reg [4:0] index_counter;

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      element_counter <= 0;
      index_counter <= 0;
      buffer_id <= 0;
      buffer_index <= 0;
      data_out <= 0;
      write_enable <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;

      // State transitions
      case (current_state)
        IDLE: begin
          if (start) begin
            element_counter <= 0;
            index_counter <= 0;
            next_state <= READ_ELEMENT;
          end
        end

        READ_ELEMENT: begin
          if (data_valid) begin
            next_state <= PROCESS;
          end
        end

        PROCESS: begin
          if (element_counter == num_elements - 1) begin
            next_state <= COMPLETE;
          end else begin
            next_state <= READ_ELEMENT;
          end
        end

        COMPLETE: begin
          if (start) begin
            next_state <= IDLE;
          end
        end

        default: next_state <= IDLE;
      endcase

      // Output logic
      case (current_state)
        IDLE: begin
          buffer_id <= 0;
          buffer_index <= 0;
          data_out <= 0;
          write_enable <= 0;
          done <= 0;
        end

        READ_ELEMENT: begin
          if (data_valid) begin
            data_out <= data_in;
            write_enable <= 1;
          end else begin
            write_enable <= 0;
          end
        end

        PROCESS: begin
          buffer_id <= index_counter % step;
          buffer_index <= index_counter / step;
          write_enable <= 0;
          done <= 0;
          
          if (element_counter == num_elements - 1) begin
            done <= 1;
          end
          
          element_counter <= element_counter + 1;
          index_counter <= index_counter + 1;
        end

        COMPLETE: begin
          buffer_id <= 0;
          buffer_index <= 0;
          data_out <= 0;
          write_enable <= 0;
          done <= 1;
        end

        default: begin
          buffer_id <= 0;
          buffer_index <= 0;
          data_out <= 0;
          write_enable <= 0;
          done <= 0;
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
          next_state = READ_ELEMENT;
        end
      end

      READ_ELEMENT: begin
        if (data_valid) begin
          next_state = PROCESS;
        end
      end

      PROCESS: begin
        if (element_counter == num_elements - 1) begin
          next_state = COMPLETE;
        end else begin
          next_state = READ_ELEMENT;
        end
      end

      COMPLETE: begin
        if (start) begin
          next_state = IDLE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

endmodule