module TopModule (
  input clk,
  input reset,
  output reg [2:0] ena,
  output reg [15:0] q
);

  always @(posedge clk) begin
    if (reset) begin
      q <= 16'b0;
      ena <= 3'b0;
    end else begin
      reg [3:0] p0, p1, p2, p3;
      reg [2:0] enas;
      p0 = q[3:0];
      p1 = q[7:4];
      p2 = q[11:8];
      p3 = q[15:12];
      p0 = p0 + 1;
      enas = 3'b0;
      if (p0 == 4'd10) begin
        p0 = 4'd0;
        p1 = p1 + 1;
        enas[0] = 1;
        if (p1 == 4'd10) begin
          p1 = 4'd0;
          p2 = p2 + 1;
          enas[1] = 1;
          if (p2 == 4'd10) begin
            p2 = 4'd0;
            p3 = p3 + 1;
            enas[2] = 1;
            if (p3 == 4'd10) p3 = 4'd0;
          end
        end
      end
      q[3:0] <= p0;
      q[7:4] <= p1;
      q[11:8] <= p2;
      q[15:12] <= p3;
      ena <= enas;
    end
  end

endmodule