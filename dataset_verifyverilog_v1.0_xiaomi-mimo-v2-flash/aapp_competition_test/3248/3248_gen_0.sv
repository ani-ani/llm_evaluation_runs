module CountUntileable (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] street,
    input wire [63:0] pattern_len,
    input wire [1023:0] patterns,
    input wire [3:0] M,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] LOAD     = 3'd1;
    localparam [2:0] CHECK    = 3'd2;
    localparam [2:0] COUNT    = 3'd3;
    localparam [2:0] FINISH   = 3'd4;

    // Registers
    reg [2:0] state, next_state;
    reg [3:0] pattern_idx;
    reg [3:0] pos_idx;
    reg [3:0] pop_idx;
    reg [15:0] coverage_mask;
    reg [15:0] temp_result;
    reg match_found;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Next state logic
    always @(*) begin
        next_state = IDLE;
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
                else next_state = IDLE;
            end
            LOAD: next_state = CHECK;
            CHECK: begin
                if (pattern_idx >= M) next_state = COUNT;
                else next_state = CHECK;
            end
            COUNT: begin
                if (pop_idx >= 16) next_state = FINISH;
                else next_state = COUNT;
            end
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pattern_idx <= 4'd0;
            pos_idx <= 4'd0;
            pop_idx <= 4'd0;
            coverage_mask <= 16'd0;
            temp_result <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            cycle_count <= cycle_count + 8'd1;
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        coverage_mask <= 16'd0;
                        pattern_idx <= 4'd0;
                        pos_idx <= 4'd0;
                    end
                end
                
                LOAD: begin
                    // Initialize for checking
                    pos_idx <= 4'd0;
                end
                
                CHECK: begin
                    if (pos_idx < 16) begin
                        // Extract pattern length for current pattern
                        // pattern_len is 64-bit, each 8 bits for 8 patterns
                        // pattern_len[7:0] = pattern[0] len, pattern_len[15:8] = pattern[1] len, etc.
                        // Extract len for pattern_idx
                        // Since pattern_idx max is 7 (8 patterns), we need to select proper byte
                        // Each pattern_len is 8 bits, but stored as 64-bit vector
                        // pattern_len[7:0] is pattern 0, pattern_len[15:8] is pattern 1, etc.
                        // Actually spec says pattern_len[0:7] as 8 patterns, each is presumably an integer
                        // Let's treat as array of 8 integers: pattern_len[7:0] is len of pattern 0, pattern_len[15:8] is len of pattern 1, etc.
                        // But pattern_len is defined as 64-bit input, so each 8-bit slice is a length
                        // Wait: spec says pattern_len[0:7] (8 patterns), likely meaning 8 elements each some size
                        // But input is defined as [63:0], which is 64 bits. Could be 8*8 bit lengths.
                        // Let's extract as 8-bit chunks: index pattern_idx gives bits 7:0 for each pattern
                        // Actually, if pattern_len is 64-bit, and we have 8 patterns, each length could be 8 bits
                        // So pattern_len[7:0] = len of pattern 0, pattern_len[15:8] = len of pattern 1, etc.
                        // To extract len for pattern_idx:
                        // len = pattern_len[ (pattern_idx*8) +: 8 ]
                        // But need to calculate shift. Since pattern_idx is 0-7, shift = pattern_idx * 8
                        // To avoid dynamic shift in synthesis, we can use a for loop or case
                        // Let's use a helper wire for len extraction
                        // For simplicity, we'll use if-else or assume pattern_len is arranged
                        // Actually, let's use a wire for the current length
                        wire [7:0] current_len;
                        // Since we can't declare wire inside always, we'll pre-calculate or use combinational logic
                    end
                    
                    // State transition logic for CHECK
                    // We need to check position pos_idx against pattern pattern_idx
                    // Only if pos_idx < current_len
                    // Get current pattern length
                    // We need to extract 8 bits from pattern_len based on pattern_idx
                    // pattern_len[7:0] for pattern 0, [15:8] for pattern 1, etc.
                    // So: current_len = pattern_len[ (pattern_idx << 3) +: 8 ]
                    // Since pattern_idx is 0-7, shift is 0,8,16,...,56
                    // We can use a temp wire or just compute
                    // Let's use a temporary register to hold current_len
                    // But better: compute in combinational logic outside or use if-else
                    // For synthesis, we can unroll with if-else
                    // However, since CHECK is sequential, we need to extract here
                    // Let's create a combinational block or use always @* inside
                    // Actually, we can compute it in the same always block if we use blocking assignment
                    // But we're using non-blocking for state machines
                    // Let's add a combinational logic for len extraction
                    // We'll do it by creating a wire outside
                    // Since we're in always @, we can use blocking assignment if we make next_state separate
                    // But we already have next_state logic separate
                    // Let's use a combinational block at top for extraction
                end
                
                // We need to fix the logic: extraction must be combinational
                // Let's restructure: add combinational logic for matching
            endcase
        end
    end

    // Add combinational logic for length extraction and matching
    // This avoids problems with extracting in sequential block
    wire [7:0] current_pattern_len;
    assign current_pattern_len = pattern_len[ (pattern_idx * 8) +: 8 ];
    
    // Extract character from street at pos_idx
    wire [7:0] street_char;
    assign street_char = street[ (pos_idx * 8) +: 8 ];
    
    // Extract character from current pattern at pos_idx
    // Pattern is at patterns[ (pattern_idx * 128) +: 128 ] (since each pattern is 16*8=128 bits)
    // Each pattern is 128 bits, 16 chars of 8 bits each
    wire [127:0] current_pattern;
    assign current_pattern = patterns[ (pattern_idx * 128) +: 128 ];
    
    wire [7:0] pattern_char;
    assign pattern_char = current_pattern[ (pos_idx * 8) +: 8 ];
    
    // Match condition
    wire match;
    assign match = (street_char == pattern_char) && (pos_idx < current_pattern_len);
    
    // Update CHECK logic in sequential block
    // Since we have combinational logic for match, we can use it
    // We need to modify the sequential block to use this
    // Let's redo the sequential logic block with proper use of combinational signals

endmodule

// Redo the module with corrected logic
module CountUntileable (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] street,
    input wire [63:0] pattern_len,
    input wire [1023:0] patterns,
    input wire [3:0] M,
    output reg [15:0] result,
    output reg done
);

    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] LOAD     = 3'd1;
    localparam [2:0] CHECK    = 3'd2;
    localparam [2:0] COUNT    = 3'd3;
    localparam [2:0] FINISH   = 3'd4;

    reg [2:0] state, next_state;
    reg [3:0] pattern_idx;
    reg [3:0] pos_idx;
    reg [3:0] pop_idx;
    reg [15:0] coverage_mask;
    reg [15:0] temp_result;
    reg match_found;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Combinational signals for current pattern extraction
    wire [7:0] current_len;
    wire [127:0] current_pattern;
    wire [7:0] street_char;
    wire [7:0] pattern_char;
    wire match;
    
    // Extract current pattern length (8 patterns, each 8 bits)
    assign current_len = pattern_len[ (pattern_idx * 8) +: 8 ];
    
    // Extract street character at pos_idx
    assign street_char = street[ (pos_idx * 8) +: 8 ];
    
    // Extract current pattern
    assign current_pattern = patterns[ (pattern_idx * 128) +: 128 ];
    
    // Extract pattern character at pos_idx
    assign pattern_char = current_pattern[ (pos_idx * 8) +: 8 ];
    
    // Determine match
    assign match = (street_char == pattern_char) && (pos_idx < current_len);

    // Next state logic
    always @(*) begin
        next_state = IDLE;
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
                else next_state = IDLE;
            end
            LOAD: next_state = CHECK;
            CHECK: begin
                if (pattern_idx >= M) next_state = COUNT;
                else next_state = CHECK;
            end
            COUNT: begin
                if (pop_idx >= 16) next_state = FINISH;
                else next_state = COUNT;
            end
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pattern_idx <= 4'd0;
            pos_idx <= 4'd0;
            pop_idx <= 4'd0;
            coverage_mask <= 16'd0;
            temp_result <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            cycle_count <= cycle_count + 8'd1;
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        coverage_mask <= 16'd0;
                        pattern_idx <= 4'd0;
                        pos_idx <= 4'd0;
                    end
                end
                
                LOAD: begin
                    // Initialize for checking
                    pos_idx <= 4'd0;
                end
                
                CHECK: begin
                    if (pos_idx < 16) begin
                        // Check match
                        if (match) begin
                            // Set bit in coverage mask
                            coverage_mask <= coverage_mask | (16'b1 << pos_idx);
                        end
                        // Move to next position
                        pos_idx <= pos_idx + 4'd1;
                    end else begin
                        // Done with current pattern, move to next pattern
                        pos_idx <= 4'd0;
                        pattern_idx <= pattern_idx + 4'd1;
                    end
                end
                
                COUNT: begin
                    // Popcount complement
                    if (pop_idx < 16) begin
                        // Check each bit in coverage_mask
                        // Since we need to count zeros, we can count ones then subtract from 16
                        // Or count zeros directly
                        // Use pop_idx to iterate through bits
                        if (!(coverage_mask[pop_idx])) begin
                            temp_result <= temp_result + 16'd1;
                        end
                        pop_idx <= pop_idx + 4'd1;
                    end
                end
                
                FINISH: begin
                    result <= temp_result;
                    done <= 1'b1;
                    pop_idx <= 4'd0;
                    temp_result <= 16'd0;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule