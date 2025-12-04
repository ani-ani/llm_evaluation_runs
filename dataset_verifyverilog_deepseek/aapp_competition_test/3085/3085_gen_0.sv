module bracket_converter(
  input clk,
  input rst_n,
  input start,
  input [7:0] input_str,
  output reg [511:0] output_buf,
  output reg [5:0] output_len,
  output reg done
);

  typedef enum logic [1:0] {IDLE, PROCESSING, DONE} state_t;
  state_t state;

  reg [2:0] stack [0:3];
  reg [1:0] sp;
  reg [3:0] count;
  reg op;
  reg [5:0] write_ptr;

  wire [2:0] char_index = count[3:1];
  wire current_char = input_str[char_index];

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      sp <= 2'b0;
      count <= 4'b0;
      write_ptr <= 6'b0;
      output_buf <= 512'b0;
      output_len <= 6'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PROCESSING;
            done <= 1'b0;
            sp <= 2'b0;
            count <= 4'b0;
            write_ptr <= 6'b0;
            output_buf <= 512'b0;
          end
        end

        PROCESSING: begin
          if (count[0]) begin // Odd cycle (pop/push)
            if (op) begin // Push
              stack[sp] <= char_index;
              sp <= sp + 1;
            end else begin // Pop
              sp <= sp - 1;
              output_buf[write_ptr*8 +: 32] <= {8'h30 + stack[sp-1], 8'h2C, 8'h30 + char_index, 8'h3A};
              write_ptr <= write_ptr + 4;
            end
          end else begin // Even cycle (evaluate)
            op <= current_char;
          end

          if (count == 4'd15) begin
            state <= DONE;
          end else begin
            count <= count + 1;
          end
        end

        DONE: begin
          done <= 1'b1;
          output_len <= write_ptr;
          if (start) begin
            state <= PROCESSING;
            done <= 1'b0;
            sp <= 2'b0;
            count <= 4'b0;
            write_ptr <= 6'b0;
            output_buf <= 512'b0;
          end
        end
      endcase
    end
  end
endmodule