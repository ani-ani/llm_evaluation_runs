module CountPermutations (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] len,
    input wire [3:0] t_idx,
    input wire [4:0] t_val,
    input wire t_valid,
    output reg [31:0] result,
    output reg done,
    output reg ready
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [3:0] MAX_N = 4'd16;
    
    // FSM States
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LOAD    = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] COMPUTE = 3'd3;
    localparam [2:0] DONE    = 3'd4;
    
    reg [2:0] state, next_state;
    
    // Storage for permutation t (1-indexed, indices 0-15)
    reg [4:0] t_mem [0:15];
    
    // Visited array for cycle detection
    reg [15:0] visited;
    
    // Counter for loading
    reg [3:0] load_idx;
    
    // Cycle detection variables
    reg [3:0] curr_idx;
    reg [3:0] cycle_len;
    reg [3:0] temp_idx;
    reg [3:0] even_cycle_count;
    
    // Power calculation variables
    reg [3:0] power_counter;
    reg [31:0] power_result;
    
    // Control signals
    reg start_processing;
    reg computation_done;
    
    integer i;
    
    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            ready <= 1'b1;
            done <= 1'b0;
            result <= 32'd0;
            load_idx <= 4'd0;
            curr_idx <= 4'd0;
            cycle_len <= 4'd0;
            even_cycle_count <= 4'd0;
            power_counter <= 4'd0;
            power_result <= 32'd1;
            visited <= 16'd0;
            start_processing <= 1'b0;
            computation_done <= 1'b0;
            for (i = 0; i < 16; i = i + 1) begin
                t_mem[i] <= 5'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    ready <= 1'b1;
                    done <= 1'b0;
                    start_processing <= 1'b0;
                    if (start) begin
                        ready <= 1'b0;
                        load_idx <= 4'd0;
                        visited <= 16'd0;
                        even_cycle_count <= 4'd0;
                        for (i = 0; i < 16; i = i + 1) begin
                            t_mem[i] <= 5'd0;
                        end
                    end
                end
                
                LOAD: begin
                    if (t_valid && load_idx < len) begin
                        t_mem[t_idx] <= t_val;
                        load_idx <= load_idx + 4'd1;
                    end
                end
                
                PROCESS: begin
                    if (!visited[curr_idx] && curr_idx < len) begin
                        // Start new cycle
                        temp_idx <= curr_idx;
                        cycle_len <= 4'd1;
                        visited[curr_idx] <= 1'b1;
                    end else if (visited[curr_idx] && curr_idx < len) begin
                        // Cycle complete
                        if (cycle_len[0] == 1'b0) begin // Even length
                            even_cycle_count <= even_cycle_count + 4'd1;
                        end
                        curr_idx <= curr_idx + 4'd1;
                    end else if (curr_idx >= len) begin
                        // All cycles processed
                    end else begin
                        // Continue traversing current cycle
                        temp_idx <= t_mem[temp_idx] - 5'd1; // Convert 1-indexed to 0-indexed
                        cycle_len <= cycle_len + 4'd1;
                        visited[t_mem[temp_idx] - 5'd1] <= 1'b1;
                    end
                end
                
                COMPUTE: begin
                    if (power_counter < even_cycle_count) begin
                        // Multiply result by 2
                        if (power_result[31]) begin
                            // Handle overflow for mod
                            power_result <= (power_result << 1) % MOD;
                        end else begin
                            power_result <= (power_result << 1);
                        end
                        power_counter <= power_counter + 4'd1;
                    end
                end
                
                DONE: begin
                    result <= power_result % MOD;
                    done <= 1'b1;
                    ready <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end else begin
                    next_state = IDLE;
                end
            end
            
            LOAD: begin
                if (load_idx >= len) begin
                    next_state = PROCESS;
                end else begin
                    next_state = LOAD;
                end
            end
            
            PROCESS: begin
                if (curr_idx >= len) begin
                    // Check if we just finished a cycle or processed all
                    next_state = COMPUTE;
                end else if (visited[curr_idx] && cycle_len > 4'd0) begin
                    // Just finished a cycle, continue with same index (it will skip)
                    next_state = PROCESS;
                end else if (!visited[curr_idx]) begin
                    // In middle of cycle traversal
                    next_state = PROCESS;
                end else begin
                    // Start new cycle
                    next_state = PROCESS;
                end
            end
            
            COMPUTE: begin
                if (power_counter >= even_cycle_count) begin
                    next_state = DONE;
                end else begin
                    next_state = COMPUTE;
                end
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Edge case: If no cycles found (len=0), jump to done
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            if (state == PROCESS && curr_idx >= len && cycle_len == 4'd0 && !computation_done) begin
                // Special case: len=0
                computation_done <= 1'b1;
            end
            if (state == IDLE && start) begin
                computation_done <= 1'b0;
                power_result <= 32'd1;
                power_counter <= 4'd0;
            end
        end
    end

endmodule