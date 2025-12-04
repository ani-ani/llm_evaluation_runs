module simple_power (
  input clk,
  input rst_n,
  input start,
  input [15:0] x,
  input [15:0] n,
  output reg result,
  output reg done
);

  localparam IDLE = 1'b0;
  localparam COMPUTING = 1'b1;

  reg state;
  reg [15:0] power_reg;
  reg [4:0] k_count;

  wire [31:0] product_full = power_reg * n;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      power_reg <= 0;
      k_count <= 0;
      result <= 0;
      done <= 0;
    end else begin
      state <= state_next;
      power_reg <= power_reg_next;
      k_count <= k_count_next;
      result <= result_next;
      done <= done_next;
    end
  end

  always_comb begin
    state_next = state;
    power_reg_next = power_reg;
    k_count_next = k_count;
    result_next = result;
    done_next = done;

    case (state)
      IDLE: begin
        if (start) begin
          if (x == 1) begin
            result_next = 1;
            done_next = 1;
            state_next = IDLE;
          end else begin
            state_next = COMPUTING;
            power_reg_next = 16'd1;
            k_count_next = 0;
            result_next = 0;
            done_next = 0;
          end
        end else begin
          done_next = 0;
          state_next = IDLE;
        end
      end
      COMPUTING: begin
        if (k_count < 16) begin
          if (product_full[31:16] != 0) begin
            state_next = IDLE;
            result_next = 0;
            done_next = 1;
            k_count_next = k_count + 1;
          end else if (product_full[15:0] == x) begin
            state_next = IDLE;
            result_next = 1;
            done_next = 1;
            k_count_next = k_count + 1;
          end else if (k_count == 15) begin
            state_next = IDLE;
            result_next = 0;
            done_next = 1;
            k_count_next = 16;
          end else begin
            power_reg_next = product_full[15:0];
            k_count_next = k_count + 1;
            result_next = 0;
            done_next = 0;
            state_next = COMPUTING;
          end
        end
      end
    endcase
  end
endmodule