module bracket_converter (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input [3:0] char_valid,
  output reg [63:0] result,
  output reg [3:0] result_len,
  output reg done,
  output reg error
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    READ_CHARS,
    PROCESS,
    OUTPUT
  } state_t;

  state_t state;
  reg [2:0] stack_ptr;
  reg [7:0] stack [0:7];
  reg [7:0] char_buffer [0:7];
  reg [3:0] buffer_ptr;
  reg [7:0] current_index;
  reg [7:0] header_buffer [0:7];
  reg [3:0] header_ptr;
  reg [7:0] char_count;
  reg [7:0] open_count;
  reg [7:0] close_count;
  reg [7:0] output_ptr;
  reg [7:0] cycle_count;

  // Initialize all registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      stack_ptr <= 0;
      buffer_ptr <= 0;
      current_index <= 0;
      header_ptr <= 0;
      char_count <= 0;
      open_count <= 0;
      close_count <= 0;
      output_ptr <= 0;
      cycle_count <= 0;
      result <= 0;
      result_len <= 0;
      done <= 0;
      error <= 0;
      for (int i = 0; i < 8; i = i + 1) begin
        stack[i] <= 0;
        char_buffer[i] <= 0;
        header_buffer[i] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= READ_CHARS;
            cycle_count <= 0;
          end
        end
        READ_CHARS: begin
          if (char_valid) begin
            if (char_in == 8'h28) begin // '('
              if (stack_ptr < 8) begin
                stack[stack_ptr] <= current_index;
                stack_ptr <= stack_ptr + 1;
                open_count <= open_count + 1;
              end else begin
                error <= 1;
                state <= OUTPUT;
              end
            end else if (char_in == 8'h29) begin // ')'
              if (stack_ptr > 0) begin
                stack_ptr <= stack_ptr - 1;
                close_count <= close_count + 1;
              end else begin
                error <= 1;
                state <= OUTPUT;
              end
            end
            char_buffer[buffer_ptr] <= char_in;
            buffer_ptr <= buffer_ptr + 1;
            current_index <= current_index + 1;
          end
          cycle_count <= cycle_count + 1;
          if (cycle_count >= 50) begin
            state <= PROCESS;
          end
        end
        PROCESS: begin
          if (header_ptr < open_count) begin
            header_buffer[header_ptr] <= {stack[header_ptr], 8'h2c, stack[header_ptr], 8'h3a};
            header_ptr <= header_ptr + 1;
          end else begin
            state <= OUTPUT;
          end
        end
        OUTPUT: begin
          if (output_ptr < header_ptr) begin
            result[output_ptr*8 +: 8] <= header_buffer[output_ptr];
            output_ptr <= output_ptr + 1;
          end else begin
            result_len <= header_ptr;
            done <= 1;
          end
        end
      endcase
    end
  end

endmodule