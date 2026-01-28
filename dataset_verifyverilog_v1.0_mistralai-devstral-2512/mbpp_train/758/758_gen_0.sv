module SublistCounter(
    input clk,
    input rst_n,
    input start,
    input [7:0] sublist_0_0,
    input [7:0] sublist_0_1,
    input [7:0] sublist_0_2,
    input [7:0] sublist_0_3,
    input [7:0] sublist_1_0,
    input [7:0] sublist_1_1,
    input [7:0] sublist_1_2,
    input [7:0] sublist_1_3,
    input [7:0] sublist_2_0,
    input [7:0] sublist_2_1,
    input [7:0] sublist_2_2,
    input [7:0] sublist_2_3,
    input [7:0] sublist_3_0,
    input [7:0] sublist_3_1,
    input [7:0] sublist_3_2,
    input [7:0] sublist_3_3,
    output reg [3:0] result_valid,
    output reg [3:0] [31:0] result_hash,
    output reg [3:0] [7:0] result_count,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LATCH = 3'd1;
    localparam [2:0] HASH = 3'd2;
    localparam [2:0] COMPARE = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Latch registers for sublists
    reg [7:0] latched_sublist_0_0;
    reg [7:0] latched_sublist_0_1;
    reg [7:0] latched_sublist_0_2;
    reg [7:0] latched_sublist_0_3;
    reg [7:0] latched_sublist_1_0;
    reg [7:0] latched_sublist_1_1;
    reg [7:0] latched_sublist_1_2;
    reg [7:0] latched_sublist_1_3;
    reg [7:0] latched_sublist_2_0;
    reg [7:0] latched_sublist_2_1;
    reg [7:0] latched_sublist_2_2;
    reg [7:0] latched_sublist_2_3;
    reg [7:0] latched_sublist_3_0;
    reg [7:0] latched_sublist_3_1;
    reg [7:0] latched_sublist_3_2;
    reg [7:0] latched_sublist_3_3;

    // Hash computation registers
    reg [31:0] hash_0;
    reg [31:0] hash_1;
    reg [31:0] hash_2;
    reg [31:0] hash_3;
    reg [3:0] hash_index;

    // Comparison and counting registers
    reg [3:0] unique_count;
    reg [3:0] current_sublist;
    reg [3:0] compare_index;
    reg [3:0] found_match;

    // FNV-1a constants
    localparam [31:0] FNV_OFFSET = 32'h811c9dc5;
    localparam [31:0] FNV_PRIME = 32'h01000193;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            done <= 1'b0;
            result_valid <= 4'd0;
            
            // Initialize all result registers
            result_hash[0] <= 32'd0;
            result_hash[1] <= 32'd0;
            result_hash[2] <= 32'd0;
            result_hash[3] <= 32'd0;
            result_count[0] <= 8'd0;
            result_count[1] <= 8'd0;
            result_count[2] <= 8'd0;
            result_count[3] <= 8'd0;
            
            // Initialize hash computation registers
            hash_0 <= 32'd0;
            hash_1 <= 32'd0;
            hash_2 <= 32'd0;
            hash_3 <= 32'd0;
            hash_index <= 4'd0;
            
            // Initialize comparison registers
            unique_count <= 4'd0;
            current_sublist <= 4'd0;
            compare_index <= 4'd0;
            found_match <= 4'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LATCH;
                    end
                end
                
                LATCH: begin
                    // Latch all input sublists
                    latched_sublist_0_0 <= sublist_0_0;
                    latched_sublist_0_1 <= sublist_0_1;
                    latched_sublist_0_2 <= sublist_0_2;
                    latched_sublist_0_3 <= sublist_0_3;
                    latched_sublist_1_0 <= sublist_1_0;
                    latched_sublist_1_1 <= sublist_1_1;
                    latched_sublist_1_2 <= sublist_1_2;
                    latched_sublist_1_3 <= sublist_1_3;
                    latched_sublist_2_0 <= sublist_2_0;
                    latched_sublist_2_1 <= sublist_2_1;
                    latched_sublist_2_2 <= sublist_2_2;
                    latched_sublist_2_3 <= sublist_2_3;
                    latched_sublist_3_0 <= sublist_3_0;
                    latched_sublist_3_1 <= sublist_3_1;
                    latched_sublist_3_2 <= sublist_3_2;
                    latched_sublist_3_3 <= sublist_3_3;
                    
                    // Initialize hash computation
                    hash_0 <= FNV_OFFSET;
                    hash_1 <= FNV_OFFSET;
                    hash_2 <= FNV_OFFSET;
                    hash_3 <= FNV_OFFSET;
                    hash_index <= 4'd0;
                    
                    next_state <= HASH;
                end
                
                HASH: begin
                    // Compute hashes for all sublists
                    if (hash_index < 4'd4) begin
                        // Process byte for each sublist
                        case (hash_index)
                            4'd0: begin
                                hash_0 <= (hash_0 ^ latched_sublist_0_0) * FNV_PRIME;
                                hash_1 <= (hash_1 ^ latched_sublist_1_0) * FNV_PRIME;
                                hash_2 <= (hash_2 ^ latched_sublist_2_0) * FNV_PRIME;
                                hash_3 <= (hash_3 ^ latched_sublist_3_0) * FNV_PRIME;
                            end
                            4'd1: begin
                                hash_0 <= (hash_0 ^ latched_sublist_0_1) * FNV_PRIME;
                                hash_1 <= (hash_1 ^ latched_sublist_1_1) * FNV_PRIME;
                                hash_2 <= (hash_2 ^ latched_sublist_2_1) * FNV_PRIME;
                                hash_3 <= (hash_3 ^ latched_sublist_3_1) * FNV_PRIME;
                            end
                            4'd2: begin
                                hash_0 <= (hash_0 ^ latched_sublist_0_2) * FNV_PRIME;
                                hash_1 <= (hash_1 ^ latched_sublist_1_2) * FNV_PRIME;
                                hash_2 <= (hash_2 ^ latched_sublist_2_2) * FNV_PRIME;
                                hash_3 <= (hash_3 ^ latched_sublist_3_2) * FNV_PRIME;
                            end
                            4'd3: begin
                                hash_0 <= (hash_0 ^ latched_sublist_0_3) * FNV_PRIME;
                                hash_1 <= (hash_1 ^ latched_sublist_1_3) * FNV_PRIME;
                                hash_2 <= (hash_2 ^ latched_sublist_2_3) * FNV_PRIME;
                                hash_3 <= (hash_3 ^ latched_sublist_3_3) * FNV_PRIME;
                            end
                        endcase
                        hash_index <= hash_index + 4'd1;
                    end else begin
                        // Hash computation complete
                        hash_index <= 4'd0;
                        current_sublist <= 4'd0;
                        compare_index <= 4'd0;
                        unique_count <= 4'd0;
                        next_state <= COMPARE;
                    end
                end
                
                COMPARE: begin
                    // Compare current sublist hash with previous unique hashes
                    if (current_sublist < 4'd4) begin
                        found_match <= 4'd0;
                        compare_index <= 4'd0;
                        
                        if (compare_index < unique_count) begin
                            case (current_sublist)
                                4'd0: begin
                                    if (hash_0 == result_hash[compare_index]) begin
                                        found_match <= 4'd1;
                                        result_count[compare_index] <= result_count[compare_index] + 8'd1;
                                    end
                                end
                                4'd1: begin
                                    if (hash_1 == result_hash[compare_index]) begin
                                        found_match <= 4'd1;
                                        result_count[compare_index] <= result_count[compare_index] + 8'd1;
                                    end
                                end
                                4'd2: begin
                                    if (hash_2 == result_hash[compare_index]) begin
                                        found_match <= 4'd1;
                                        result_count[compare_index] <= result_count[compare_index] + 8'd1;
                                    end
                                end
                                4'd3: begin
                                    if (hash_3 == result_hash[compare_index]) begin
                                        found_match <= 4'd1;
                                        result_count[compare_index] <= result_count[compare_index] + 8'd1;
                                    end
                                end
                            endcase
                            compare_index <= compare_index + 4'd1;
                        end else begin
                            // Comparison complete for this sublist
                            if (!found_match) begin
                                // New unique hash found
                                result_hash[unique_count] <= case (current_sublist)
                                    4'd0: hash_0;
                                    4'd1: hash_1;
                                    4'd2: hash_2;
                                    4'd3: hash_3;
                                    default: 32'd0;
                                endcase;
                                result_count[unique_count] <= 8'd1;
                                unique_count <= unique_count + 4'd1;
                            end
                            current_sublist <= current_sublist + 4'd1;
                        end
                    end else begin
                        // All sublists processed
                        next_state <= OUTPUT;
                    end
                end
                
                OUTPUT: begin
                    // Set valid flags for output slots
                    result_valid <= {4{1'b0}};
                    if (unique_count > 4'd0) begin
                        result_valid[0] <= 1'b1;
                        if (unique_count > 4'd1) begin
                            result_valid[1] <= 1'b1;
                            if (unique_count > 4'd2) begin
                                result_valid[2] <= 1'b1;
                                if (unique_count > 4'd3) begin
                                    result_valid[3] <= 1'b1;
                                end
                            end
                        end
                    end
                    next_state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
            
            // Cycle counter for timeout
            if (cycle_count < MAX_CYCLES) begin
                cycle_count <= cycle_count + 8'd1;
            end else begin
                cycle_count <= 8'd0;
                next_state <= IDLE;
            end
        end
    end
endmodule