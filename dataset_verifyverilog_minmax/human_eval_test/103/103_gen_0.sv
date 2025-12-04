module rounded_average(
    input [7:0] n,
    input [7:0] m,
    output logic signed [8:0] result
);

logic [8:0] count;
logic [15:0] sum;
logic [7:0] rounded_average;
logic [9:0] temp_sum;

always @* begin
    if (n > m) begin
        result = 9'sb111111111;
    end else begin
        temp_sum = n + m;
        count = m - n + 1;
        sum = temp_sum * count / 2;
        rounded_average = (sum + (count >> 1)) / count;
        result = {1'b0, rounded_average};
    end
end

endmodule