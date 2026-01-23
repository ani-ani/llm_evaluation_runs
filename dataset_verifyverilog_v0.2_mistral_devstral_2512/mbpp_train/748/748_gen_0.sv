module capital_words_spaces (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input [3:0] char_index,
  input input_valid,
  output reg [7:0] char_out,
  output reg [3:0] out_index,
  output reg output_valid,
  output reg done
);

  parameter MAX_LEN = 16;
  parameter IDLE = 3'b000;
  parameter LOAD = 3'b001;
  parameter PROCESS = 3'b010;
  parameter INSERT_SPACE = 3'b011;
  parameter DONE = 3'b100;

  reg [7:0] char_buffer [0:MAX_LEN-1];
  reg [3:0] load_ptr;
  reg [3:0] process_ptr;
  reg [3:0] out_ptr;
  reg [2:0] state, next_state;
  reg prev_was_upper;
  reg space_pending;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      load_ptr <= 0;
      process_ptr <= 0;
      out_ptr <= 0;
      prev_was_upper <= 0;
      space_pending <= 0;
      done <= 0;
      output_valid <= 0;
      char_out <= 0;
      out_index <= 0;
    end else begin
      state <= next_state;
    end
  end

  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = LOAD;
      end
      LOAD: begin
        if (char_index == MAX_LEN-1 && input_valid) next_state = PROCESS;
      end
      PROCESS: begin
        if (process_ptr == MAX_LEN-1) begin
          if (space_pending) next_state = INSERT_SPACE;
          else next_state = DONE;
        end
      end
      INSERT_SPACE: begin
        next_state = PROCESS;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      load_ptr <= 0;
      process_ptr <= 0;
      out_ptr <= 0;
      prev_was_upper <= 0;
      space_pending <= 0;
    end else begin
      case (state)
        LOAD: begin
          if (input_valid) begin
            char_buffer[char_index] <= char_in;
            if (char_index == MAX_LEN-1) begin
              load_ptr <= 0;
              process_ptr <= 0;
              out_ptr <= 0;
              prev_was_upper <= 0;
              space_pending <= 0;
            end
          end
        end
        PROCESS: begin
          if (process_ptr < MAX_LEN) begin
            reg is_upper = (char_buffer[process_ptr] >= 8'h41 && char_buffer[process_ptr] <= 8'h5A);
            if (is_upper && !prev_was_upper && process_ptr != 0) begin
              space_pending <= 1;
            end else begin
              space_pending <= 0;
            end
            prev_was_upper <= is_upper;
            process_ptr <= process_ptr + 1;
          end
        end
        INSERT_SPACE: begin
          space_pending <= 0;
        end
      endcase
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      output_valid <= 0;
      char_out <= 0;
      out_index <= 0;
    end else begin
      case (state)
        PROCESS: begin
          if (space_pending) begin
            char_out <= 8'h20;
            out_index <= out_ptr;
            output_valid <= 1;
            out_ptr <= out_ptr + 1;
          end else begin
            char_out <= char_buffer[process_ptr];
            out_index <= out_ptr;
            output_valid <= 1;
            out_ptr <= out_ptr + 1;
          end
        end
        INSERT_SPACE: begin
          char_out <= char_buffer[process_ptr];
          out_index <= out_ptr;
          output_valid <= 1;
          out_ptr <= out_ptr + 1;
        end
        DONE: begin
          output_valid <= 0;
          done <= 1;
        end
        default: begin
          output_valid <= 0;
          done <= 0;
        end
      endcase
    end
  end

endmodule