module fibonacci(
  input clk,
  input rst_n,
  input [7:0] n,
  input start,
  output reg [15:0] result,
  output reg done
);

  reg computing;
  reg [7:0] count;
  reg [7:0] n_reg;
  reg [15:0] prev;
  reg [15:0] curr;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      computing <= 1'b0;
      done <= 1'b0;
      result <= 16'd0;
      count <= 8'd0;
      n_reg <= 8'd0;
      prev <= 16'd0;
      curr <= 16'd1;
    end else begin
      if (computing) begin
        if (count < n_reg) begin
          prev <= curr;
          curr <= prev + curr;
          count <= count + 8'd1;
        end else begin
          computing <= 1'b0;
          done <= 1'b1;
          result <= (n_reg == 8'd0) ? prev : curr;
        end
      end else if (start && !done) begin
        computing <= 1'b1;
        done <= 1'b0;
        prev <= 16'd0;
        curr <= 16'd1;
        count <= 8'd0;
        n_reg <= n;
      end
    end
  end

endmodule