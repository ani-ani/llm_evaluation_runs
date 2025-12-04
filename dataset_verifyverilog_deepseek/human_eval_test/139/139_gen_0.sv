module special_factorial (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  output reg [63:0] result,
  output reg done
);

  localparam [1:0] IDLE        = 2'b00;
  localparam [1:0] COMPUTE_FACT = 2'b01;
  localparam [1:0] MULTIPLY_PROD = 2'b10;
  localparam [1:0] DONE       = 2'b11;

  reg [1:0] state;
  reg [63:0] product_reg;
  reg [63:0] current_fact;
  reg [2:0] k_counter;
  reg [3:0] mult_counter;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      product_reg <= 64'd1;
      done <= 1'b0;
      current_fact <= 64'd0;
      k_counter <= 3'd0;
      mult_counter <= 4'd0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            product_reg <= 64'd1;
            k_counter <= n;
            current_fact <= 64'd1;
            mult_counter <= 4'd1;
            state <= COMPUTE_FACT;
          end
        end

        COMPUTE_FACT: begin
          if (mult_counter <= k_counter) begin
            current_fact <= current_fact * mult_counter;
            mult_counter <= mult_counter + 1;
          end else begin
            state <= MULTIPLY_PROD;
          end
        end

        MULTIPLY_PROD: begin
          product_reg <= product_reg * current_fact;
          k_counter <= k_counter - 1;
          if (k_counter == 3'd1) begin
            state <= DONE;
          end else begin
            current_fact <= 64'd1;
            mult_counter <= 4'd1;
            state <= COMPUTE_FACT;
          end
        end

        DONE: begin
          done <= 1'b1;
          if (!start) begin
            state <= IDLE;
          end
        end
      endcase
    end
  end

  always @(posedge clk) begin
    result <= product_reg;
  end

endmodule