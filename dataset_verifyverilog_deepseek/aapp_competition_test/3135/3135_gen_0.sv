module signed_binary_converter(
  input clk,
  input rst_n,
  input start,
  input [7:0] bin_in,
  output reg [15:0] signed_out,
  output reg done
);

  typedef enum logic [1:0] {IDLE, PROCESSING, DONE} state_t;
  state_t state;
  reg [2:0] idx;
  reg carry_in_reg;
  reg next_carry;
  logic current_bit;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      signed_out <= 16'b0;
      carry_in_reg <= 1'b0;
      idx <= 3'b0;
    end else begin
      done <= 1'b0;

      case (state)
        IDLE: begin
          if (start) begin
            state <= PROCESSING;
            carry_in_reg <= 1'b0;
            idx <= 3'b0;
            signed_out <= 16'b0;
          end
        end

        PROCESSING: begin
          current_bit = bin_in[7 - idx] ^ carry_in_reg;
          next_carry = bin_in[7 - idx] & carry_in_reg;

          signed_out[idx*2 +: 2] <= current_bit ? 2'b00 : 
                                    (carry_in_reg ? 2'b01 : 2'b10);

          carry_in_reg <= next_carry;

          if (idx == 7) state <= DONE;
          else idx <= idx + 1;
        end

        DONE: begin
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end

endmodule