module cylinder_volume (
  input clk,
  input rst_n,
  input start,
  input [15:0] radius,
  input [15:0] height,
  output reg [31:0] volume,
  output reg done
);

  typedef enum logic [2:0] {IDLE, C1, C2, C3, DONE} state_t;
  state_t state;

  reg [31:0] r_squared_reg;
  reg [47:0] rh_product_reg;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      r_squared_reg <= 0;
      rh_product_reg <= 0;
      volume <= 0;
      done <= 0;
    end else begin
      done <= 1'b0;
      case (state)
        IDLE: begin
          if (start) begin
            state <= C1;
          end
        end

        C1: begin
          r_squared_reg <= radius * radius;
          state <= C2;
        end

        C2: begin
          rh_product_reg <= r_squared_reg * height;
          state <= C3;
        end

        C3: begin
          volume <= rh_product_reg * 18'h3243F;
          state <= DONE;
        end

        DONE: begin
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end

endmodule