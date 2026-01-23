module subsequence_string(
    input [7:0] a,
    input [7:0] b,
    input [7:0] c,
    input [7:0] d,
    output reg valid,
    output reg [3:0] length,
    output reg [15:0] string_bits
);

    reg [3:0] n0_possible [0:1];
    reg [3:0] n1_possible [0:1];
    reg [3:0] n0, n1;
    reg [7:0] c_val;
    reg [3:0] zeros_start, q, r;
    integer i, j, k;

    always @(*) begin
        // Initialize outputs
        valid = 1'b0;
        length = 4'd0;
        for (i = 0; i < 16; i = i + 1) begin
            string_bits[i] = 1'b0;
        end

        // Determine possible n0 values from a
        if (a == 8'd0) begin
            n0_possible[0] = 4'd0;
            n0_possible[1] = 4'd1;
        end else if (a == 8'd1) begin
            n0_possible[0] = 4'd2;
        end else if (a == 8'd3) begin
            n0_possible[0] = 4'd3;
        end else if (a == 8'd6) begin
            n0_possible[0] = 4'd4;
        end else if (a == 8'd10) begin
            n0_possible[0] = 4'd5;
        end else if (a == 8'd15) begin
            n0_possible[0] = 4'd6;
        end else if (a == 8'd21) begin
            n0_possible[0] = 4'd7;
        end else if (a == 8'd28) begin
            n0_possible[0] = 4'd8;
        end else begin
            n0_possible[0] = 4'd0;
            n0_possible[1] = 4'd0;
        end

        // Determine possible n1 values from d
        if (d == 8'd0) begin
            n1_possible[0] = 4'd0;
            n1_possible[1] = 4'd1;
        end else if (d == 8'd1) begin
            n1_possible[0] = 4'd2;
        end else if (d == 8'd3) begin
            n1_possible[0] = 4'd3;
        end else if (d == 8'd6) begin
            n1_possible[0] = 4'd4;
        end else if (d == 8'd10) begin
            n1_possible[0] = 4'd5;
        end else if (d == 8'd15) begin
            n1_possible[0] = 4'd6;
        end else if (d == 8'd21) begin
            n1_possible[0] = 4'd7;
        end else if (d == 8'd28) begin
            n1_possible[0] = 4'd8;
        end else begin
            n1_possible[0] = 4'd0;
            n1_possible[1] = 4'd0;
        end

        // Check all combinations of n0 and n1
        for (i = 0; i < 2; i = i + 1) begin
            if (n0_possible[i] == 4'd0) continue;
            for (j = 0; j < 2; j = j + 1) begin
                if (n1_possible[j] == 4'd0) continue;
                n0 = n0_possible[i];
                n1 = n1_possible[j];
                if (n0 + n1 > 0 && b + c == n0 * n1) begin
                    valid = 1'b1;
                    length = n0 + n1;
                    c_val = n0 * n1 - b;
                    if (n1 == 4'd0) begin
                        for (k = 0; k < n0; k = k + 1) begin
                            string_bits[k] = 1'b0;
                        end
                    end else if (n0 == 4'd0) begin
                        for (k = 0; k < n1; k = k + 1) begin
                            string_bits[k] = 1'b1;
                        end
                    end else begin
                        q = c_val / n1;
                        r = c_val % n1;
                        zeros_start = n0 - q - (r > 0 ? 4'd1 : 4'd0);
                        for (k = 0; k < 16; k = k + 1) begin
                            if (k < zeros_start) begin
                                string_bits[k] = 1'b0;
                            end else if (k < zeros_start + r) begin
                                string_bits[k] = 1'b1;
                            end else if (k < zeros_start + r + (r > 0 ? 4'd1 : 4'd0)) begin
                                string_bits[k] = 1'b0;
                            end else if (k < zeros_start + r + (r > 0 ? 4'd1 : 4'd0) + (n1 - r)) begin
                                string_bits[k] = 1'b1;
                            end else begin
                                string_bits[k] = 1'b0;
                            end
                        end
                    end
                end
            end
        end
    end
endmodule