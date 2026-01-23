module elementwise_div (
    input [3:0] num1_array,
    input [3:0] num2_array,
    output reg [3:0] quotient_array,
    output reg [3:0] remainder_array
);

   reg [3:0] q0, r0, q1, r1, q2, r2, q3, r3;

   always @(*) begin
      if (num2_array[0] == 0) begin
          q0 = 4'b1111;
          r0 = 0;
      end else begin
          q0 = 0;
          r0 = num1_array[0];
          while (r0 >= num2_array[0]) begin
              r0 = r0 - num2_array[0];
              q0 = q0 + 1;
          end
      end
      quotient_array[0] = q0;
      remainder_array[0] = r0;

      if (num2_array[1] == 0) begin
          q1 = 4'b1111;
          r1 = 0;
      end else begin
          q1 = 0;
          r1 = num1_array[1];
          while (r1 >= num2_array[1]) begin
              r1 = r1 - num2_array[1];
              q1 = q1 + 1;
          end
      end
      quotient_array[1] = q1;
      remainder_array[1] = r1;

      if (num2_array[2] == 0) begin
          q2 = 4'b1111;
          r2 = 0;
      end else begin
          q2 = 0;
          r2 = num1_array[2];
          while (r2 >= num2_array[2]) begin
              r2 = r2 - num2_array[2];
              q2 = q2 + 1;
          end
      end
      quotient_array[2] = q2;
      remainder_array[2] = r2;

      if (num2_array[3] == 0) begin
          q3 = 4'b1111;
          r3 = 0;
      end else begin
          q3 = 0;
          r3 = num1_array[3];
          while (r3 >= num2_array[3]) begin
              r3 = r3 - num2_array[3];
              q3 = q3 + 1;
          end
      end
      quotient_array[3] = q3;
      remainder_array[3] = r3;

   end

endmodule