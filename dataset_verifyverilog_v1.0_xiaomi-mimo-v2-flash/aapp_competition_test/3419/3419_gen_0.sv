module RookieBunny (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] s1,
    input [3:0] s2,
    input [3:0] t_i,
    input load_ready,
    output reg [3:0] result,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] LOAD_INPUTS  = 3'd1;
    localparam [2:0] INIT_DP      = 3'd2;
    localparam [2:0] PROCESS      = 3'd3;
    localparam [2:0] FIND_MAX     = 3'd4;
    localparam [2:0] FINISH       = 3'd5;

    // Registers
    reg [2:0] state, next_state;
    reg [3:0] reg_n, reg_s1, reg_s2;
    reg [3:0] t_buffer [0:15]; // Storage for up to 16 customers
    reg [3:0] load_idx;
    reg [3:0] i_reg; // Customer index (0 to n-1)
    reg [3:0] r1_reg, r2_reg; // Current counters for outer loop
    reg [3:0] next_r1, next_r2; // Computed next state
    reg [3:0] max_idx;
    reg [3:0] temp_max;
    reg [3:0] cycle_count; // Timeout counter
    
    // DP Table: state[i][j] = 1 if j minutes left on Counter 1, i-j on Counter 2 (simplified)
    // Since n, s1, s2 are 4-bit (max 15), a 16x16 bit matrix is feasible (256 bits)
    // Flattened: dp[rem1][rem2] = 1 if reachable
    reg dp [0:15][0:15];
    reg dp_next [0:15][0:15];
    reg found_next;
    integer row, col;

    // --- FSM Synchronous Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            load_idx <= 4'd0;
            i_reg <= 4'd0;
            r1_reg <= 4'd0;
            r2_reg <= 4'd0;
            max_idx <= 4'd0;
            temp_max <= 4'd0;
            cycle_count <= 4'd0;
            reg_n <= 4'd0;
            reg_s1 <= 4'd0;
            reg_s2 <= 4'd0;
            // Initialize DP table to 0
            for (row = 0; row < 16; row = row + 1) begin
                for (col = 0; col < 16; col = col + 1) begin
                    dp[row][col] <= 1'b0;
                end
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 4'd0;
                    load_idx <= 4'd0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        reg_n <= n;
                        reg_s1 <= s1;
                        reg_s2 <= s2;
                    end
                end

                LOAD_INPUTS: begin
                    if (load_ready && load_idx < reg_n) begin
                        t_buffer[load_idx] <= t_i;
                        load_idx <= load_idx + 4'd1;
                    end
                end

                INIT_DP: begin
                    // Reset DP table
                    for (row = 0; row < 16; row = row + 1) begin
                        for (col = 0; col < 16; col = col + 1) begin
                            dp[row][col] <= 1'b0;
                        end
                    end
                    // Initial state: s1 minutes on Counter 1, s2 minutes on Counter 2
                    if (reg_s1 <= 4'd15 && reg_s2 <= 4'd15) begin
                        dp[reg_s1][reg_s2] <= 1'b1;
                    end
                    i_reg <= 4'd0;
                    max_idx <= 4'd0;
                end

                PROCESS: begin
                    // Update DP for customer i_reg (t = t_buffer[i_reg])
                    // Use temp_max to track if this index is reachable
                    // Note: In hardware, we calculate next state in combinational logic
                    // Here we are strictly sequential for simplicity/safety.
                    
                    if (i_reg < reg_n) begin
                        // Transition logic is handled by combinational block below
                        // Update dp registers
                        for (row = 0; row < 16; row = row + 1) begin
                            for (col = 0; col < 16; col = col + 1) begin
                                dp[row][col] <= dp_next[row][col];
                            end
                        end
                        // If any state was reachable in this cycle, update max_idx
                        if (found_next) begin
                            max_idx <= i_reg + 4'd1;
                        end
                        i_reg <= i_reg + 4'd1;
                    end
                    // Timeout safeguard
                    cycle_count <= cycle_count + 4'd1;
                end

                FIND_MAX: begin
                    // Result is already max_idx (number of customers processed)
                    result <= max_idx;
                end

                FINISH: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // --- Combinational Logic (Next State & DP Update) ---
    always @(*) begin
        next_state = state;
        found_next = 1'b0;
        
        // Default DP next state (keep current if not processed)
        for (row = 0; row < 16; row = row + 1) begin
            for (col = 0; col < 16; col = col + 1) begin
                dp_next[row][col] = dp[row][col];
            end
        end

        case (state)
            IDLE: begin
                if (start) next_state = LOAD_INPUTS;
            end

            LOAD_INPUTS: begin
                if (load_idx >= reg_n) next_state = INIT_DP;
            end

            INIT_DP: begin
                next_state = PROCESS;
            end

            PROCESS: begin
                if (i_reg >= reg_n || cycle_count >= 4'd15) begin
                    next_state = FIND_MAX;
                end else begin
                    // Compute next DP states for t = t_buffer[i_reg]
                    // t_buffer[i_reg] is the current customer's time requirement
                    // We check all current valid states (r1, r2)
                    
                    // Reset next DP table (start fresh each cycle)
                    for (row = 0; row < 16; row = row + 1) begin
                        for (col = 0; col < 16; col = col + 1) begin
                            dp_next[row][col] = 1'b0;
                        end
                    end

                    for (r1_reg = 0; r1_reg <= 15; r1_reg = r1_reg + 1) begin
                        for (r2_reg = 0; r2_reg <= 15; r2_reg = r2_reg + 1) begin
                            if (dp[r1_reg][r2_reg]) begin
                                // Check Counter 1
                                if (t_buffer[i_reg] <= r1_reg) begin
                                    dp_next[r1_reg - t_buffer[i_reg]][r2_reg] = 1'b1;
                                    found_next = 1'b1;
                                end
                                // Check Counter 2
                                if (t_buffer[i_reg] <= r2_reg) begin
                                    dp_next[r1_reg][r2_reg - t_buffer[i_reg]] = 1'b1;
                                    found_next = 1'b1;
                                end
                            end
                        end
                    end
                    // If no states reachable, we stop (though logic continues due to cycle_count)
                end
            end

            FIND_MAX: begin
                next_state = FINISH;
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule