module binary_seq_counter (
    input [3:0] n,
    input start,
    output reg [31:0] result
);

    always_comb begin
        // Default assignment
        result = 32'h00010000; // 1.0 in Q16.16

        if (start) begin
            // Internal variables
            reg [31:0] nCr;
            reg [31:0] temp;
            integer i;
            integer n_int;
            
            // Convert n to integer and check range
            n_int = n;
            
            // Only compute if n is in valid range 1 to 8
            if (n_int >= 1 && n_int <= 8) begin
                nCr = 32'd1;
                
                // Loop from r=1 to n
                for (i = 1; i <= n_int; i = i + 1) begin
                    // Calculate C(n, r) using recurrence: C(n, r) = C(n, r-1) * (n + 1 - r) / r
                    temp = nCr * (n_int + 1 - i);
                    nCr = temp / i;
                    
                    // Accumulate nCr^2 to result (scaled to Q16.16)
                    result = result + ((nCr * nCr) << 16);
                end
            end
        end
    end

endmodule
module TopModule(output out);
  assign out = 1'b0;
endmodule