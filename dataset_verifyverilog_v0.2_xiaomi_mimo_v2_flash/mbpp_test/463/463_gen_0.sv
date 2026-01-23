module max_product_subarray (
    input clk,
    input rst_n,
    input start,
    input [5:0] array_length,
    input [15:0] array_data [0:7],
    output reg [31:0] result,
    output reg done
);

    parameter ARRAY_MAX = 8;
    
    // State definition
    localparam IDLE = 2'b00;
    localparam PROCESS_ELEMENT = 2'b01;
    localparam UPDATE_RESULT = 2'b10;
    localparam DONE = 2'b11;
    
    // Internal registers
    reg [1:0] current_state, next_state;
    reg [2:0] index, next_index; // Counter for array index (0 to 7)
    reg [31:0] max_ending_here, next_max_ending_here;
    reg [31:0] min_ending_here, next_min_ending_here;
    reg [31:0] max_so_far, next_max_so_far;
    reg has_positive, next_has_positive;
    reg [5:0] length_reg, next_length_reg;
    
    // Combinational logic for Q16.16 conversion
    wire [31:0] current_val_q16;
    assign current_val_q16 = {array_data[index][15], array_data[index][15:0], 16'b0};
    
    // Combinational logic for multiplication
    wire signed [31:0] prod_max;
    wire signed [31:0] prod_min;
    
    // Multiplication logic: 16-bit signed * Q16.16 (treat Q16.16 as 32-bit signed)
    // Since input is integer, we multiply integer * Q16.16
    // array_data[index] is 16-bit signed integer
    // max_ending_here/min_ending_here are Q16.16
    // Result is Q32.16, we need to shift right by 16 to get Q16.16
    
    wire signed [47:0] full_prod_max;
    wire signed [47:0] full_prod_min;
    
    assign full_prod_max = $signed({{16{array_data[index][15]}}, array_data[index]}) * $signed(max_ending_here);
    assign full_prod_min = $signed({{16{array_data[index][15]}}, array_data[index]}) * $signed(min_ending_here);
    
    // Truncate to 32 bits (upper 32 bits of 48-bit result, keeping Q16.16 format)
    // Since it's integer * Q16.16, result is Q32.16. Shift right by 16 to get Q16.16
    wire [31:0] prod_max_shifted;
    wire [31:0] prod_min_shifted;
    
    assign prod_max_shifted = full_prod_max[47] ? full_prod_max[47:16] : full_prod_max[47:16];
    assign prod_min_shifted = full_prod_min[47] ? full_prod_min[47:16] : full_prod_min[47:16];
    
    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            index <= 0;
            max_ending_here <= 32'sd0;
            min_ending_here <= 32'sd0;
            max_so_far <= 32'sd0;
            has_positive <= 1'b0;
            length_reg <= 6'd0;
        end else begin
            current_state <= next_state;
            index <= next_index;
            max_ending_here <= next_max_ending_here;
            min_ending_here <= next_min_ending_here;
            max_so_far <= next_max_so_far;
            has_positive <= next_has_positive;
            length_reg <= next_length_reg;
        end
    end
    
    // Next state logic
    always @(*) begin
        // Default assignments
        next_state = current_state;
        next_index = index;
        next_max_ending_here = max_ending_here;
        next_min_ending_here = min_ending_here;
        next_max_so_far = max_so_far;
        next_has_positive = has_positive;
        next_length_reg = length_reg;
        done = 1'b0;
        result = 32'd0;
        
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESS_ELEMENT;
                    next_index = 0;
                    next_length_reg = array_length;
                    // Initialize with first element
                    if (array_length > 0) begin
                        next_max_ending_here = {array_data[0][15], array_data[0][15:0], 16'b0};
                        next_min_ending_here = {array_data[0][15], array_data[0][15:0], 16'b0};
                        next_max_so_far = {array_data[0][15], array_data[0][15:0], 16'b0};
                        next_has_positive = (array_data[0] > 0);
                    end else begin
                        next_max_ending_here = 32'sd0;
                        next_min_ending_here = 32'sd0;
                        next_max_so_far = 32'sd0;
                        next_has_positive = 1'b0;
                    end
                end else begin
                    next_state = IDLE;
                end
            end
            
            PROCESS_ELEMENT: begin
                // Calculate new max/min ending here
                // Need to handle the multiplication and comparison
                // Since we can't use combinational always block for state transitions with multiplication,
                // we handle the logic directly
                
                if (index < length_reg - 1) begin
                    next_state = UPDATE_RESULT;
                    next_index = index;
                    // Keep current values
                end else begin
                    next_state = DONE;
                    // Final result needs to be set in DONE state
                end
            end
            
            UPDATE_RESULT: begin
                // Update based on current element
                // Current element value in Q16.16
                // We need to recompute the multiplication results here since PROCESS_ELEMENT doesn't have them
                
                // Calculate products
                // prod_max_shifted and prod_min_shifted are already computed
                
                // Compare and update max_ending_here and min_ending_here
                // Three candidates for max_ending_here: max_ending_here * val, min_ending_here * val, val
                // Three candidates for min_ending_here: max_ending_here * val, min_ending_here * val, val
                
                reg [31:0] temp_max;
                reg [31:0] temp_min;
                
                temp_max = prod_max_shifted;
                if ($signed(prod_min_shifted) > $signed(temp_max)) temp_max = prod_min_shifted;
                if ($signed(current_val_q16) > $signed(temp_max)) temp_max = current_val_q16;
                
                temp_min = prod_max_shifted;
                if ($signed(prod_min_shifted) < $signed(temp_min)) temp_min = prod_min_shifted;
                if ($signed(current_val_q16) < $signed(temp_min)) temp_min = current_val_q16;
                
                next_max_ending_here = temp_max;
                next_min_ending_here = temp_min;
                
                // Update max_so_far
                if ($signed(temp_max) > $signed(max_so_far)) begin
                    next_max_so_far = temp_max;
                end
                
                // Update positive flag
                if ($signed(array_data[index]) > 0) begin
                    next_has_positive = 1'b1;
                end
                
                next_index = index + 1;
                
                if (next_index < length_reg) begin
                    next_state = PROCESS_ELEMENT;
                end else begin
                    next_state = DONE;
                end
            end
            
            DONE: begin
                done = 1'b1;
                // Return 0 if no positive number was found and at least one element exists
                if (length_reg > 0 && !has_positive) begin
                    result = 32'd0;
                end else begin
                    result = max_so_far;
                end
                next_state = IDLE;
                next_index = 0;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule
