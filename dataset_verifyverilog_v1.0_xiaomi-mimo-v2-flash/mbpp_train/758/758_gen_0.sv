module SublistProcessor(
    input clk,
    input rst_n,
    input start,
    input [7:0] sublists[0:3][0:3],
    output reg [3:0] result_valid,
    output reg [31:0] result_hash[0:3],
    output reg [7:0] result_count[0:3],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] LATCH    = 3'd1;
    localparam [2:0] HASH     = 3'd2;
    localparam [2:0] COMPARE  = 3'd3;
    localparam [2:0] OUTPUT   = 3'd4;
    localparam [2:0] FINISH   = 3'd5;
    
    // Constants
    localparam [31:0] FNV_PRIME = 32'h01000193;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    reg [3:0] sublist_idx;
    reg [1:0] byte_idx;
    reg [31:0] temp_hash;
    reg [31:0] stored_hashes[0:3];
    reg [7:0] stored_counts[0:3];
    reg [2:0] unique_count;
    reg [1:0] output_idx;
    reg [3:0] valid_mask;
    
    // Combinational signals for hashing
    reg [31:0] hash_update;
    
    // Loop counter
    integer i;

    // State machine sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_valid <= 4'd0;
            for (i = 0; i < 4; i = i + 1) begin
                result_hash[i] <= 32'd0;
                result_count[i] <= 8'd0;
            end
            done <= 1'b0;
            cycle_count <= 8'd0;
            sublist_idx <= 4'd0;
            byte_idx <= 2'd0;
            temp_hash <= 32'd0;
            for (i = 0; i < 4; i = i + 1) begin
                stored_hashes[i] <= 32'd0;
                stored_counts[i] <= 8'd0;
            end
            unique_count <= 3'd0;
            output_idx <= 2'd0;
            valid_mask <= 4'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result_valid <= 4'd0;
                    cycle_count <= 8'd0;
                    sublist_idx <= 4'd0;
                    byte_idx <= 2'd0;
                    temp_hash <= 32'd0;
                    unique_count <= 3'd0;
                    output_idx <= 2'd0;
                    valid_mask <= 4'd0;
                    for (i = 0; i < 4; i = i + 1) begin
                        result_hash[i] <= 32'd0;
                        result_count[i] <= 8'd0;
                        stored_hashes[i] <= 32'd0;
                        stored_counts[i] <= 8'd0;
                    end
                end
                
                LATCH: begin
                    cycle_count <= 8'd0;
                end
                
                HASH: begin
                    if (byte_idx < 2'd3) begin
                        byte_idx <= byte_idx + 2'd1;
                    end else begin
                        byte_idx <= 2'd0;
                        sublist_idx <= sublist_idx + 4'd1;
                    end
                end
                
                COMPARE: begin
                    // Update stored hashes with new unique entry
                    if (sublist_idx < 4'd4) begin
                        // Check if hash is unique
                        // This is handled in combinational logic
                    end
                end
                
                OUTPUT: begin
                    if (output_idx < unique_count) begin
                        output_idx <= output_idx + 2'd1;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Combinational next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LATCH;
                end
            end
            
            LATCH: begin
                next_state = HASH;
            end
            
            HASH: begin
                // Hash all 4 sublists (4 bytes each)
                if (sublist_idx == 4'd4 && byte_idx == 2'd0) begin
                    next_state = COMPARE;
                end else begin
                    next_state = HASH;
                end
            end
            
            COMPARE: begin
                if (sublist_idx == 4'd4) begin
                    next_state = OUTPUT;
                end else begin
                    next_state = COMPARE;
                end
            end
            
            OUTPUT: begin
                if (output_idx >= unique_count) begin
                    next_state = FINISH;
                end else begin
                    next_state = OUTPUT;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Hash update logic (combinational)
    always @(*) begin
        if (state == HASH && sublist_idx < 4'd4) begin
            // Get current byte
            hash_update = temp_hash ^ sublists[sublist_idx][byte_idx];
            hash_update = hash_update * FNV_PRIME;
        end else begin
            hash_update = temp_hash;
        end
    end

    // Hash computation sequential update
    always @(posedge clk) begin
        if (state == HASH && sublist_idx < 4'd4) begin
            temp_hash <= hash_update;
        end
    end

    // Compare and count unique hashes
    always @(posedge clk) begin
        if (state == COMPARE && sublist_idx < 4'd4) begin
            // Check if hash already exists
            reg found;
            reg [2:0] found_idx;
            found = 1'b0;
            found_idx = 3'd0;
            
            for (i = 0; i < 4; i = i + 1) begin
                if (!found && stored_counts[i] != 8'd0 && stored_hashes[i] == temp_hash) begin
                    found = 1'b1;
                    found_idx = i;
                end
            end
            
            if (found) begin
                // Increment count
                stored_counts[found_idx] <= stored_counts[found_idx] + 8'd1;
            end else begin
                // Add new entry
                stored_hashes[unique_count] <= temp_hash;
                stored_counts[unique_count] <= 8'd1;
                unique_count <= unique_count + 3'd1;
            end
            
            sublist_idx <= sublist_idx + 4'd1;
        end
    end

    // Output population
    always @(posedge clk) begin
        if (state == OUTPUT && output_idx < unique_count) begin
            result_hash[output_idx] <= stored_hashes[output_idx];
            result_count[output_idx] <= stored_counts[output_idx];
            valid_mask[output_idx] <= 1'b1;
        end
        
        if (state == OUTPUT && output_idx >= unique_count) begin
            result_valid <= valid_mask;
        end
        
        if (state == IDLE) begin
            result_valid <= 4'd0;
        end
    end

endmodule