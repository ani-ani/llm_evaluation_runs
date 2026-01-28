module subsequence_string(
    input [7:0] a,
    input [7:0] b,
    input [7:0] c,
    input [7:0] d,
    output reg valid,
    output reg [3:0] length,
    output reg [15:0] string_bits
);

    // Helper signals for internal computation
    reg [3:0] n0_possible [0:1]; // max 2 possible values for n0
    reg [3:0] n1_possible [0:1]; // max 2 possible values for n1
    reg [1:0] count_n0;
    reg [1:0] count_n1;
    reg [3:0] n0;
    reg [3:0] n1;
    reg [7:0] c_val;
    reg [7:0] q_val;
    reg [7:0] r_val;
    reg [4:0] zeros_start;
    reg found;
    reg [3:0] i;
    reg [3:0] p;

    // Step 1: Determine possible n0 from a
    always @(*) begin
        count_n0 = 2'd0;
        n0_possible[0] = 4'd0;
        n0_possible[1] = 4'd0;
        
        if (a == 8'd0) begin
            n0_possible[0] = 4'd0;
            n0_possible[1] = 4'd1;
            count_n0 = 2'd2;
        end else if (a == 8'd1 || a == 8'd3 || a == 8'd6 || a == 8'd10 || a == 8'd15 || a == 8'd21 || a == 8'd28) begin
            case (a)
                8'd1: n0_possible[0] = 4'd2;
                8'd3: n0_possible[0] = 4'd3;
                8'd6: n0_possible[0] = 4'd4;
                8'd10: n0_possible[0] = 4'd5;
                8'd15: n0_possible[0] = 4'd6;
                8'd21: n0_possible[0] = 4'd7;
                8'd28: n0_possible[0] = 4'd8;
                default: n0_possible[0] = 4'd0;
            endcase
            count_n0 = 2'd1;
        end
    end

    // Step 1: Determine possible n1 from d
    always @(*) begin
        count_n1 = 2'd0;
        n1_possible[0] = 4'd0;
        n1_possible[1] = 4'd0;
        
        if (d == 8'd0) begin
            n1_possible[0] = 4'd0;
            n1_possible[1] = 4'd1;
            count_n1 = 2'd2;
        end else if (d == 8'd1 || d == 8'd3 || d == 8'd6 || d == 8'd10 || d == 8'd15 || d == 8'd21 || d == 8'd28) begin
            case (d)
                8'd1: n1_possible[0] = 4'd2;
                8'd3: n1_possible[0] = 4'd3;
                8'd6: n1_possible[0] = 4'd4;
                8'd10: n1_possible[0] = 4'd5;
                8'd15: n1_possible[0] = 4'd6;
                8'd21: n1_possible[0] = 4'd7;
                8'd28: n1_possible[0] = 4'd8;
                default: n1_possible[0] = 4'd0;
            endcase
            count_n1 = 2'd1;
        end
    end

    // Steps 2-5: Main combinational logic
    always @(*) begin
        // Initialize outputs
        valid = 1'b0;
        length = 4'd0;
        string_bits = 16'd0;
        found = 1'b0;
        n0 = 4'd0;
        n1 = 4'd0;
        c_val = 8'd0;
        
        // Step 2: Check all combinations
        if (!found) begin
            for (i = 0; i < 2; i = i + 1) begin
                if (count_n0 > i) begin
                    for (p = 0; p < 2; p = p + 1) begin
                        if (count_n1 > p) begin
                            // Check if non-empty and equation satisfied
                            if ((n0_possible[i] + n1_possible[p] > 0) && 
                                (b + c == (n0_possible[i] * n1_possible[p]))) begin
                                found = 1'b1;
                                n0 = n0_possible[i];
                                n1 = n1_possible[p];
                                break;
                            end
                        end
                    end
                    if (found) break;
                end
            end
        end

        // Step 3: If found, set valid and length
        if (found) begin
            valid = 1'b1;
            length = n0 + n1;
            
            // Step 4: Compute c_val
            c_val = (n0 * n1) - b;
            
            // Step 5: Construct string bits
            if (n1 == 4'd0) begin
                // All zeros
                for (p = 0; p < 16; p = p + 1) begin
                    if (p < length) begin
                        string_bits[p] = 1'b0;
                    end
                end
            end else if (n0 == 4'd0) begin
                // All ones
                for (p = 0; p < 16; p = p + 1) begin
                    if (p < length) begin
                        string_bits[p] = 1'b1;
                    end
                end
            end else begin
                // General case
                q_val = c_val / n1;
                r_val = c_val % n1;
                
                if (r_val > 0) begin
                    zeros_start = n0 - q_val - 1;
                end else begin
                    zeros_start = n0 - q_val;
                end
                
                // Fill bits for positions 0..15
                for (p = 0; p < 16; p = p + 1) begin
                    if (p < length) begin
                        if (p < zeros_start) begin
                            string_bits[p] = 1'b0;
                        end else if (p < zeros_start + r_val) begin
                            string_bits[p] = 1'b1;
                        end else if (p < zeros_start + r_val + ((r_val > 0) ? 1 : 0)) begin
                            string_bits[p] = 1'b0;
                        end else if (p < zeros_start + r_val + ((r_val > 0) ? 1 : 0) + (n1 - r_val)) begin
                            string_bits[p] = 1'b1;
                        end else begin
                            string_bits[p] = 1'b0;
                        end
                    end
                end
            end
        end
    end

endmodule