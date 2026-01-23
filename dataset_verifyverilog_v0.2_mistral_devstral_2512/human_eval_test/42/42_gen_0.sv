module incr_list (
  input clk,
  input rst_n,
  input start,
  input [2:0] length,
  input [7:0] data_in,
  input data_in_valid,
  output reg [7:0] data_out,
  output reg data_out_valid,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [7:0] data_array [0:7];
  reg [2:0] read_ptr;
  reg [2:0] write_ptr;
  reg [2:0] count;
  reg [7:0] temp_data;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      read_ptr <= 0;
      write_ptr <= 0;
      count <= 0;
      data_out <= 0;
      data_out_valid <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
      
      case (current_state)
        IDLE: begin
          if (start) begin
            read_ptr <= 0;
            write_ptr <= 0;
            count <= 0;
            data_out_valid <= 0;
            done <= 0;
          end
        end
        
        PROCESSING: begin
          if (data_in_valid && (count < length)) begin
            data_array[write_ptr] <= data_in;
            write_ptr <= write_ptr + 1;
            count <= count + 1;
          end
          
          if (count > 0 && (read_ptr < count)) begin
            temp_data <= data_array[read_ptr] + 1;
            read_ptr <= read_ptr + 1;
          end
        end
        
        DONE: begin
          done <= 1;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    
    case (current_state)
      IDLE: begin
        if (start) next_state = PROCESSING;
      end
      
      PROCESSING: begin
        if (count == length && read_ptr == count) begin
          next_state = DONE;
        end
      end
      
      DONE: begin
        if (start) next_state = PROCESSING;
        else next_state = IDLE;
      end
    endcase
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      data_out <= 0;
      data_out_valid <= 0;
    end else begin
      case (current_state)
        IDLE: begin
          data_out <= 0;
          data_out_valid <= 0;
        end
        
        PROCESSING: begin
          if (count > 0 && (read_ptr > 0)) begin
            data_out <= temp_data;
            data_out_valid <= 1;
          end else begin
            data_out <= 0;
            data_out_valid <= 0;
          end
        end
        
        DONE: begin
          data_out <= 0;
          data_out_valid <= 0;
        end
      endcase
    end
  end

endmodule