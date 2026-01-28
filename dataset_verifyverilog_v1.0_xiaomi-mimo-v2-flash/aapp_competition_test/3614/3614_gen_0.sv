module LongestIncreasingPath (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] grid [0:7][0:7],
    input wire [2:0] start_r,
    input wire [2:0] start_c,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT      = 3'd1;
    localparam [2:0] SORT_PREP = 3'd2;
    localparam [2:0] SORT_LOOP = 3'd3;
    localparam [2:0] DP_PROCESS = 3'd4;
    localparam [2:0] FINISH    = 3'd5;

    reg [2:0] state;
    reg [6:0] cycle_count;      // 0-127 cycles
    localparam [6:0] MAX_CYCLES = 7'd100;

    // DP array: 8x8 of 4-bit values (max path 16)
    reg [3:0] dp [0:7][0:7];
    
    // Sorted order tracking
    reg [5:0] sort_index [0:63];      // 64 entries, 6-bit each (0-63)
    reg [5:0] sorted_count;
    reg [5:0] current_idx;
    
    // Processing state
    reg [2:0] proc_r;
    reg [2:0] proc_c;
    reg [3:0] max_path;
    
    // Jump iteration
    reg [2:0] jump_type;  // 0=row, 1=col
    reg [2:0] delta_r;
    reg [2:0] delta_c;
    reg [3:0] jump_idx;   // 0-13 possible jumps
    
    // Temporary values
    reg [2:0] new_r;
    reg [2:0] new_c;
    reg [3:0] candidate;

    // Integer for loops
    integer i, j, k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'd0;
            cycle_count <= 7'd0;
            sorted_count <= 6'd0;
            current_idx <= 6'd0;
            proc_r <= 3'd0;
            proc_c <= 3'd0;
            max_path <= 4'd0;
            jump_type <= 3'd0;
            delta_r <= 3'd0;
            delta_c <= 3'd0;
            jump_idx <= 4'd0;
            new_r <= 3'd0;
            new_c <= 3'd0;
            candidate <= 4'd0;
            // Initialize dp array
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    dp[i][j] <= 4'd0;
                end
            end
            // Initialize sort_index
            for (k = 0; k < 64; k = k + 1) begin
                sort_index[k] <= 6'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 7'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Initialize all dp values to 1
                    if (proc_c == 3'd7) begin
                        proc_c <= 3'd0;
                        proc_r <= proc_r + 3'd1;
                    end else begin
                        proc_c <= proc_c + 3'd1;
                    end
                    
                    dp[proc_r][proc_c] <= 4'd1;
                    
                    if (proc_r == 3'd7 && proc_c == 3'd7) begin
                        proc_r <= 3'd0;
                        proc_c <= 3'd0;
                        state <= SORT_PREP;
                    end
                end

                SORT_PREP: begin
                    // Build sorted index array (simple bubble-like approach)
                    // Find max among remaining cells
                    reg [5:0] max_idx;
                    reg [7:0] max_val;
                    reg [5:0] search_idx;
                    
                    max_val = 8'd0;
                    max_idx = 6'd0;
                    
                    // Find next highest value
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            search_idx = i * 8 + j;
                            // Check if not already used
                            reg found;
                            found = 1'b0;
                            for (k = 0; k < sorted_count; k = k + 1) begin
                                if (sort_index[k] == search_idx) begin
                                    found = 1'b1;
                                end
                            end
                            if (!found && grid[i][j] >= max_val) begin
                                max_val = grid[i][j];
                                max_idx = search_idx;
                            end
                        end
                    end
                    
                    sort_index[sorted_count] <= max_idx;
                    sorted_count <= sorted_count + 6'd1;
                    
                    if (sorted_count == 6'd63) begin
                        sorted_count <= 6'd0;
                        state <= DP_PROCESS;
                    end
                end

                DP_PROCESS: begin
                    cycle_count <= cycle_count + 7'd1;
                    
                    // Process current sorted cell
                    current_idx <= current_idx + 6'd1;
                    proc_r <= sort_index[current_idx][5:3];
                    proc_c <= sort_index[current_idx][2:0];
                    max_path <= 4'd0;
                    jump_idx <= 4'd0;
                    jump_type <= 3'd0;
                    
                    // If processed all cells, finish
                    if (current_idx >= 6'd64) begin
                        current_idx <= 6'd0;
                        // Output result
                        result <= {4'd0, dp[start_r][start_c]};
                        state <= FINISH;
                    end else begin
                        // Start checking jumps (process in next cycle)
                        // We'll check row jumps first, then column jumps
                    end
                end
                
                // Additional state to handle jump checking
                default: begin
                    // Process jump checking
                    if (current_idx <= 6'd64) begin
                        if (jump_type == 3'd0) begin
                            // Row jumps: delta_r = ±1, delta_c = ±2 to ±7
                            case (jump_idx)
                                4'd0: begin delta_r <= 3'd1; delta_c <= 3'd2; end
                                4'd1: begin delta_r <= 3'd1; delta_c <= 3'd3; end
                                4'd2: begin delta_r <= 3'd1; delta_c <= 3'd4; end
                                4'd3: begin delta_r <= 3'd1; delta_c <= 3'd5; end
                                4'd4: begin delta_r <= 3'd1; delta_c <= 3'd6; end
                                4'd5: begin delta_r <= 3'd1; delta_c <= 3'd7; end
                                4'd6: begin delta_r <= 3'd7; delta_c <= 3'd2; end  // -1 in signed
                                4'd7: begin delta_r <= 3'd7; delta_c <= 3'd3; end
                                4'd8: begin delta_r <= 3'd7; delta_c <= 3'd4; end
                                4'd9: begin delta_r <= 3'd7; delta_c <= 3'd5; end
                                4'd10: begin delta_r <= 3'd7; delta_c <= 3'd6; end
                                4'd11: begin delta_r <= 3'd7; delta_c <= 3'd7; end
                                default: jump_type <= 3'd1;
                            endcase
                            
                            // Calculate new position
                            if (jump_idx < 4'd12) begin
                                if (delta_r == 3'd1)
                                    new_r <= proc_r + 3'd1;
                                else
                                    new_r <= proc_r - 3'd1;
                                
                                if (delta_c < 3'd8)
                                    new_c <= proc_c + delta_c;
                                else
                                    new_c <= proc_c - delta_c;
                                
                                // Check bounds and update
                                if (new_r < 8 && new_c < 8) begin
                                    if (grid[new_r][new_c] > grid[proc_r][proc_c]) begin
                                        if (dp[new_r][new_c] + 4'd1 > max_path) begin
                                            max_path <= dp[new_r][new_c] + 4'd1;
                                        end
                                    end
                                end
                                jump_idx <= jump_idx + 4'd1;
                            end
                        end else begin
                            // Column jumps: delta_c = ±1, delta_r = ±2 to ±7
                            case (jump_idx)
                                4'd0: begin delta_c <= 3'd1; delta_r <= 3'd2; end
                                4'd1: begin delta_c <= 3'd1; delta_r <= 3'd3; end
                                4'd2: begin delta_c <= 3'd1; delta_r <= 3'd4; end
                                4'd3: begin delta_c <= 3'd1; delta_r <= 3'd5; end
                                4'd4: begin delta_c <= 3'd1; delta_r <= 3'd6; end
                                4'd5: begin delta_c <= 3'd1; delta_r <= 3'd7; end
                                4'd6: begin delta_c <= 3'd7; delta_r <= 3'd2; end  // -1
                                4'd7: begin delta_c <= 3'd7; delta_r <= 3'd3; end
                                4'd8: begin delta_c <= 3'd7; delta_r <= 3'd4; end
                                4'd9: begin delta_c <= 3'd7; delta_r <= 3'd5; end
                                4'd10: begin delta_c <= 3'd7; delta_r <= 3'd6; end
                                4'd11: begin delta_c <= 3'd7; delta_r <= 3'd7; end
                                default: begin
                                    // Update dp value
                                    if (max_path > 4'd0) begin
                                        dp[proc_r][proc_c] <= max_path;
                                    end
                                    state <= DP_PROCESS;
                                end
                            endcase
                            
                            if (jump_idx < 4'd12) begin
                                if (delta_c == 3'd1)
                                    new_c <= proc_c + 3'd1;
                                else
                                    new_c <= proc_c - 3'd1;
                                
                                if (delta_r < 3'd8)
                                    new_r <= proc_r + delta_r;
                                else
                                    new_r <= proc_r - delta_r;
                                
                                // Check bounds and update
                                if (new_r < 8 && new_c < 8) begin
                                    if (grid[new_r][new_c] > grid[proc_r][proc_c]) begin
                                        if (dp[new_r][new_c] + 4'd1 > max_path) begin
                                            max_path <= dp[new_r][new_c] + 4'd1;
                                        end
                                    end
                                end
                                jump_idx <= jump_idx + 4'd1;
                            end
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
            endcase
            
            // Timeout
            if (cycle_count >= MAX_CYCLES && state != IDLE && state != FINISH) begin
                state <= FINISH;
            end
        end
    end
endmodule