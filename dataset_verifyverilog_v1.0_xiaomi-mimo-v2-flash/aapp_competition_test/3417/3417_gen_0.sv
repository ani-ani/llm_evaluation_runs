module max_independent_set (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [255:0] adj_matrix,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] INIT     = 3'd1;
    localparam [2:0] CHECK    = 3'd2;
    localparam [2:0] COUNT    = 3'd3;
    localparam [2:0] UPDATE   = 3'd4;
    localparam [2:0] NEXT     = 3'd5;
    localparam [2:0] FINISH   = 3'd6;
    
    // Registers
    reg [2:0] state, next_state;
    reg [15:0] mask_counter;          // Current mask being checked
    reg [15:0] max_mask_counter;      // Maximum mask value (2^n - 1)
    reg [7:0] max_size;               // Track maximum independent set size
    reg [7:0] temp_max;               // Temporary max for current mask
    reg [3:0] i, j;                   // Loop counters for checking pairs
    reg [3:0] vertex_count;           // Count of vertices in current mask
    reg valid;                        // Flag indicating if mask is independent
    reg [7:0] bit_count;              // Count of set bits
    
    // Intermediate signals
    wire [3:0] i_plus_j;
    wire edge_bit;
    wire both_bits_set;
    
    // Calculate i*16 + j for edge lookup
    assign i_plus_j = i + j;
    assign edge_bit = adj_matrix[{i, j}];
    assign both_bits_set = mask_counter[i] && mask_counter[j];
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            mask_counter <= 16'd0;
            max_mask_counter <= 16'd0;
            max_size <= 8'd0;
            temp_max <= 8'd0;
            i <= 4'd0;
            j <= 4'd0;
            vertex_count <= 4'd0;
            valid <= 1'b0;
            bit_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 8'd0;
                    if (start) begin
                        // Initialize
                        mask_counter <= 16'd0;
                        max_size <= 8'd0;
                        max_mask_counter <= (16'd1 << n) - 16'd1;
                        i <= 4'd0;
                        j <= 4'd0;
                        vertex_count <= 4'd0;
                        valid <= 1'b1;  // Assume valid initially
                        temp_max <= 8'd0;
                        bit_count <= 8'd0;
                    end
                end
                
                INIT: begin
                    // Start checking for current mask
                    valid <= 1'b1;
                    i <= 4'd0;
                    j <= 4'd0;
                end
                
                CHECK: begin
                    // Check all pairs (i,j) where i<j and both in mask
                    if (i < n) begin
                        if (j < n) begin
                            if (j > i && both_bits_set && edge_bit) begin
                                valid <= 1'b0;  // Found edge, not independent
                            end
                            j <= j + 4'd1;
                        end else begin
                            j <= 4'd0;
                            i <= i + 4'd1;
                        end
                    end
                end
                
                COUNT: begin
                    // Count bits in mask if valid
                    if (valid) begin
                        bit_count <= 8'd0;
                    end else begin
                        temp_max <= 8'd0;  // Skip if not valid
                    end
                    i <= 4'd0;
                end
                
                UPDATE: begin
                    // Update maximum if this mask is better
                    if (valid && bit_count > max_size) begin
                        max_size <= bit_count;
                    end
                end
                
                NEXT: begin
                    // Move to next mask
                    if (mask_counter < max_mask_counter) begin
                        mask_counter <= mask_counter + 16'd1;
                    end
                end
                
                FINISH: begin
                    // All done
                    result <= max_size;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end else begin
                    next_state = IDLE;
                end
            end
            
            INIT: begin
                // Reset check counters
                next_state = CHECK;
            end
            
            CHECK: begin
                // Check all pairs
                if (i >= n && j == 4'd0) begin
                    next_state = COUNT;
                end else begin
                    next_state = CHECK;
                end
            end
            
            COUNT: begin
                // Count set bits in mask if valid
                if (valid) begin
                    if (i < n) begin
                        if (mask_counter[i]) begin
                            bit_count = bit_count + 8'd1;
                        end
                        i = i + 4'd1;
                        next_state = COUNT;
                    end else begin
                        next_state = UPDATE;
                    end
                end else begin
                    next_state = UPDATE;
                end
            end
            
            UPDATE: begin
                // Check if we're done
                if (mask_counter >= max_mask_counter) begin
                    next_state = FINISH;
                end else begin
                    next_state = NEXT;
                end
            end
            
            NEXT: begin
                // Move to next mask and restart checks
                next_state = INIT;
            end
            
            FINISH: begin
                // One cycle with done=1, then back to idle
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule