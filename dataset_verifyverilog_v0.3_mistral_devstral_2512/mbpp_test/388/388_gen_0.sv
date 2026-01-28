module highest_power_of_2(
    input [15:0] n,
    output [15:0] result
);

    reg [15:0] temp;

    always @(*) begin
        if (n == 16'd0) begin
            result = 16'd0;
        end else begin
            temp = n;
            temp = temp | (temp >> 1);
            temp = temp | (temp >> 2);
            temp = temp | (temp >> 4);
            temp = temp | (temp >> 8);
            result = (temp + 16'd1) >> 1;
        end
    end

endmodule