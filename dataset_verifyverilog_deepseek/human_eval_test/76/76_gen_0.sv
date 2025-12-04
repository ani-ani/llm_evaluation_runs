module simple_power(input clk, input rst_n, input start, input [15:0] x, input [15:0] n, output reg result, output reg done);
  reg state;
  localparam IDLE = 1'b0;
  localparam COMPUTE = 1'b1;
  
  reg [15:0] x_reg, n_reg;
  reg [15:0] power_reg;
  reg [3:0] counter;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b1;
      result <= 1'b0;
      power_reg <= 16'd1;
      counter <= 4'd0;
      x_reg <= 16'd0;
      n_reg <= 16'd0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            x_reg <= x;
            n_reg <= n;
            state <= COMPUTE;
            done <= 1'b0;
            result <= 1'b0;
            power_reg <= 16'd1;
            counter <= 4'd0;
          end
        end
        
        COMPUTE: begin
          reg [31:0] next_power;
          if (x_reg == 16'd1) begin
            result <= 1'b1;
            done <= 1'b1;
            state <= IDLE;
          end else begin
            next_power = power_reg * n_reg;
            if (next_power == x_reg) begin
              result <= 1'b1;
              done <= 1'b1;
              state <= IDLE;
            end else if (next_power > x_reg) begin
              result <= 1'b0;
              done <= 1'b1;
              state <= IDLE;
            end else begin
              power_reg <= next_power[15:0];
              counter <= counter + 4'd1;
              if (counter == 4'd15) begin
                result <= 1'b0;
                done <= 1'b1;
                state <= IDLE;
              end
            end
          end
        end
      endcase
    end
  end
endmodule