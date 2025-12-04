module elementwise_sub (
    input wire signed [3:0][7:0] a,
    input wire signed [3:0][7:0] b,
    input wire [1:0] valid_entries,
    output logic signed [3:0][7:0] diff
);

    integer N;
    
    always_comb begin
        // Determine the number of valid entries
        N = (valid_entries == 0) ? 4 : valid_entries;
        
        // Initialize all outputs to 0
        diff = '0;
        
        // Compute subtraction for valid elements
        for (int i = 0; i < 4; i++) begin
            if (i < N) begin
                diff[i] = a[i] - b[i];
            end
        end
    end

endmodule