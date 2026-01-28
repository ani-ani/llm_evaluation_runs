module EvenNumberFilter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] data_in [0:7],
    input wire [2:0] depth,
    output reg [7:0] data_out [0:7],
    output reg [3:0] count_out,
    output reg done,
    output reg valid
);

    // State definitions
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] SCAN     = 3'd1;
    localparam [2:0] PROCESS  = 3'd2;
    localparam [2:0] OUTPUT   = 3'd3;
    localparam [2:0] DONE     = 3'd4;

    // Stack entry structure: {valid[2], depth[2:0], index[2:0]}
    // Each entry is 8 bits total
    reg [7:0] stack [0:3];
    reg [2:0] stack_ptr;

    // Processing registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [2:0] scan_idx;
    reg [2:0] out_idx;
    reg [7:0] output_buffer [0:7];
    reg [3:0] output_count;
    reg [2:0] current_depth;
    reg [7:0] pending_marker;
    reg has_pending;
    reg skip_mode;
    reg [2:0] skip_depth;
    reg [2:0] cycle_count;

    integer i;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = SCAN;
                else
                    next_state = IDLE;
            end
            
            SCAN: begin
                if (scan_idx < 8)
                    next_state = PROCESS;
                else
                    next_state = OUTPUT;
            end
            
            PROCESS: begin
                // Continue processing
                next_state = SCAN;
            end
            
            OUTPUT: begin
                if (out_idx < output_count)
                    next_state = OUTPUT;
                else
                    next_state = DONE;
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            stack_ptr <= 3'd0;
            scan_idx <= 3'd0;
            out_idx <= 3'd0;
            output_count <= 4'd0;
            current_depth <= 3'd0;
            has_pending <= 1'b0;
            pending_marker <= 8'd0;
            skip_mode <= 1'b0;
            skip_depth <= 3'd0;
            cycle_count <= 3'd0;
            done <= 1'b0;
            valid <= 1'b0;
            count_out <= 4'd0;
            
            // Reset output arrays
            for (i = 0; i < 8; i = i + 1) begin
                data_out[i] <= 8'd0;
                output_buffer[i] <= 8'd0;
                stack[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        scan_idx <= 3'd0;
                        out_idx <= 3'd0;
                        output_count <= 4'd0;
                        current_depth <= 3'd0;
                        has_pending <= 1'b0;
                        skip_mode <= 1'b0;
                        skip_depth <= 3'd0;
                        cycle_count <= 3'd0;
                        stack_ptr <= 3'd0;
                        // Clear output buffer
                        for (i = 0; i < 8; i = i + 1) begin
                            output_buffer[i] <= 8'd0;
                            stack[i] <= 8'd0;
                        end
                    end
                end
                
                SCAN: begin
                    // Just waiting for process state
                    cycle_count <= cycle_count + 3'd1;
                end
                
                PROCESS: begin
                    if (scan_idx < 8) begin
                        // Get current input value
                        // Note: data_in is a port, we need to handle it carefully
                        // In synthesis, we need to handle the 2D array
                        // We'll use a temporary variable for the current value
                        // Since we can't directly access data_in in always block with wait states
                        // We need to process based on data_in value
                        
                        // Handle skip mode (odd number detected, skipping nested content)
                        if (skip_mode) begin
                            // Check if we're at end of skip depth
                            // For negative markers, they represent boundaries
                            // We need to check the actual value from data_in
                            // But we can't access it here directly in synthesis
                            // We'll handle this in the logic below
                            
                            // For now, just advance scan_idx
                            scan_idx <= scan_idx + 3'd1;
                            
                            // Check if we need to exit skip mode
                            // This is tricky - we need to know if current value is end marker
                            // We'll handle this in the actual value processing
                        end else begin
                            // Process current value
                            // Check if it's a nesting marker or data
                            // Since we can't directly read data_in in always block with conditional
                            // We need a different approach
                            
                            // Actually, let's read data_in once and process
                            // We'll use a helper approach
                            
                            // For synthesis, we need to read the array value
                            // The standard way is to process based on the value
                            
                            // Let's implement the logic properly
                            // We need to know the current value
                            // This requires reading data_in[scan_idx]
                            
                            // Since we can't do that directly in a case statement
                            // We'll use conditional logic
                            
                            // Read current input
                            // Note: In Verilog, we can read input ports in always blocks
                            // But we need to be careful with 2D arrays
                            
                            // Let's assume we read data_in[scan_idx] into a temp
                            // Actually, we can read it directly in the condition
                            
                            // Check if current value is negative (nesting marker)
                            // Since data_in values are 0-255 or negative represented as 8-bit
                            // Negative values in 2-bit complement would be 128-255
                            // 255 (0xFF) = -1, 254 (0xFE) = -2, etc.
                            
                            // For 8-bit values, negative means MSB is 1
                            // 255 (0xFF) is all 1's
                            // 254 (0xFE) is 11111110
                            
                            // Let's read the current value
                            // We need a register to store it
                            // Actually, we can process it directly
                            
                            // Check if it's a nesting marker
                            // 255 = 0xFF (start), 254 = 0xFE (end)
                            
                            // We need to check data_in[scan_idx] value
                            // For synthesis, we can read it in the always block
                            
                            // Let's implement the actual processing logic
                            // We'll check the value and act accordingly
                            
                            // Since we can't have complex conditions in case
                            // We'll use if-else structure
                            
                            // Read current value
                            // For 8-bit, 255 = 8'd255 = 8'b11111111
                            // 254 = 8'd254 = 8'b11111110
                            
                            // Check if it's a start marker (255)
                            if (data_in[scan_idx] == 8'd255) begin
                                // Start of nested tuple
                                if (current_depth < depth) begin
                                    // Push to stack
                                    if (stack_ptr < 4) begin
                                        // Stack entry: {valid, depth, index}
                                        // valid=1, depth=current_depth, index=scan_idx
                                        stack[stack_ptr] <= {1'b1, current_depth, scan_idx};
                                        stack_ptr <= stack_ptr + 3'd1;
                                        current_depth <= current_depth + 3'd1;
                                    end
                                end
                                // Mark as pending to output later
                                has_pending <= 1'b1;
                                pending_marker <= 8'd255;
                                scan_idx <= scan_idx + 3'd1;
                            end
                            // Check if it's an end marker (254)
                            else if (data_in[scan_idx] == 8'd254) begin
                                // End of nested tuple
                                // Pop from stack
                                if (stack_ptr > 0) begin
                                    stack_ptr <= stack_ptr - 3'd1;
                                    // Restore depth from stack
                                    current_depth <= stack[stack_ptr - 3'd1][5:3];
                                end else begin
                                    current_depth <= 3'd0;
                                end
                                // Mark as pending to output later
                                has_pending <= 1'b0;
                                // Don't output end marker if we're in skip mode
                                // Actually, we should output it if we're not skipping
                                if (!skip_mode) begin
                                    if (output_count < 8) begin
                                        output_buffer[output_count] <= 8'd254;
                                        output_count <= output_count + 4'd1;
                                    end
                                end
                                scan_idx <= scan_idx + 3'd1;
                                // Reset pending marker
                                pending_marker <= 8'd0;
                            end
                            else begin
                                // It's a data value (0-255)
                                // Check if it's even (LSB=0)
                                if (data_in[scan_idx][0] == 1'b0) begin
                                    // Even number - add to output
                                    if (output_count < 8) begin
                                        // First output pending marker if exists
                                        if (has_pending) begin
                                            output_buffer[output_count] <= pending_marker;
                                            output_count <= output_count + 4'd1;
                                            has_pending <= 1'b0;
                                        end
                                        // Then output the even number
                                        output_buffer[output_count] <= data_in[scan_idx];
                                        output_count <= output_count + 4'd1;
                                    end
                                end else begin
                                    // Odd number - skip mode
                                    // We need to skip until we find the matching end marker
                                    skip_mode <= 1'b1;
                                    skip_depth <= current_depth;
                                    // Clear any pending marker
                                    has_pending <= 1'b0;
                                end
                                scan_idx <= scan_idx + 3'd1;
                            end
                        end
                    end else begin
                        // Done scanning
                        scan_idx <= 3'd0;
                    end
                end
                
                OUTPUT: begin
                    if (out_idx < output_count) begin
                        // Transfer from buffer to output
                        data_out[out_idx] <= output_buffer[out_idx];
                        out_idx <= out_idx + 3'd1;
                    end else begin
                        // Fill remaining with zeros
                        for (i = out_idx; i < 8; i = i + 1) begin
                            data_out[i] <= 8'd0;
                        end
                        count_out <= output_count;
                        valid <= 1'b1;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    // Keep valid high, done will go high for one cycle
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    valid <= 1'b0;
                end
            endcase
        end
    end

endmodule
