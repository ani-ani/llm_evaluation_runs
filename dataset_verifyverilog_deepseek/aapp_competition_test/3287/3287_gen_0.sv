module loot_divider(
  input clk,
  input rst_n,
  input start,
  input [2:0] k,
  input [7:0] x [7:0],
  output reg [31:0] left_behind,
  output reg done
);

  typedef enum logic [1:0] {
    IDLE,
    PROCESS,
    DONE
  } state_t;

  state_t state;
  reg [2:0] index;
  reg [7:0] carry_in;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      left_behind <= 0;
      index <= 0;
      carry_in <= 0;
    end else begin
      done <= 0;
      case (state)
        IDLE: begin
          if (start) begin
            state <= PROCESS;
            index <= 0;
            carry_in <= 0;
            left_behind <= 0;
          end
        end
        PROCESS: begin
          automatic reg [7:0] sum = x[index] + carry_in;
          automatic reg is_odd = sum[0];
          automatic reg [7:0] sum_corr = is_odd ? sum - 8'd1 : sum;
          automatic reg [7:0] next_carry = sum_corr >> 1;
          automatic reg [31:0] to_add = is_odd ? (32'd1 << index) : 32'd0;

          left_behind <= left_behind + to_add;
          carry_in <= next_carry;
          index <= index + 3'd1;

          state <= (index == (k - 1)) ? DONE : PROCESS;
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