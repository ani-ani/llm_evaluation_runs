module even_odd_diff(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    output reg [15:0] result,
    output reg done
);

    reg [15:0] first_even;
    reg [15:0] first_odd;
    reg [15:0] diff;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 16'd0;
            done <= 1'b0;
        end else if (start) begin
            // Find first even
            first_even = 16'd0;
            if (arr_0[0] == 1'b0) first_even = arr_0;
            else if (arr_1[0] == 1'b0) first_even = arr_1;
            else if (arr_2[0] == 1'b0) first_even = arr_2;
            else if (arr_3[0] == 1'b0) first_even = arr_3;
            else if (arr_4[0] == 1'b0) first_even = arr_4;
            else if (arr_5[0] == 1'b0) first_even = arr_5;
            else if (arr_6[0] == 1'b0) first_even = arr_6;
            else if (arr_7[0] == 1'b0) first_even = arr_7;

            // Find first odd
            first_odd = 16'd0;
            if (arr_0[0] == 1'b1) first_odd = arr_0;
            else if (arr_1[0] == 1'b1) first_odd = arr_1;
            else if (arr_2[0] == 1'b1) first_odd = arr_2;
            else if (arr_3[0] == 1'b1) first_odd = arr_3;
            else if (arr_4[0] == 1'b1) first_odd = arr_4;
            else if (arr_5[0] == 1'b1) first_odd = arr_5;
            else if (arr_6[0] == 1'b1) first_odd = arr_6;
            else if (arr_7[0] == 1'b1) first_odd = arr_7;

            // Compute difference
            diff = first_even - first_odd;

            // Clamp to 16-bit signed range
            if (diff > 16'd32767) begin
                result <= 16'd32767;
            end else if (diff < 16'd-32768) begin
                result <= 16'd-32768;
            end else begin
                result <= diff;
            end

            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule