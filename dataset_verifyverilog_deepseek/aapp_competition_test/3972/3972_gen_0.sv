module sequence_counter (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  output reg [29:0] result,
  output reg done
);

  localparam IDLE = 2'b00;
  localparam COMPUTE = 2'b01;
  localparam DONE = 2'b10;

  reg [1:0] state;
  reg [3:0] count;
  reg [3:0] n_reg;
  reg [29:0] dp [0:7];

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      result <= 30'd0;
      count <= 4'd0;
      n_reg <= 4'd0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            n_reg <= n;
            done <= 1'b0;
            dp[0] <= 30'd1;
            dp[1] <= 30'd4;
            count <= 4'd0;
            state <= COMPUTE;
          end
        end

        COMPUTE: begin
          if (count >= 4'd2 && count <= 4'd7) begin
            dp[count] <= ((dp[count-1] << 1) + dp[count-2]) % 30'd1000000007;
          end
          count <= count + 1;
          
          if (count == 4'd8) begin
            result <= (n_reg >= 4'd1 && n_reg <= 4'd8) ? dp[n_reg-1] : 30'd0;
            done <= 1'b1;
            state <= DONE;
          end
        end

        DONE: begin
          if (start) begin
            n_reg <= n;
            done <= 1'b0;
            dp[0] <= 30'd1;
            dp[1] <= 30'd4;
            count <= 4'd0;
            state <= COMPUTE;
          end
        end
      endcase
    end
  end

endmodule