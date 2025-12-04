module aesthetic_path_colors(
  input clk,
  input rst_n,
  input start,
  input [7:0] n,
  output reg [7:0] result,
  output reg done
);

  localparam [1:0] IDLE = 2'b00;
  localparam [1:0] FIND_DIVISOR = 2'b01;
  localparam [1:0] CHECK_POW = 2'b10;
  localparam [1:0] DONE_STATE = 2'b11;

  reg [1:0] state, next_state;
  reg [7:0] n_reg, d_reg, temp_n, divisor;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 8'd0;
      done <= 1'b0;
      n_reg <= 8'd0;
      d_reg <= 8'd0;
      temp_n <= 8'd0;
      divisor <= 8'd0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            if (n == 8'd1) begin
              result <= 8'd1;
              done <= 1'b1;
              state <= DONE_STATE;
            end else begin
              n_reg <= n;
              d_reg <= 8'd2;
              state <= FIND_DIVISOR;
            end
          end
        end

        FIND_DIVISOR: begin
          if (d_reg > 8'd15 || d_reg * d_reg > n_reg) begin
            result <= n_reg;
            done <= 1'b1;
            state <= DONE_STATE;
          end else if (n_reg % d_reg == 8'd0) begin
            divisor <= d_reg;
            temp_n <= n_reg;
            state <= CHECK_POW;
          end else begin
            d_reg <= d_reg + 8'd1;
          end
        end

        CHECK_POW: begin
          if (temp_n % divisor == 8'd0) begin
            temp_n <= temp_n / divisor;
          end else begin
            if (temp_n == 8'd1) result <= divisor;
            else result <= 8'd1;
            done <= 1'b1;
            state <= DONE_STATE;
          end
        end

        DONE_STATE: begin
          if (start) begin
            done <= 1'b0;
            if (n == 8'd1) begin
              result <= 8'd1;
              done <= 1'b1;
            end else begin
              n_reg <= n;
              d_reg <= 8'd2;
              state <= FIND_DIVISOR;
            end
          end
        end
      endcase
    end
  end

endmodule