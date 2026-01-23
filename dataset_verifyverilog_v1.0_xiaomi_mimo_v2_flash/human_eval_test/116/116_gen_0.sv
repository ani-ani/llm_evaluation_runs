module sort_array (
    input clk,
    input rst_n,
    input start,
    input [7:0] len,
    input [31:0] arr [0:7],
    output reg [31:0] result [0:7],
    output reg done
);

    // State declarations
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] LOAD        = 4'd1;
    localparam [3:0] INIT_PASS   = 4'd2;
    localparam [3:0] COMPARE     = 4'd3;
    localparam [3:0] SWAP        = 4'd4;
    localparam [3:0] NEXT_PAIR   = 4'd5;
    localparam [3:0] NEXT_PASS   = 4'd6;
    localparam [3:0] FINISHED    = 4'd7;
    
    // Internal registers
    reg [3:0] state, next_state;
    reg [3:0] i;           // Outer loop counter (pass number)
    reg [3:0] j;           // Inner loop counter (pair index)
    reg [31:0] buffer [0:7];  // Internal buffer for sorting
    reg [31:0] temp_val;      // Temporary for swap
    reg swap_needed;          // Flag to indicate swap required
    
    // Popcount computation registers
    reg [31:0] pc_a, pc_b;    // Values to compute popcount for
    reg [5:0] pc_count_a, pc_count_b;  // Popcount results (max 32 ones)
    reg [4:0] pc_bit_idx;     // Bit index for popcount
    reg pc_done;              // Popcount computation complete
    
    // Cycle counter for timeout prevention
    reg [11:0] cycle_count;
    localparam [11:0] MAX_CYCLES = 12'd4095;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result[0] <= 32'd0;
            result[1] <= 32'd0;
            result[2] <= 32'd0;
            result[3] <= 32'd0;
            result[4] <= 32'd0;
            result[5] <= 32'd0;
            result[6] <= 32'd0;
            result[7] <= 32'd0;
            done <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            buffer[0] <= 32'd0;
            buffer[1] <= 32'd0;
            buffer[2] <= 32'd0;
            buffer[3] <= 32'd0;
            buffer[4] <= 32'd0;
            buffer[5] <= 32'd0;
            buffer[6] <= 32'd0;
            buffer[7] <= 32'd0;
            temp_val <= 32'd0;
            swap_needed <= 1'b0;
            pc_a <= 32'd0;
            pc_b <= 32'd0;
            pc_count_a <= 6'd0;
            pc_count_b <= 6'd0;
            pc_bit_idx <= 5'd0;
            pc_done <= 1'b0;
            cycle_count <= 12'd0;
        end else begin
            state <= next_state;
            
            // Cycle counter increment
            if (state != IDLE) begin
                cycle_count <= cycle_count + 12'd1;
            end else begin
                cycle_count <= 12'd0;
            end
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 12'd0;
                    // Initialize all buffer elements
                    buffer[0] <= 32'd0;
                    buffer[1] <= 32'd0;
                    buffer[2] <= 32'd0;
                    buffer[3] <= 32'd0;
                    buffer[4] <= 32'd0;
                    buffer[5] <= 32'd0;
                    buffer[6] <= 32'd0;
                    buffer[7] <= 32'd0;
                    if (start) begin
                        i <= 4'd0;
                        j <= 4'd0;
                        pc_a <= 32'd0;
                        pc_b <= 32'd0;
                        pc_count_a <= 6'd0;
                        pc_count_b <= 6'd0;
                        pc_bit_idx <= 5'd0;
                        pc_done <= 1'b0;
                    end
                end
                
                LOAD: begin
                    // Copy input array to internal buffer
                    buffer[0] <= arr[0];
                    buffer[1] <= arr[1];
                    buffer[2] <= arr[2];
                    buffer[3] <= arr[3];
                    buffer[4] <= arr[4];
                    buffer[5] <= arr[5];
                    buffer[6] <= arr[6];
                    buffer[7] <= arr[7];
                end
                
                INIT_PASS: begin
                    i <= 4'd0;
                    j <= 4'd0;
                    pc_a <= 32'd0;
                    pc_b <= 32'd0;
                    pc_count_a <= 6'd0;
                    pc_count_b <= 6'd0;
                    pc_bit_idx <= 5'd0;
                    pc_done <= 1'b0;
                end
                
                COMPARE: begin
                    // Initialize popcount computation
                    pc_a <= buffer[j];
                    pc_b <= buffer[j + 1];
                    pc_count_a <= 6'd0;
                    pc_count_b <= 6'd0;
                    pc_bit_idx <= 5'd0;
                    pc_done <= 1'b0;
                    
                    // Single iteration of bit counting
                    // Count bits in pc_a
                    if (pc_a[pc_bit_idx]) begin
                        pc_count_a <= pc_count_a + 6'd1;
                    end
                    // Count bits in pc_b
                    if (pc_b[pc_bit_idx]) begin
                        pc_count_b <= pc_count_b + 6'd1;
                    end
                    
                    pc_bit_idx <= pc_bit_idx + 5'd1;
                    
                    if (pc_bit_idx == 5'd31) begin
                        pc_done <= 1'b1;
                        // Final count for last bit
                        if (pc_a[31]) begin
                            pc_count_a <= pc_count_a + 6'd1;
                        end
                        if (pc_b[31]) begin
                            pc_count_b <= pc_count_b + 6'd1;
                        end
                    end
                end
                
                SWAP: begin
                    // Perform swap if needed
                    if (swap_needed) begin
                        temp_val <= buffer[j];
                        buffer[j] <= buffer[j + 1];
                        buffer[j + 1] <= temp_val;
                    end
                end
                
                NEXT_PAIR: begin
                    j <= j + 4'd1;
                    // Reset popcount for next comparison
                    pc_a <= 32'd0;
                    pc_b <= 32'd0;
                    pc_count_a <= 6'd0;
                    pc_count_b <= 6'd0;
                    pc_bit_idx <= 5'd0;
                    pc_done <= 1'b0;
                end
                
                NEXT_PASS: begin
                    i <= i + 4'd1;
                    j <= 4'd0;
                    // Reset popcount for next pass
                    pc_a <= 32'd0;
                    pc_b <= 32'd0;
                    pc_count_a <= 6'd0;
                    pc_count_b <= 6'd0;
                    pc_bit_idx <= 5'd0;
                    pc_done <= 1'b0;
                end
                
                FINISHED: begin
                    // Copy sorted buffer to output
                    result[0] <= buffer[0];
                    result[1] <= buffer[1];
                    result[2] <= buffer[2];
                    result[3] <= buffer[3];
                    result[4] <= buffer[4];
                    result[5] <= buffer[5];
                    result[6] <= buffer[6];
                    result[7] <= buffer[7];
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        swap_needed = 1'b0;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end
            
            LOAD: begin
                next_state = INIT_PASS;
            end
            
            INIT_PASS: begin
                // Check if more passes needed (i < len - 1)
                if (len <= 8'd1 || i >= len - 8'd1) begin
                    next_state = FINISHED;
                end else begin
                    next_state = COMPARE;
                end
            end
            
            COMPARE: begin
                // Wait for popcount computation (done after bit_idx reaches 31)
                if (pc_done) begin
                    // Compare popcounts first, then values
                    if (pc_count_a < pc_count_b) begin
                        // Element a has fewer ones - correct order
                        swap_needed = 1'b0;
                        next_state = NEXT_PAIR;
                    end else if (pc_count_a > pc_count_b) begin
                        // Element b has fewer ones - swap needed
                        swap_needed = 1'b1;
                        next_state = SWAP;
                    end else begin
                        // Equal popcounts, compare decimal values
                        if (pc_a < pc_b) begin
                            // a is smaller - correct order
                            swap_needed = 1'b0;
                            next_state = NEXT_PAIR;
                        end else begin
                            // b is smaller or equal - swap (or keep equal)
                            swap_needed = 1'b1;
                            next_state = SWAP;
                        end
                    end
                end
            end
            
            SWAP: begin
                next_state = NEXT_PAIR;
            end
            
            NEXT_PAIR: begin
                // Check if done with this pass (j >= len - i - 2)
                if (j >= len - i - 8'd2) begin
                    next_state = NEXT_PASS;
                end else begin
                    next_state = COMPARE;
                end
            end
            
            NEXT_PASS: begin
                next_state = INIT_PASS;
            end
            
            FINISHED: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
        
        // Timeout safety
        if (cycle_count >= MAX_CYCLES) begin
            next_state = FINISHED;
        end
    end

endmodule