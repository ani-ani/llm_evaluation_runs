module powers_of_two_sum(
  input [15:0] num,
  output reg result
);

  always @* begin
    if (num == 0) begin
      result = 1'b0;
    end
    else if (num[0] == 1'b0) begin
      result = 1'b1;
    end
    else begin
      result = 1'b0;
    end
  end

endmodule