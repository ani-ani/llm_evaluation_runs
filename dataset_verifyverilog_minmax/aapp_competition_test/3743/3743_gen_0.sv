module aesthetic_path_colors (
  input reg clk,
  input reg rst_n,
  input reg start,
  input reg [7:0] n,
  output reg [7:0] result,
  output reg done
);

  localparam IDLE = 2'b00;
  localparam FIND_DIVISOR = 2'b01;
  localparam CHECK_POW = 2'b10;
  localparam DONE = 2'b11;

  reg [1:0] state;
  reg [7:0] n_reg;
  reg [7:0] n_temp;
  reg [7:0] divisor;
  reg [4:0] divisor_test; // 2..16 inclusive
  reg found_divisor;
  reg [2:0] div_counter;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      n_reg <= 8'b0;
      n_temp <= 8'b0;
      divisor <= 8'b0;
      divisor_test <= 5'b0;
      found_divisor <= 1'b0;
      div_counter <= 3'b0;
      result <= 8'b0;
      done <= 1'b0;
    end else begin
      // default holds
      state <= state;
      n_reg <= n_reg;
      n_temp <= n_temp;
      divisor <= divisor;
      divisor_test <= divisor_test;
      found_divisor <= found_divisor;
      div_counter <= div_counter;
      result <= result;
      done <= done;

      case (state)
        IDLE: begin
          if (start) begin
            n_reg <= n;
            n_temp <= n;
            divisor_test <= 5'd2;
            found_divisor <= 1'b0;
            div_counter <= 3'b0;
            result <= 8'b0;
            done <= 1'b0;
            if (n == 8'd1) begin
              result <= 8'd1;
              done <= 1'b1;
              state <= DONE;
            end else begin
              state <= FIND_DIVISOR;
            end
          end
        end

        FIND_DIVISOR: begin
          if (divisor_test > 5'd16) begin
            // No divisor found: n is prime
            result <= n_reg;
            done <= 1'b1;
            state <= DONE;
          end else begin
            if (n_reg % divisor_test == 0) begin
              divisor <= divisor_test;
              found_divisor <= 1'b1;
              state <= CHECK_POW;
            end else begin
              divisor_test <= divisor_test + 1;
            end
          end
        end

        CHECK_POW: begin
          if (n_temp % divisor == 0) begin
            n_temp <= n_temp / divisor;
            div_counter <= div_counter + 1;
            if (n_temp == 8'b1) begin
              result <= divisor;
              done <= 1'b1;
              state <= DONE;
            end
          end else begin
            // Not a pure power of divisor
            result <= 8'd1;
            done <= 1'b1;
            state <= DONE;
          end
        end

        DONE: begin
          if (!start) begin
            done <= 1'b0;
            result <= 8'b0;
            state <= IDLE;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule