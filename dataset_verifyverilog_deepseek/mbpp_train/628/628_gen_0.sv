module space_replacer(
  input clk,
  input rst_n,
  input start,
  input [127:0] in_str,
  output reg done,
  output reg [383:0] out_str
);

  typedef enum {IDLE, PROCESSING, DONE} state_t;
  state_t state;

  reg [3:0] char_count;
  reg [5:0] out_ptr;
  wire [7:0] current_char;

  assign current_char = in_str[char_count*8 +:8];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      out_str <= 0;
      char_count <= 0;
      out_ptr <= 0;
    end else begin
      case(state)
        IDLE: begin
          done <= 0;
          if (start) begin
            state <= PROCESSING;
            out_str <= 0;
            char_count <= 0;
            out_ptr <= 0;
          end
        end

        PROCESSING: begin
          if (current_char == 8'h20) begin
            out_str[out_ptr*8 +:24] <= {8'h25, 8'h32, 8'h30};
            out_ptr <= out_ptr + 3;
          end else begin
            out_str[out_ptr*8 +:8] <= current_char;
            out_ptr <= out_ptr + 1;
          end

          if (char_count == 15) begin
            state <= DONE;
          end
          char_count <= char_count + 1;
        end

        DONE: begin
          done <= 1;
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule
