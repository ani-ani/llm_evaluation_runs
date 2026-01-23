module max_f_value(
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [7:0][15:0] a,
    output reg [31:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam PROCESS = 3'b010;
    localparam CALC = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state;
    reg [2:0] counter;
    reg [2:0] n_reg;
    
    // Intermediate signals for difference calculation
    wire signed [15:0] diff_val;
    wire signed [15:0] seq1_val;
    wire signed [15:0] seq2_val;
    wire signed [15:0] abs_diff;
    
    // Registers for Kadane's algorithm
    reg signed [31:0] curr_sum1;
    reg signed [31:0] max_sum1;
    reg signed [31:0] curr_sum2;
    reg signed [31:0] max_sum2;
    
    // Combinational logic for difference and sequences
    wire signed [15:0] a_i = a[counter];
    wire signed [15:0] a_i_plus_1 = a[counter + 1];
    
    assign diff_val = a_i - a_i_plus_1;
    assign abs_diff = (diff_val[15]) ? -diff_val : diff_val;
    
    // seq1: starts with + sign at i=0
    // seq1[i] = abs_diff * (-1)^i
    // seq2: starts with - sign at i=0 (opposite of seq1)
    // seq2[i] = -seq1[i]
    
    // Check if i is even or odd
    wire is_even = (counter[0] == 1'b0);
    
    assign seq1_val = is_even ? abs_diff : -abs_diff;
    assign seq2_val = -seq1_val;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'h0;
            done <= 1'b0;
            counter <= 3'b0;
            n_reg <= 3'b0;
            curr_sum1 <= 32'sh0;
            max_sum1 <= 32'sh0;
            curr_sum2 <= 32'sh0;
            max_sum2 <= 32'sh0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                    end
                end
                
                LOAD: begin
                    // Validate n (2 <= n <= 8)
                    if (n >= 2 && n <= 8) begin
                        n_reg <= n;
                        counter <= 3'b0;
                        // Initialize Kadane's accumulators
                        curr_sum1 <= 32'sh0;
                        max_sum1 <= 32'sh0;
                        curr_sum2 <= 32'sh0;
                        max_sum2 <= 32'sh0;
                        state <= PROCESS;
                    end else begin
                        // Invalid n, go to DONE with 0 result
                        result <= 32'h0;
                        done <= 1'b1;
                        state <= DONE;
                    end
                end
                
                PROCESS: begin
                    // Iterate through n-1 differences
                    if (counter < n_reg - 1) begin
                        // Process current element for seq1
                        if (curr_sum1 + seq1_val > 0) begin
                            curr_sum1 <= curr_sum1 + seq1_val;
                        end else begin
                            curr_sum1 <= seq1_val;
                        end
                        
                        // Update max for seq1
                        if (curr_sum1 + seq1_val > max_sum1) begin
                            max_sum1 <= curr_sum1 + seq1_val;
                        end else if (curr_sum1 > max_sum1 && seq1_val > 0) begin
                            // Safety check (redundant with above)
                            max_sum1 <= curr_sum1;
                        end else if (seq1_val > max_sum1) begin
                            max_sum1 <= seq1_val;
                        end
                        
                        // Process current element for seq2
                        if (curr_sum2 + seq2_val > 0) begin
                            curr_sum2 <= curr_sum2 + seq2_val;
                        end else begin
                            curr_sum2 <= seq2_val;
                        end
                        
                        // Update max for seq2
                        if (curr_sum2 + seq2_val > max_sum2) begin
                            max_sum2 <= curr_sum2 + seq2_val;
                        end else if (curr_sum2 > max_sum2 && seq2_val > 0) begin
                            max_sum2 <= curr_sum2;
                        end else if (seq2_val > max_sum2) begin
                            max_sum2 <= seq2_val;
                        end
                        
                        counter <= counter + 1;
                    end else begin
                        // Need one more iteration to finalize current to max
                        // Final check: current could be the max
                        if (curr_sum1 > max_sum1)
                            max_sum1 <= curr_sum1;
                        if (curr_sum2 > max_sum2)
                            max_sum2 <= curr_sum2;
                            
                        state <= CALC;
                        counter <= 3'b0; // Reset for future use
                    end
                end
                
                CALC: begin
                    // Compare final max values
                    if (max_sum1 > max_sum2)
                        result <= max_sum1;
                    else
                        result <= max_sum2;
                    state <= DONE;
                end
                
                DONE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule