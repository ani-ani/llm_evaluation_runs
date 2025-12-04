module distinct_char_counter (
  input clk,
  input rst_n,
  input start,
  input [3:0] str_len,
  input [127:0] char_array,
  output reg [4:0] distinct_count,
  output reg done
);

  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t state;
  reg [3:0] index;
  reg [255:0] seen;

  wire [7:0] current_char = char_array[127 - 8*index -:8];
  wire [7:0] upper_char = current_char & 8'hDF;
  wire [255:0] char_mask = 256'b1 << upper_char;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      distinct_count <= '0;
      done <= '0;
      seen <= '0;
      index <= '0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            state <= PROCESSING;
            distinct_count <= '0;
            seen <= '0;
            index <= '0;
          end
        end

        PROCESSING: begin
          if (index < str_len) begin
            if ((seen & char_mask) == 0) begin
              distinct_count <= distinct_count + 1;
              seen <= seen | char_mask;
            end
          end
          index <= index + 1;
          if (index == 4'd15) begin
            state <= DONE;
          end
        end

        DONE: begin
          done <= 1;
          state <= IDLE;
        end
      endcase
    end
  end

endmodule