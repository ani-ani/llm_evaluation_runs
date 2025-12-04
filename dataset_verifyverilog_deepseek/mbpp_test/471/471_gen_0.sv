module array_modulo_product (
  input clk,
  input rst_n,
  input start,
  input [7:0] n,
  input [7:0] data,
  input data_valid,
  output reg [7:0] result,
  output reg done
);

  reg [7:0] product_reg;
  reg [3:0] element_count;
  reg state;
  reg done_next, done_p1, done_p2;

  wire [7:0] data_mod = data % n;
  wire [15:0] product_mult = product_reg * data_mod;
  wire [7:0] new_product = product_mult % n;

  localparam IDLE = 1'b0;
  localparam PROCESS = 1'b1;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      product_reg <= 8'h01;
      element_count <= 4'd0;
      done_next <= 1'b0;
      done_p1 <= 1'b0;
      done_p2 <= 1'b0;
      result <= 8'd0;
      done <= 1'b0;
    end else begin
      done_p1 <= done_next;
      done_p2 <= done_p1;
      done <= done_p2;
      result <= product_reg;

      case (state)
        IDLE: begin
          if (start) begin
            product_reg <= 8'h01;
            element_count <= 4'd0;
            state <= PROCESS;
          end
        end

        PROCESS: begin
          if (data_valid && (element_count < 4'd8)) begin
            product_reg <= new_product;
            element_count <= element_count + 4'd1;
            if (element_count == 4'd7) done_next <= 1'b1;
          end
          if (done_p2) begin
            state <= IDLE;
            done_next <= 1'b0;
            done_p1 <= 1'b0;
            done_p2 <= 1'b0;
          end
        end
      endcase
    end
  end
endmodule