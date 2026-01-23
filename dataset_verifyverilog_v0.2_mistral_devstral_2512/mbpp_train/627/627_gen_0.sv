module find_first_missing(
    input clk,
    input rst_n,
    input start,
    input [31:0] data_in,
    output reg [31:0] missing_number
);

    reg [31:0] data_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_reg <= 32'd0;
            missing_number <= 32'd0;
        end else if (start) begin
            data_reg <= data_in;
            missing_number <= find_missing(data_reg);
        end
    end

    function [31:0] find_missing;
        input [31:0] data;
        reg [31:0] missing;
        integer i;

        initial begin
            missing = 32'd0;
            for (i = 0; i < 32; i = i + 1) begin
                if (data[i] != 32'd1 << i) begin
                    missing = 32'd1 << i;
                    break;
                end
            end
        end
    endfunction
endmodule