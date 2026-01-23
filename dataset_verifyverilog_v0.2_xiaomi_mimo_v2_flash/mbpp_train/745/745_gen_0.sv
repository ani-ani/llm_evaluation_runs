module divisible_by_digits(
    input [3:0] start_num,
    input [3:0] end_num,
    output reg [15:0] valid_mask
);

    // Function to extract digits and check validity for a given number N
    // Returns 1 if valid (contains no 0 and divisible by all non-zero digits), 0 otherwise
    function automatic is_valid_num;
        input [3:0] N;
        integer i;
        reg [3:0] d1, d2;
        reg has_d1, has_d2;
        reg [3:0] rem;
        begin
            // Default: valid unless proven otherwise
            is_valid_num = 1;
            
            // Extract digits using case statement
            // Format: d1 is tens digit, d2 is ones digit
            // has_d1/has_d2 indicate if the digit exists (only d2 exists for 0-9)
            d1 = 0; d2 = 0; has_d1 = 0; has_d2 = 0;
            
            case(N)
                4'd0: begin d1=0; d2=0; has_d1=0; has_d2=1; end
                4'd1: begin d1=0; d2=1; has_d1=0; has_d2=1; end
                4'd2: begin d1=0; d2=2; has_d1=0; has_d2=1; end
                4'd3: begin d1=0; d2=3; has_d1=0; has_d2=1; end
                4'd4: begin d1=0; d2=4; has_d1=0; has_d2=1; end
                4'd5: begin d1=0; d2=5; has_d1=0; has_d2=1; end
                4'd6: begin d1=0; d2=6; has_d1=0; has_d2=1; end
                4'd7: begin d1=0; d2=7; has_d1=0; has_d2=1; end
                4'd8: begin d1=0; d2=8; has_d1=0; has_d2=1; end
                4'd9: begin d1=0; d2=9; has_d1=0; has_d2=1; end
                4'd10: begin d1=1; d2=0; has_d1=1; has_d2=1; end
                4'd11: begin d1=1; d2=1; has_d1=1; has_d2=1; end
                4'd12: begin d1=1; d2=2; has_d1=1; has_d2=1; end
                4'd13: begin d1=1; d2=3; has_d1=1; has_d2=1; end
                4'd14: begin d1=1; d2=4; has_d1=1; has_d2=1; end
                4'd15: begin d1=1; d2=5; has_d1=1; has_d2=1; end
                default: begin d1=0; d2=0; has_d1=0; has_d2=0; end
            endcase

            // Check digits
            // Check d1 if it exists
            if (has_d1) begin
                if (d1 == 0) is_valid_num = 0; // Contains 0
                else if (d1 != 0 && is_valid_num) begin
                    // Check N % d1 == 0 using subtraction
                    // Logic: if N < d1, remainder is N (not 0 unless N is 0, but d1>0 so fail unless N=0 which is handled by has_d1=0 usually, but here N>=10)
                    if (N < d1) is_valid_num = 0;
                    else begin
                        rem = N;
                        // Unrolled subtraction loop (max 15 iterations)
                        if (rem >= d1) rem = rem - d1;
                        if (rem >= d1) rem = rem - d1;
                        if (rem >= d1) rem = rem - d1;
                        if (rem >= d1) rem = rem - d1;
                        if (rem >= d1) rem = rem - d1;
                        if (rem >= d1) rem = rem - d1;
                        if (rem >= d1) rem = rem - d1;
                        if (rem >= d1) rem = rem - d1;
                        if (rem >= d1) rem = rem - d1;
                        if (rem >= d1) rem = rem - d1;
                        if (rem >= d1) rem = rem - d1;
                        if (rem >= d1) rem = rem - d1;
                        if (rem >= d1) rem = rem - d1;
                        if (rem >= d1) rem = rem - d1;
                        if (rem >= d1) rem = rem - d1;
                        
                        if (rem != 0) is_valid_num = 0;
                    end
                end
            end

            // Check d2 if it exists
            if (has_d2 && is_valid_num) begin
                if (d2 == 0) is_valid_num = 0; // Contains 0
                else if (d2 != 0 && is_valid_num) begin
                    // Check N % d2 == 0
                    if (N < d2) is_valid_num = 0;
                    else begin
                        rem = N;
                        // Unrolled subtraction loop
                        if (rem >= d2) rem = rem - d2;
                        if (rem >= d2) rem = rem - d2;
                        if (rem >= d2) rem = rem - d2;
                        if (rem >= d2) rem = rem - d2;
                        if (rem >= d2) rem = rem - d2;
                        if (rem >= d2) rem = rem - d2;
                        if (rem >= d2) rem = rem - d2;
                        if (rem >= d2) rem = rem - d2;
                        if (rem >= d2) rem = rem - d2;
                        if (rem >= d2) rem = rem - d2;
                        if (rem >= d2) rem = rem - d2;
                        if (rem >= d2) rem = rem - d2;
                        if (rem >= d2) rem = rem - d2;
                        if (rem >= d2) rem = rem - d2;
                        if (rem >= d2) rem = rem - d2;

                        if (rem != 0) is_valid_num = 0;
                    end
                end
            end
        end
    endfunction

    // Combinational block to generate valid_mask
    integer i;
    always @(*) begin
        valid_mask = 16'b0;
        for (i = 0; i < 16; i = i + 1) begin
            // Check range and validity
            if (i >= start_num && i <= end_num) begin
                if (is_valid_num(i[3:0])) begin
                    valid_mask[i] = 1'b1;
                end
            end
        end
    end

endmodule