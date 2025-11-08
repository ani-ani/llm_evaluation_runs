module TopModule(
  input clk,
  input reset,
  output reg [2:0] ena,
  output reg [15:0] q
);

  always @(posedge clk) begin
    if (reset) begin
      q <= 16'd0;
      ena <= 3'd0;
    end else begin
      // Ones digit (q[3:0]) - always increments
      if (q[3:0] == 4'd9) begin
        q[3:0] <= 4'd0;
        ena[0] <= 1'b1;
      end else begin
        q[3:0] <= q[3:0] + 1'b1;
        ena[0] <= 1'b0;
      end
      
      // Tens digit (q[7:4]) - increments when ones rolls over
      if (ena[0]) begin
        if (q[7:4] == 4'd9) begin
          q[7:4] <= 4'd0;
          ena[1] <= 1'b1;
        end else begin
          q[7:4] <= q[7:4] + 1'b1;
          ena[1] <= 1'b0;
        end
      end else begin
        ena[1] <= 1'b0;
      end
      
      // Hundreds digit (q[11:8]) - increments when tens rolls over
      if (ena[1]) begin
        if (q[11:8] == 4'd9) begin
          q[11:8] <= 4'd0;
          ena[2] <= 1'b1;
        end else begin
          q[11:8] <= q[11:8] + 1'b1;
          ena[2] <= 1'b0;
        end
      end else begin
        ena[2] <= 1'b0;
      end
      
      // Thousands digit (q[15:12]) - increments when hundreds rolls over
      if (ena[2]) begin
        if (q[15:12] == 4'd9) begin
          q[15:12] <= 4'd0;
        end else begin
          q[15:12] <= q[15:12] + 1'b1;
        end
      end
    end
  end

endmodule