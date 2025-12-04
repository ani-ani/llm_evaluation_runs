module non_wool_sequence_counter(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [15:0] m,
  output reg [31:0] result,
  output reg done
);

  localparam MOD_VAL = 32'd1000000009;
  localparam [1:0]
    IDLE    = 2'b00,
    INIT    = 2'b01,
    COMPUTE = 2'b10,
    DONE    = 2'b11;

  reg [1:0] state_reg, state_next;
  reg [31:0] result_reg, result_next;
  reg [3:0] i_reg, i_next;
  reg [31:0] k_reg;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_reg <= IDLE;
      result_reg <= 32'b0;
      i_reg <= 4'b0;
      done <= 1'b0;
    end else begin
      state_reg <= state_next;
      result_reg <= result_next;
      i_reg <= i_next;
      done <= (state_reg == DONE);
    end
  end

  always_comb begin
    state_next = state_reg;
    result_next = result_reg;
    i_next = i_reg;
    k_reg = 0;

    case (state_reg)
      IDLE: begin
        if (start) begin
          state_next = INIT;
        end
      end
      INIT: begin
        k_reg = (32'd1 << m) - 32'd1;
        result_next = 32'd1;
        i_next = 4'd0;
        if (n == 4'd0) begin
          state_next = DONE;
        end else begin
          state_next = COMPUTE;
        end
      end
      COMPUTE: begin
        k_reg = (32'd1 << m) - 32'd1;
        if (i_reg < n) begin
          automatic logic [31:0] temp = k_reg - i_reg;
          automatic logic [63:0] product = result_reg * temp;
          result_next = product % MOD_VAL;
          i_next = i_reg + 1;
        end
        state_next = (i_next == n) ? DONE : COMPUTE;
      end
      DONE: begin
        state_next = IDLE;
      end
      default: state_next = IDLE;
    endcase
  end

  assign result = result_reg;

endmodule