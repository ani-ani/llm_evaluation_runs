module divisible_by_11 (
  input clk,
  input rst_n,
  input start,
  input [31:0] number,
  output reg result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t state;
  reg [3:0] remainder;
  reg [4:0] bit_counter;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      remainder <= 0;
      bit_counter <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PROCESSING;
            remainder <= 0;
            bit_counter <= 31;
            done <= 0;
          end
        end
        PROCESSING: begin
          if (bit_counter == 0) begin
            state <= DONE;
            result <= (remainder == 0);
            done <= 1;
          end else begin
            remainder <= remainder * 2 + number[bit_counter];
            if (remainder >= 11) begin
              remainder <= remainder - 11;
            end
            bit_counter <= bit_counter - 1;
          end
        end
        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule