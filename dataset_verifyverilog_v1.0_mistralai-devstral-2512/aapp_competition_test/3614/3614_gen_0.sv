module LongestIncreasingPath(
    input clk,
    input rst_n,
    input start,
    input [7:0] grid [0:7] [0:7],
    input [2:0] start_r,
    input [2:0] start_c,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    // DP array and temporary storage
    reg [3:0] dp [0:7] [0:7];
    reg [3:0] temp_dp [0:7] [0:7];

    // Control signals
    reg [2:0] state, next_state;
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1024;

    // Loop counters
    reg [5:0] i, j, k;
    reg [2:0] r, c, new_r, new_c;
    reg [7:0] current_val, next_val;
    reg [3:0] max_path;

    // Initialize all dp values to 1
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 10'd0;
            
            // Initialize dp arrays
            for (i = 0; i < 64; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    dp[i[5:3]][i[2:0]] <= 4'd1;
                    temp_dp[i[5:3]][i[2:0]] <= 4'd1;
                end
            end
            
            // Reset counters
            i <= 6'd0;
            j <= 6'd0;
            k <= 6'd0;
            r <= 3'd0;
            c <= 3'd0;
            new_r <= 3'd0;
            new_c <= 3'd0;
            current_val <= 8'd0;
            next_val <= 8'd0;
            max_path <= 4'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 10'd1;
        end
    end

    // State machine
    always @(*) begin
        next_state = state;
        done = 1'b0;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end

            INIT: begin
                // Reset cycle counter
                cycle_count = 10'd0;
                
                // Initialize dp arrays
                for (i = 0; i < 64; i = i + 1) begin
                    for (j = 0; j < 8; j = j + 1) begin
                        dp[i[5:3]][i[2:0]] = 4'd1;
                        temp_dp[i[5:3]][i[2:0]] = 4'd1;
                    end
                end
                
                // Reset counters
                i = 6'd0;
                j = 6'd0;
                k = 6'd0;
                r = 3'd0;
                c = 3'd0;
                new_r = 3'd0;
                new_c = 3'd0;
                current_val = 8'd0;
                next_val = 8'd0;
                max_path = 4'd0;
                
                next_state = PROCESS;
            end

            PROCESS: begin
                // Process cells in order
                if (i < 64) begin
                    r = i[5:3];
                    c = i[2:0];
                    current_val = grid[r][c];
                    
                    // Check all possible jumps
                    if (j < 14) begin
                        case (j)
                            // Row jumps: delta_r = ±1, delta_c = ±2 to ±7
                            6'd0: begin new_r = r + 3'd1; new_c = c + 3'd2; end
                            6'd1: begin new_r = r + 3'd1; new_c = c + 3'd3; end
                            6'd2: begin new_r = r + 3'd1; new_c = c + 3'd4; end
                            6'd3: begin new_r = r + 3'd1; new_c = c + 3'd5; end
                            6'd4: begin new_r = r + 3'd1; new_c = c + 3'd6; end
                            6'd5: begin new_r = r + 3'd1; new_c = c + 3'd7; end
                            6'd6: begin new_r = r - 3'd1; new_c = c + 3'd2; end
                            6'd7: begin new_r = r - 3'd1; new_c = c + 3'd3; end
                            6'd8: begin new_r = r - 3'd1; new_c = c + 3'd4; end
                            6'd9: begin new_r = r - 3'd1; new_c = c + 3'd5; end
                            6'd10: begin new_r = r - 3'd1; new_c = c + 3'd6; end
                            6'd11: begin new_r = r - 3'd1; new_c = c + 3'd7; end
                            // Column jumps: delta_c = ±1, delta_r = ±2 to ±7
                            6'd12: begin new_r = r + 3'd2; new_c = c + 3'd1; end
                            6'd13: begin new_r = r + 3'd3; new_c = c + 3'd1; end
                            default: begin new_r = r; new_c = c; end
                        endcase
                        
                        // Check bounds
                        if (new_r >= 3'd0 && new_r <= 3'd7 && new_c >= 3'd0 && new_c <= 3'd7) begin
                            next_val = grid[new_r][new_c];
                            
                            // Check if petal value increases
                            if (next_val > current_val) begin
                                // Update dp value
                                if (temp_dp[r][c] < dp[new_r][new_c] + 4'd1) begin
                                    temp_dp[r][c] = dp[new_r][new_c] + 4'd1;
                                end
                            end
                        end
                        
                        j = j + 6'd1;
                    end else begin
                        // Move to next cell
                        j = 6'd0;
                        i = i + 6'd1;
                    end
                end else begin
                    // Copy temp_dp back to dp
                    for (k = 0; k < 64; k = k + 1) begin
                        dp[k[5:3]][k[2:0]] = temp_dp[k[5:3]][k[2:0]];
                    end
                    
                    // Find maximum path from start position
                    max_path = dp[start_r][start_c];
                    
                    next_state = FINISH;
                end
            end

            FINISH: begin
                result = max_path;
                done = 1'b1;
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Timeout check
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b1;
        end
    end

endmodule