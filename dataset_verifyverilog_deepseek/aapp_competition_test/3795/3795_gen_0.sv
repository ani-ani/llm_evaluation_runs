module currency_exchange (
  input clk,
  input rst_n,
  input start,
  input [15:0] n,
  input [7:0] d,
  input [7:0] e,
  output reg [15:0] min_rubles,
  output reg done
);

localparam [1:0] IDLE = 2'b00;
localparam [1:0] CALC = 2'b01;
localparam [1:0] DONE = 2'b10;

reg [1:0] state = IDLE;
reg [7:0] i_reg;
reg [16:0] product_reg;
reg [8:0] e5_reg;
reg [15:0] n_reg;
reg [7:0] d_reg;
reg [15:0] min_rubles_reg;

wire [16:0] ext_n_reg = {1'b0, n_reg};
wire [16:0] current_remaining_full = ext_n_reg - product_reg;
wire is_valid = ~current_remaining_full[16];
wire [15:0] current_remaining_trunc = current_remaining_full[15:0];
wire [15:0] remainder16 = current_remaining_trunc % d_reg;

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    done <= 0;
    min_rubles <= 0;
    min_rubles_reg <= 16'hFFFF;
  end else begin
    case(state)
      IDLE: begin
        done <= 0;
        if (start) begin
          n_reg   <= n;
          d_reg   <= d;
          e5_reg  <= 5 * e;
          product_reg <= 17'b0;
          i_reg <= 8'b0;
          min_rubles_reg <= 16'hFFFF;
          state <= CALC;
        end
      end

      CALC: begin
        if (is_valid) begin
          if (remainder16 < min_rubles_reg) begin
            min_rubles_reg <= remainder16;
          end
          if (remainder16 == 16'b0) begin
            state <= DONE;
          end else begin
            wire [16:0] next_product = product_reg + e5_reg;
            wire [16:0] ext_n_17 = {1'b0, n_reg};
            if (i_reg == 8'd255 || next_product > ext_n_17) begin
              state <= DONE;
            end else begin
              i_reg <= i_reg + 8'd1;
              product_reg <= next_product;
              state <= CALC;
            end
          end
        end else begin
          state <= DONE;
        end
      end

      DONE: begin
        min_rubles <= min_rubles_reg;
        done <= 1'b1;
        state <= IDLE;
      end
    endcase
  end
end

endmodule