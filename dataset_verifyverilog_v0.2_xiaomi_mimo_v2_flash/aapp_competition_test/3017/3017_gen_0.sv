module power_substring_counter(
    input [15:0] n,
    input [3:0] e,
    output reg [15:0] count
);

    // Helper function to compute 2^e
    function [15:0] power_of_two;
        input [3:0] exp;
        begin
            power_of_two = 16'd1 << exp;
        end
    endfunction

    // Helper function to count digits and store them in a packed array
    // Returns {num_digits, digit_1, digit_2, ..., digit_5} (digits stored in MSB of the 20-bit vector)
    function [19:0] get_digits;
        input [15:0] val;
        reg [15:0] temp;
        reg [3:0] d1, d2, d3, d4, d5;
        integer i;
        begin
            temp = val;
            d1 = 0; d2 = 0; d3 = 0; d4 = 0; d5 = 0;
            
            if (temp == 0) begin
                get_digits = {4'd1, 16'd0};
            end else begin
                // Extract digits. We only need up to 5 digits for 65535.
                // Manual division is efficient here.
                d1 = temp % 10; temp = temp / 10;
                if (temp > 0) begin
                    d2 = temp % 10; temp = temp / 10;
                    if (temp > 0) begin
                        d3 = temp % 10; temp = temp / 10;
                        if (temp > 0) begin
                            d4 = temp % 10; temp = temp / 10;
                            if (temp > 0) begin
                                d5 = temp % 10;
                                get_digits = {4'd5, {12'd0, d5, d4, d3, d2, d1}};
                            end else begin
                                get_digits = {4'd4, {12'd0, d4, d3, d2, d1}};
                            end
                        end else begin
                            get_digits = {4'd3, {12'd0, d3, d2, d1}};
                        end
                    end else begin
                        get_digits = {4'd2, {12'd0, d2, d1}};
                    end
                end else begin
                    get_digits = {4'd1, {12'd0, d1}};
                end
            end
        end
    endfunction

    // Helper function to check if p_digits is a substring of k_digits
    function match_substring;
        input [19:0] k_digits_packed; // {num_k, d5, d4, d3, d2, d1} (d1 is LSB digit)
        input [19:0] p_digits_packed; // {num_p, d5, d4, d3, d2, d1}
        reg [3:0] num_k;
        reg [3:0] num_p;
        reg [15:0] k_d;
        reg [15:0] p_d;
        integer i, j;
        reg found;
        reg match;
        begin
            num_k = k_digits_packed[19:16];
            num_p = p_digits_packed[19:16];
            
            // Extract individual digits for easier access
            // p_digits are stored in bits 15:0, 4 bits each, d1 is LSB
            // We need to align them for comparison.
            // Let's put them in an array for logic.
            // Actually, we need to handle the sliding window manually.
            
            // Optimization: The pattern length is num_p. The text length is num_k.
            // We need to check every valid start position in k.
            
            match_substring = 0;
            
            if (num_p == 0) match_substring = 1; // Empty pattern matches
            else if (num_p > num_k) match_substring = 0; // Pattern too long
            else begin
                // We compare indices 0 to num_p-1 of pattern against indices j to j+num_p-1 of k
                // k digits are packed in k_d[3:0] (pos 0), k_d[7:4] (pos 1), ...
                // p digits are packed in p_d[3:0] (pos 0), p_d[7:4] (pos 1), ...
                k_d = k_digits_packed[15:0];
                p_d = p_digits_packed[15:0];
                
                for (i = 0; i <= (num_k - num_p); i = i + 1) begin
                    found = 1;
                    for (j = 0; j < num_p; j = j + 1) begin
                        // Compare p_d[j] with k_d[i+j]
                        // Note: If we stored d1 in LSB (bits 3:0), then d1 is index 0.
                        // Let's assume the storage format for the manual check:
                        // bits 3:0 is index 0, bits 7:4 is index 1...
                        if (p_d[4*j +: 4] != k_d[4*(i+j) +: 4]) begin
                            found = 0;
                        end
                    end
                    if (found) begin
                        match_substring = 1;
                        disable match_substring_loop; // Break outer loop
                    end
                end
            end
        end
    endfunction

    // Main combinational logic
    integer i;
    reg [15:0] p_val;
    reg [19:0] p_digits;
    reg [19:0] k_digits;
    reg match;
    
    always @(*) begin
        // 1. Compute Power
        p_val = power_of_two(e);
        
        // 2. Get Digits of Power
        p_digits = get_digits(p_val);
        
        // 3. Iterate and Count
        count = 0;
        for (i = 0; i <= 65535; i = i + 1) begin
            if (i > n) begin
                // Break if i exceeds n (unrolling requires logic to stop)
                // But since it's combinational, we can just condition the addition.
            end else begin
                k_digits = get_digits(i);
                match = match_substring(k_digits, p_digits);
                if (match) begin
                    count = count + 1;
                end
            end
        end
    end

endmodule
