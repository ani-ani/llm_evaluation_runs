module OptimalCaching(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] cache_size,
    input wire [4:0] num_objects,
    input wire [4:0] num_accesses,
    input wire [4:0] access_seq [0:15],
    output reg [4:0] result,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FIND_NEXT_USE = 3'd3;
    localparam [2:0] UPDATE_CACHE = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;
    
    reg [2:0] state, next_state;
    reg [4:0] miss_count;
    reg [4:0] access_idx;
    reg [3:0] cache_idx;
    reg [3:0] cache_full_idx;
    reg [3:0] eviction_idx;
    reg [4:0] current_object;
    reg [4:0] next_use_pos;
    reg [4:0] farthest_next_use;
    reg [3:0] i;
    reg [3:0] j;
    reg [3:0] k;
    reg [3:0] l;
    reg [3:0] m;
    
    // Cache array (4 entries, each 5 bits)
    reg [4:0] cache [0:3];
    
    // Valid array for cache entries
    reg cache_valid [0:3];
    
    // Next use tracking
    reg [4:0] next_use_table [0:15];
    reg [4:0] search_limit;
    reg [4:0] check_idx;
    reg cache_hit;
    reg eviction_found;
    
    integer temp_idx;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            miss_count <= 5'd0;
            access_idx <= 5'd0;
            cache_idx <= 4'd0;
            cache_full_idx <= 4'd0;
            eviction_idx <= 4'd0;
            current_object <= 5'd0;
            next_use_pos <= 5'd0;
            farthest_next_use <= 5'd0;
            for (i = 0; i < 4; i = i + 1) begin
                cache[i] <= 5'd0;
                cache_valid[i] <= 1'b0;
            end
            for (j = 0; j < 16; j = j + 1) begin
                next_use_table[j] <= 5'd0;
            end
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            l <= 4'd0;
            m <= 4'd0;
            search_limit <= 5'd0;
            check_idx <= 5'd0;
            cache_hit <= 1'b0;
            eviction_found <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                    end
                end
                
                LOAD: begin
                    // Initialize for computation
                    miss_count <= 5'd0;
                    access_idx <= 5'd0;
                    cache_full_idx <= 4'd0;
                    for (i = 0; i < 4; i = i + 1) begin
                        cache_valid[i] <= 1'b0;
                    end
                    state <= COMPUTE;
                end
                
                COMPUTE: begin
                    if (access_idx < num_accesses) begin
                        current_object <= access_seq[access_idx];
                        cache_hit <= 1'b0;
                        l <= 4'd0;
                        state <= FIND_NEXT_USE;
                    end else begin
                        state <= DONE_STATE;
                    end
                end
                
                FIND_NEXT_USE: begin
                    if (l < 4'd4) begin
                        if (cache_valid[l] && cache[l] == current_object) begin
                            cache_hit <= 1'b1;
                        end
                        l <= l + 4'd1;
                    end else begin
                        if (!cache_hit) begin
                            miss_count <= miss_count + 5'd1;
                            cache_full_idx <= 4'd0;
                            state <= UPDATE_CACHE;
                        end else begin
                            access_idx <= access_idx + 5'd1;
                            state <= COMPUTE;
                        end
                    end
                end
                
                UPDATE_CACHE: begin
                    // Check if cache has empty slot
                    if (cache_full_idx < 4'd4 && cache_full_idx < cache_size) begin
                        if (!cache_valid[cache_full_idx]) begin
                            cache[cache_full_idx] <= current_object;
                            cache_valid[cache_full_idx] <= 1'b1;
                            access_idx <= access_idx + 5'd1;
                            state <= COMPUTE;
                        end else begin
                            cache_full_idx <= cache_full_idx + 4'd1;
                        end
                    end else begin
                        // All slots full, find eviction
                        farthest_next_use <= 5'd31;
                        eviction_idx <= 4'd0;
                        cache_full_idx <= 4'd0;
                        state <= UPDATE_CACHE;
                    end
                end
                
                DONE_STATE: begin
                    result <= miss_count;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule