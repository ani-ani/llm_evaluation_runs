module find_string(
    input [15:0] a,
    input [15:0] b,
    input [15:0] c,
    input [15:0] d,
    output [15:0] out_chars,
    output [3:0] out_len
);

    reg [15:0] out_chars_reg;
    reg [3:0] out_len_reg;
    reg [3:0] i, j, k;
    reg [15:0] current_string;
    reg [15:0] count_00, count_01, count_10, count_11;
    reg found;

    always @(*) begin
        out_chars_reg = 16'd0;
        out_len_reg = 4'd0;
        found = 1'b0;

        for (i = 1; i <= 16; i = i + 1) begin
            if (found) begin
                continue;
            end

            if ((i - 1) <= (a + b + c + d) && (a + b + c + d) <= (i * (i - 1) / 2)) begin
                for (j = 0; j < 65536; j = j + 1) begin
                    current_string = j;
                    count_00 = 16'd0;
                    count_01 = 16'd0;
                    count_10 = 16'd0;
                    count_11 = 16'd0;

                    for (k = 1; k < i; k = k + 1) begin
                        if (current_string[k-1] == 1'b0 && current_string[k] == 1'b0) begin
                            count_00 = count_00 + 16'd1;
                        end else if (current_string[k-1] == 1'b0 && current_string[k] == 1'b1) begin
                            count_01 = count_01 + 16'd1;
                        end else if (current_string[k-1] == 1'b1 && current_string[k] == 1'b0) begin
                            count_10 = count_10 + 16'd1;
                        end else if (current_string[k-1] == 1'b1 && current_string[k] == 1'b1) begin
                            count_11 = count_11 + 16'd1;
                        end
                    end

                    if (count_00 == a && count_01 == b && count_10 == c && count_11 == d) begin
                        out_chars_reg = current_string;
                        out_len_reg = i;
                        found = 1'b1;
                        break;
                    end
                end
            end
        end
    end

    assign out_chars = out_chars_reg;
    assign out_len = out_len_reg;

endmodule