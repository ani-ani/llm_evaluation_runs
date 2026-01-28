module detect_k_existence (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] k,
    input wire [7:0] a [0:15],
    input wire [4:0] n,
    output reg result,
    output reg done
);

    // Internal registers for pipeline
    reg [3:0] i;
    reg [7:0] n_minus_1;
    reg [7:0] n_minus_2;
    reg start_d;
    
    // Intermediate results
    wire k_found;
    wire single_element;
    wire cond1_met;
    wire cond2_met;
    wire cond3_met;
    wire cond4_met;
    wire any_condition;
    
    // Combinational logic for condition checks
    reg [3:0] current_i;
    reg [7:0] a_i;
    reg [7:0] a_i_minus_1;
    reg [7:0] a_i_plus_1;
    reg [7:0] a_i_minus_2;
    reg [7:0] a_i_plus_2;
    
    // Check if k exists in array (parallel comparison)
    assign k_found = (a[0] == k) || (a[1] == k) || (a[2] == k) || (a[3] == k) ||
                     (a[4] == k) || (a[5] == k) || (a[6] == k) || (a[7] == k) ||
                     (a[8] == k) || (a[9] == k) || (a[10] == k) || (a[11] == k) ||
                     (a[12] == k) || (a[13] == k) || (a[14] == k) || (a[15] == k);
    
    // Check if n=1
    assign single_element = (n == 5'd1);
    
    // Combinational condition checks for each index
    always @(*) begin
        a_i = a[i];
        
        // Condition 1: i < n-1 and a[i] >= k and a[i+1] >= k
        if (i < n_minus_1 && a_i >= k && a[i+1] >= k)
            cond1_met = 1'b1;
        else
            cond1_met = 1'b0;
        
        // Condition 2: i > 0 and a[i] >= k and a[i-1] >= k
        if (i > 4'd0 && a_i >= k && a[i-1] >= k)
            cond2_met = 1'b1;
        else
            cond2_met = 1'b0;
        
        // Condition 3: i > 1 and a[i] >= k and a[i-2] >= k
        if (i > 4'd1 && a_i >= k && a[i-2] >= k)
            cond3_met = 1'b1;
        else
            cond3_met = 1'b0;
        
        // Condition 4: i < n-2 and a[i] >= k and a[i+2] >= k
        if (i < n_minus_2 && a_i >= k && a[i+2] >= k)
            cond4_met = 1'b1;
        else
            cond4_met = 1'b0;
    end
    
    assign any_condition = cond1_met || cond2_met || cond3_met || cond4_met;
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 1'b0;
            done <= 1'b0;
            i <= 4'd0;
            n_minus_1 <= 8'd0;
            n_minus_2 <= 8'd0;
            start_d <= 1'b0;
        end else begin
            start_d <= start;
            
            if (start) begin
                // Initialize computation
                i <= 4'd0;
                n_minus_1 <= n - 8'd1;
                n_minus_2 <= n - 8'd2;
                
                if (!k_found) begin
                    result <= 1'b0;
                    done <= 1'b1;
                end else if (single_element) begin
                    result <= 1'b1;
                    done <= 1'b1;
                end else begin
                    // Start checking conditions
                    result <= 1'b0;
                    done <= 1'b0;
                end
            end else if (start_d && !done) begin
                // Continue checking indices
                if (i < n) begin
                    if (any_condition) begin
                        result <= 1'b1;
                        done <= 1'b1;
                    end else begin
                        // Continue to next index
                        if (i < n - 4'd1) begin
                            i <= i + 4'd1;
                        end else begin
                            // Reached end of array
                            result <= 1'b0;
                            done <= 1'b1;
                        end
                    end
                end else begin
                    // Should not reach here, but safe default
                    result <= 1'b0;
                    done <= 1'b1;
                end
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule