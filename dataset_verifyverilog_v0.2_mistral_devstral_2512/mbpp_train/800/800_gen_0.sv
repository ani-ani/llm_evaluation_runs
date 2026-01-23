module remove_all_spaces (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input input_valid,
  input input_done,
  output reg [7:0] output_char,
  output reg output_valid,
  output reg done
);

  parameter BUFFER_SIZE = 16;

  typedef enum logic [1:0] {
    IDLE,
    COLLECT,
    PROCESS,
    COMPLETE
  } state_t;

  state_t current_state, next_state;

  reg [7:0] buffer [0:BUFFER_SIZE-1];
  reg [3:0] input_ptr;
  reg [3:0] output_ptr;
  reg [3:0] buffer_length;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      input_ptr <= 0;
      output_ptr <= 0;
      buffer_length <= 0;
      output_valid <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  always @(*) begin
    next_state = current_state;
    output_valid = 0;
    done = 0;

    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = COLLECT;
          input_ptr = 0;
          buffer_length = 0;
        end
      end

      COLLECT: begin
        if (input_valid) begin
          buffer[input_ptr] = char_in;
          input_ptr = input_ptr + 1;
          buffer_length = input_ptr;
        end

        if (input_done) begin
          next_state = PROCESS;
          output_ptr = 0;
        end
      end

      PROCESS: begin
        if (output_ptr < buffer_length) begin
          if (buffer[output_ptr] != 8'h20 && 
              buffer[output_ptr] != 8'h09 && 
              buffer[output_ptr] != 8'h0A && 
              buffer[output_ptr] != 8'h0D) begin
            output_char = buffer[output_ptr];
            output_valid = 1;
          end
          output_ptr = output_ptr + 1;
        end else begin
          next_state = COMPLETE;
        end
      end

      COMPLETE: begin
        done = 1;
        if (!start) begin
          next_state = IDLE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

endmodule