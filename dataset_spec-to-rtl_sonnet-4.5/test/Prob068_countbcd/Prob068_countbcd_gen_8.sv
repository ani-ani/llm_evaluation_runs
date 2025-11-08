module TopModule(
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
      // Ones digit (q[3:0]) always increments
      if (q[3:0] == 4'd9) begin
        q[3:0] <= 4'd0;
        ena[0] <= 1'b1;
        
        // Tens digit (q[7:4]) increments when ones wraps
        if (q[7:4] == 4'd9) begin
          q[7:4] <= 4'd0;
          ena[1] <= 1'b1;
          
          // Hundreds digit (q[11:8]) increments when tens wraps
          if (q[11:8] == 4'd9) begin
            q[11:8] <= 4'd0;
            ena[2] <= 1'b1;
            
            // Thousands digit (q[15:12]) increments when hundreds wraps
            if (q[15:12] == 4'd9) begin
              q[15:12] <= 4'd0;
            end else begin
              q[15:12] <= q[15:12] + 4'd1;
            end
          end else begin
            q[11:8] <= q[11:8] + 4'd1;
            ena[2] <= 1'b0;
          end
        end else begin
          q[7:4] <= q[7:4] + 4'd1;
          ena[1] <= 1'b0;
          ena[2] <= 1'b0;
        end
      end else begin
        q[3:0] <= q[3:0] + 4'd1;
        ena <= 3'b0;
      end
    end
  end

endmodule