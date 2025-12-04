module pita_pizza_calculator(
  input clk,
  input rst_n,
  input start,
  input [13:0] total_profit,
  input [9:0] pita_profit,
  input [9:0] pizza_profit,
  output reg [6:0] pita_count,
  output reg [6:0] pizza_count,
  output reg valid,
  output reg done
);

  typedef enum {IDLE, CHECK, DONE} state_t;
  state_t state;

  reg [6:0] pita_count_reg;
  wire [16:0] product = pita_count_reg * pita_profit;
  wire signed [16:0] temp_signed = $signed({3'b0, total_profit}) - $signed(product);
  wire temp_ge_0 = (temp_signed >= 0);
  wire [16:0] temp_unsigned = temp_ge_0 ? temp_signed : 16'd0;
  wire [16:0] remainder = temp_unsigned % pizza_profit;
  wire [16:0] pizza_count_calc = temp_unsigned / pizza_profit;
  wire pizza_count_le100 = (pizza_count_calc <= 17'd100);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      pita_count_reg <= 7'd0;
      valid <= 1'b0;
      done <= 1'b0;
      pita_count <= 7'd0;
      pizza_count <= 7'd0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          valid <= 1'b0;
          if (start) begin
            state <= CHECK;
            pita_count_reg <= 7'd0;
          end
        end

        CHECK: begin
          valid <= 1'b0;

          if (temp_ge_0 && (remainder == 0) && pizza_count_le100) begin
            valid <= 1'b1;
            pita_count <= pita_count_reg;
            pizza_count <= pizza_count_calc[6:0];
          end

          if (pita_count_reg == 7'd100)
            state <= DONE;
          else
            pita_count_reg <= pita_count_reg + 1'b1;
        end

        DONE: begin
          done <= 1'b1;
          if (start)
            state <= IDLE;
        end
      endcase
    end
  end
endmodule