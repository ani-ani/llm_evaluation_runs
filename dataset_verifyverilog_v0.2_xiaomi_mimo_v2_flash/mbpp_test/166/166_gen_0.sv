module even_pair_counter (
    input clk,
    input rst_n,
    input [7:0] data_in,
    input [2:0] index,
    input load,
    input compute,
    output reg [4:0] result,
    output reg valid
);

    // Memory to store 8 elements
    reg [7:0] storage [0:7];
    
    // Control signals
    reg loading_done;
    
    integer i;
    reg [3:0] count_even;
    reg [3:0] count_odd;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset state
            loading_done <= 1'b0;
            result <= 5'b0;
            valid <= 1'b0;
        end else begin
            // Load operation
            if (load) begin
                storage[index] <= data_in;
                valid <= 1'b0; // Invalidate previous result during load
            end
            
            // Compute operation
            if (compute && loading_done) begin
                // Count even and odd parities
                count_even = 0;
                count_odd = 0;
                
                for (i = 0; i < 8; i = i + 1) begin
                    if (storage[i][0] == 1'b0) begin
                        count_even = count_even + 1;
                    end else begin
                        count_odd = count_odd + 1;
                    end
                end
                
                // Calculate pairs: n*(n-1)/2
                // pairs_even = count_even * (count_even - 1) / 2
                // pairs_odd = count_odd * (count_odd - 1) / 2
                result <= ((count_even * (count_even - 1)) >> 1) + ((count_odd * (count_odd - 1)) >> 1);
                valid <= 1'b1;
            end else if (!load && !compute) begin
                // When idle, signal that storage is ready for compute
                loading_done <= 1'b1;
                valid <= 1'b0;
            end else if (compute && !loading_done) begin
                // Compute triggered before any loads
                result <= 5'd0;
                valid <= 1'b1;
            end
        end
    end

endmodule