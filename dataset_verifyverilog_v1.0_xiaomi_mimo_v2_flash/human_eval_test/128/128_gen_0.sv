module prod_signs (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire valid,
    input wire signed [7:0] arr [0:7],
    output reg signed [15:0] result,
    output reg done
);
    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE    = 2'd2;
    
    // Internal registers
    reg [1:0] state, next_state;
    reg [2:0] index;           // Index for iterating through array (0-7)
    reg signed [7:0] current_val;
    reg signed [15:0] sum_mag; // Sum of magnitudes (10-bit max, use 16-bit)
    reg signed [1:0] prod_sign; // Product of signs (-1, 0, or 1)
    reg valid_latched;
    reg signed [15:0] temp_result;
    reg done_internal;
    
    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 3'd0;
            sum_mag <= 16'sd0;
            prod_sign <= 2'sd0;
            valid_latched <= 1'b0;
            temp_result <= 16'sd0;
            result <= 16'sd0;
            done <= 1'b0;
            done_internal <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    done_internal <= 1'b0;
                    index <= 3'd0;
                    sum_mag <= 16'sd0;
                    prod_sign <= 2'sd0;
                    if (start) begin
                        state <= COMPUTE;
                        valid_latched <= valid;
                        // Initialize sign product: 1 means positive, -1 negative, 0 neutral
                        // We use 1 for positive, -1 for negative (encoded as 2's comp)
                        // Start with 1 (positive) - if any zero found, becomes 0
                        // If any negative found and no zeros, flips to -1
                        // Strategy: prod_sign = 0 if zero found
                        //           prod_sign = 1 if all positive
                        //           prod_sign = -1 if odd number of negatives and no zeros
                        prod_sign <= 2'sd1; // Assume positive initially
                    end
                end
                
                COMPUTE: begin
                    if (valid_latched) begin
                        if (index < 3'd8) begin
                            current_val <= arr[index];
                            
                            // Process current element
                            // Magnitude: |x| = x >= 0 ? x : -x
                            if (arr[index] >= 8'sd0) begin
                                sum_mag <= sum_mag + {8'd0, arr[index]};
                                // prod_sign stays same if positive
                            end else begin
                                sum_mag <= sum_mag + {8'd0, (~arr[index] + 8'sd1)}; // abs(neg)
                                // Flip sign for negative (1 -> -1, -1 -> 1)
                                prod_sign <= -prod_sign;
                            end
                            
                            // Check for zero
                            if (arr[index] == 8'sd0) begin
                                prod_sign <= 2'sd0; // Zero makes product zero
                            end
                            
                            index <= index + 3'd1;
                        end else begin
                            // All elements processed, compute final result
                            // Result = prod_sign * sum_mag
                            temp_result <= prod_sign * sum_mag;
                            done_internal <= 1'b1;
                            state <= DONE;
                        end
                    end else begin
                        // Empty array case (valid=0)
                        temp_result <= 16'sd0;
                        done_internal <= 1'b1;
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    result <= temp_result;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule