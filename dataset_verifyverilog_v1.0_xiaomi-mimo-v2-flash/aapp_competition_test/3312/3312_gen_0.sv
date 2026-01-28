module Johnny5MaxPoints(
    input clk,
    input rst_n,
    input start,
    input [3:0] grid_size,
    input [3:0] start_energy,
    input [3:0] start_x,
    input [3:0] start_y,
    input [3:0] can_count,
    input [3:0] can_x_in,
    input [3:0] can_y_in,
    input [4:0] can_time_in,
    input can_write,
    output reg [7:0] result,
    output reg done,
    output reg busy
);

    // Constants
    localparam [4:0] MAX_TIME = 5'd32;
    localparam [3:0] MAX_ENERGY = 4'd8;
    localparam [4:0] MAX_CANS = 5'd8;
    localparam [5:0] MAX_CYCLES = 6'd50;

    // State declarations for main FSM
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LOAD_CANS = 4'd1;
    localparam [3:0] SORT_CANS = 4'd2;
    localparam [3:0] INIT_DP = 4'd3;
    localparam [3:0] PROPAGATE = 4'd4;
    localparam [3:0] APPLY_CAN = 4'd5;
    localparam [3:0] FIND_MAX = 4'd6;
    localparam [3:0] FINISH = 4'd7;

    // Registers
    reg [3:0] state;
    reg [3:0] n_reg, e_reg, sx_reg, sy_reg, c_reg;
    reg [4:0] max_t_reg;

    // Can storage (buffer)
    reg [3:0] can_x_buf [0:7];
    reg [3:0] can_y_buf [0:7];
    reg [4:0] can_t_buf [0:7];
    reg [2:0] can_load_idx;
    reg [2:0] can_sort_idx;
    reg [2:0] can_proc_idx;
    reg [2:0] can_proc_count;

    // DP Memory: Address = {time[4:0], x[3:0], y[3:0], energy[3:0]}
    // 32*16*16*9 = 73,728 entries. Too large for registers.
    // We must store per time step and iterate.
    // We will store dp for current time t and next time t+1.
    // But grid is 16x16x9 = 2304 entries per time.
    // For hardware constraint, we assume a deep memory or use block RAM.
    // Here we will simulate a DP update in place or using a buffer.
    // Since N is small (<=16), we can use a flattened array for two time steps.
    // Size: 16 * 16 * 9 = 2304 entries. 2304 * 8 bits = 18k bits.
    // If too large, we process time steps one by one.
    // Let's define the address bus.
    wire [11:0] dp_addr; // 4 bits time, 4 bits x, 4 bits y (12 bits)
    // However, energy is also a dimension. 16*16*9 = 2304.
    // We need 12 bits for position (x,y) and 4 bits for energy.
    // Total 12 + 4 = 16 bits address. 65k bits. Maybe use Block RAM.
    // We will treat dp as a RAM accessed via signals.
    
    // Since Verilog requires explicit memory, we declare it as reg.
    // To fit in typical simulation, we might need to be smart.
    // But requirements say use DP array. Let's declare a large memory.
    // However, 2D memory [time][state] is best.
    // We will iterate time. So we need current and next state.
    // Current state: dp_current[x][y][e]
    // Next state: dp_next[x][y][e]
    // Size: 16 * 16 * 9 = 2304 entries per array.
    // Two arrays = 4608 entries. Each 8 bits.
    reg [7:0] dp_current [0:15][0:15][0:8];
    reg [7:0] dp_next [0:15][0:15][0:8];

    // Helper regs for loops
    reg [3:0] loop_x, loop_y, loop_e;
    reg [4:0] loop_t;
    reg [2:0] loop_dir;
    reg [7:0] cycle_count;

    // Temporary calculation regs
    reg [7:0] best_score;
    reg [3:0] new_x, new_y, new_e;
    reg [7:0] temp_score;

    // Index variable for loop (must be integer for loop synthesis in some tools, but [3:0] is safer for Icarus)
    integer i, j, k;

    // Bubble sort helpers
    reg swapped;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset logic
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            busy <= 1'b0;
            can_load_idx <= 3'd0;
            can_proc_count <= 3'd0;
            // Initialize DP arrays to 0 (or a valid init value)
            // We use 0 as base score. Unreachable states keep 0 or -1 (255).
            // Let's use 0 as base. Unreachable will stay 0.
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    for (k = 0; k <= 8; k = k + 1) begin
                        dp_current[i][j][k] <= 8'd0;
                        dp_next[i][j][k] <= 8'd0;
                    end
                end
            end
            // Initialize can buffer to 0
            for (i = 0; i < 8; i = i + 1) begin
                can_x_buf[i] <= 4'd0;
                can_y_buf[i] <= 4'd0;
                can_t_buf[i] <= 5'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                    if (start) begin
                        // Load static parameters
                        n_reg <= grid_size;
                        e_reg <= start_energy;
                        sx_reg <= start_x;
                        sy_reg <= start_y;
                        c_reg <= can_count;
                        can_load_idx <= 3'd0;
                        can_proc_idx <= 3'd0;
                        can_sort_idx <= 3'd0;
                        swapped <= 1'b0;
                        
                        // Handle edge case: C=0
                        if (can_count == 4'd0) begin
                            state <= INIT_DP;
                            busy <= 1'b1;
                        end else begin
                            state <= LOAD_CANS;
                            busy <= 1'b1;
                        end
                    end
                end

                LOAD_CANS: begin
                    if (can_write && can_load_idx < c_reg && can_load_idx < 3'd8) begin
                        can_x_buf[can_load_idx] <= can_x_in;
                        can_y_buf[can_y_idx] <= can_y_in;
                        can_t_buf[can_load_idx] <= can_time_in;
                        can_load_idx <= can_load_idx + 3'd1;
                    end
                    if (can_load_idx >= c_reg || can_load_idx >= 3'd8) begin
                        state <= SORT_CANS;
                    end
                end

                SORT_CANS: begin
                    // Bubble sort one pass per cycle
                    if (can_sort_idx < c_reg - 1'd1) begin
                        if (can_t_buf[can_sort_idx] > can_t_buf[can_sort_idx + 1'd1]) begin
                            // Swap
                            can_t_buf[can_sort_idx] <= can_t_buf[can_sort_idx + 1'd1];
                            can_t_buf[can_sort_idx + 1'd1] <= can_t_buf[can_sort_idx];
                            can_x_buf[can_sort_idx] <= can_x_buf[can_sort_idx + 1'd1];
                            can_x_buf[can_sort_idx + 1'd1] <= can_x_buf[can_sort_idx];
                            can_y_buf[can_sort_idx] <= can_y_buf[can_sort_idx + 1'd1];
                            can_y_buf[can_sort_idx + 1'd1] <= can_y_buf[can_sort_idx];
                            swapped <= 1'b1;
                        end
                        can_sort_idx <= can_sort_idx + 3'd1;
                    end else begin
                        if (swapped) begin
                            can_sort_idx <= 3'd0;
                            swapped <= 1'b0;
                        end else begin
                            state <= INIT_DP;
                        end
                    end
                end

                INIT_DP: begin
                    // Reset DP arrays
                    // We only set start position and energy
                    // All others remain 0 (unreachable or no points)
                    
                    // First, clear the previous state (if not first run)
                    // Since we reuse dp_current, we need to clear it.
                    // But in INIT_DP we only set start. 
                    // To be safe, we can clear all, but that takes cycles.
                    // Let's assume we overwrite only reachable states.
                    // Or we use a generation counter. 
                    // For simplicity, we clear.
                    
                    if (loop_x < 16 && loop_y < 16 && loop_e <= 8) begin
                        dp_current[loop_x][loop_y][loop_e] <= 8'd0;
                        dp_next[loop_x][loop_y][loop_e] <= 8'd0;
                        
                        if (loop_x == 15 && loop_y == 15 && loop_e == 8) begin
                            loop_x <= 0; loop_y <= 0; loop_e <= 0;
                            // Set start state
                            if (e_reg <= 8) begin
                                dp_current[sx_reg][sy_reg][e_reg] <= 8'd1; // 1 because we start at time 0, and we count points. 
                                // Wait, initial score is 0. But let's say we track potential score.
                                // Actually, dp holds max score *achieved* at that state/time.
                                // So init is 0.
                                dp_current[sx_reg][sy_reg][e_reg] <= 8'd0;
                            end
                            
                            max_t_reg <= 0;
                            if (c_reg > 0) max_t_reg <= can_t_buf[c_reg - 1'd1];
                            
                            state <= PROPAGATE;
                        end else begin
                            // Increment counters
                            if (loop_e < 8) loop_e <= loop_e + 1;
                            else begin
                                loop_e <= 0;
                                if (loop_y < 15) loop_y <= loop_y + 1;
                                else begin
                                    loop_y <= 0;
                                    loop_x <= loop_x + 1;
                                end
                            end
                        end
                    end else begin
                        // First entry
                        loop_x <= 0; loop_y <= 0; loop_e <= 0;
                    end
                end

                PROPAGATE: begin
                    // Iterate through time from current to next can time
                    // We process one time step per cycle or one transition.
                    // Since N is small, we can iterate x,y,e.
                    // We need to read from dp_current and write to dp_next.
                    
                    // Logic for one time step propagation:
                    // For all x,y,e where dp_current[x][y][e] != 0 (or valid):
                    // 1. Stand still: if e > 0, dp_next[x][y][e] = max(dp_next[x][y][e], dp_current[x][y][e])
                    // 2. Move: if e > 0, neighbors. dp_next[nx][ny][e-1] = max(...)
                    
                    // We iterate through states (x,y,e).
                    // To keep it fast, we update dp_next.
                    // Then we swap dp_current and dp_next for the next time step.
                    
                    if (loop_x < n_reg) begin
                        if (loop_y < n_reg) begin
                            if (loop_e <= 8) begin
                                // Check valid state in current
                                if (dp_current[loop_x][loop_y][loop_e] != 8'd0 || 
                                   (loop_x == sx_reg && loop_y == sy_reg && loop_e == e_reg)) begin
                                    
                                    // The value
                                    reg [7:0] val;
                                    val = dp_current[loop_x][loop_y][loop_e];
                                    
                                    // 1. Stand still (if energy > 0)
                                    if (loop_e > 0) begin
                                        if (val > dp_next[loop_x][loop_y][loop_e])
                                            dp_next[loop_x][loop_y][loop_e] <= val;
                                    end
                                    
                                    // 2. Move (if energy > 0)
                                    if (loop_e > 0) begin
                                        // Up
                                        if (loop_y > 0)
                                            if (val > dp_next[loop_x][loop_y - 1][loop_e - 1])
                                                dp_next[loop_x][loop_y - 1][loop_e - 1] <= val;
                                        // Down
                                        if (loop_y < n_reg - 1)
                                            if (val > dp_next[loop_x][loop_y + 1][loop_e - 1])
                                                dp_next[loop_x][loop_y + 1][loop_e - 1] <= val;
                                        // Left
                                        if (loop_x > 0)
                                            if (val > dp_next[loop_x - 1][loop_y][loop_e - 1])
                                                dp_next[loop_x - 1][loop_y][loop_e - 1] <= val;
                                        // Right
                                        if (loop_x < n_reg - 1)
                                            if (val > dp_next[loop_x + 1][loop_y][loop_e - 1])
                                                dp_next[loop_x + 1][loop_y][loop_e - 1] <= val;
                                    end
                                end
                                
                                // Increment counters
                                if (loop_e < 8) loop_e <= loop_e + 1;
                                else begin
                                    loop_e <= 0;
                                    if (loop_y < n_reg - 1) loop_y <= loop_y + 1;
                                    else begin
                                        loop_y <= 0;
                                        if (loop_x < n_reg - 1) loop_x <= loop_x + 1;
                                        else begin
                                            // Done with this time step
                                            loop_x <= 0;
                                            loop_y <= 0;
                                            loop_e <= 0;
                                            max_t_reg <= max_t_reg + 1;
                                            
                                            // Check if we reached the time of the next can
                                            // We need to check against can_t_buf[can_proc_idx]
                                            // If max_t_reg == can_t_buf[can_proc_idx], we stop propagation and apply can
                                            
                                            if (can_proc_idx < c_reg && max_t_reg == can_t_buf[can_proc_idx]) begin
                                                state <= APPLY_CAN;
                                            end else if (max_t_reg >= 5'd31) begin // Time limit
                                                // Force finish if no more cans or time limit
                                                if (can_proc_idx >= c_reg)
                                                    state <= FIND_MAX;
                                                else
                                                    state <= FIND_MAX; // Or should wait? No, time up.
                                            end else begin
                                                // Swap current and next
                                                // We do this by iterating and copying back? 
                                                // Or just pointer swap? Since we have two arrays, we iterate.
                                                // To save logic, we can iterate and copy dp_next to dp_current, then clear dp_next.
                                                // This takes another cycle.
                                                
                                                // Optimization: swap pointers conceptually. 
                                                // But in Verilog, we must copy.
                                                // Let's copy in next cycle state.
                                                state <= 4'd10; // Copy state
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                4'd10: begin // Copy State
                    // Copy dp_next to dp_current and clear dp_next
                    // Use loop counters (already set to 0)
                    if (loop_x < n_reg) begin
                        if (loop_y < n_reg) begin
                            if (loop_e <= 8) begin
                                dp_current[loop_x][loop_y][loop_e] <= dp_next[loop_x][loop_y][loop_e];
                                dp_next[loop_x][loop_y][loop_e] <= 8'd0;
                                
                                if (loop_e < 8) loop_e <= loop_e + 1;
                                else begin
                                    loop_e <= 0;
                                    if (loop_y < n_reg - 1) loop_y <= loop_y + 1;
                                    else begin
                                        loop_y <= 0;
                                        if (loop_x < n_reg - 1) loop_x <= loop_x + 1;
                                        else begin
                                            // Done copying
                                            state <= PROPAGATE;
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                APPLY_CAN: begin
                    // Current time is can_t_buf[can_proc_idx]
                    // Apply effect of can at (CX, CY)
                    // Iterate all states in dp_current.
                    
                    if (loop_x < n_reg) begin
                        if (loop_y < n_reg) begin
                            if (loop_e <= 8) begin
                                reg [7:0] val;
                                val = dp_current[loop_x][loop_y][loop_e];
                                
                                if (val != 8'd0 || (loop_x == sx_reg && loop_y == sy_reg && loop_e == e_reg && max_t_reg == 0)) begin
                                    // Check distance to can
                                    reg [3:0] cx, cy;
                                    reg [3:0] dist;
                                    cx = can_x_buf[can_proc_idx];
                                    cy = can_y_buf[can_proc_idx];
                                    
                                    // Manhattan distance (abs diff)
                                    reg [3:0] dx, dy;
                                    if (loop_x > cx) dx = loop_x - cx; else dx = cx - loop_x;
                                    if (loop_y > cy) dy = loop_y - cy; else dy = cy - loop_y;
                                    dist = dx + dy;
                                    
                                    if (dist == 0) begin
                                        // At can: +1 point
                                        dp_current[loop_x][loop_y][loop_e] <= val + 1;
                                    end else if (dist == 1) begin
                                        // Adjacent: +1 energy
                                        new_e = (loop_e < MAX_ENERGY) ? loop_e + 1 : MAX_ENERGY;
                                        // Update in place (or to next? Apply immediately since same time)
                                        dp_current[loop_x][loop_y][loop_e] <= val; // Keep old
                                        // We need to update the same cell with new energy? 
                                        // DP state transitions usually fork.
                                        // We add the energy state to the current time step.
                                        if (val > dp_current[loop_x][loop_y][new_e])
                                            dp_current[loop_x][loop_y][new_e] <= val;
                                    end
                                end
                                
                                // Increment
                                if (loop_e < 8) loop_e <= loop_e + 1;
                                else begin
                                    loop_e <= 0;
                                    if (loop_y < n_reg - 1) loop_y <= loop_y + 1;
                                    else begin
                                        loop_y <= 0;
                                        if (loop_x < n_reg - 1) loop_x <= loop_x + 1;
                                        else begin
                                            // Done applying can
                                            can_proc_idx <= can_proc_idx + 3'd1;
                                            loop_x <= 0;
                                            
                                            // Check next can
                                            if (can_proc_idx < c_reg - 1 && can_t_buf[can_proc_idx] == can_t_buf[can_proc_idx + 1'd1]) begin
                                                // Same time next can
                                                state <= APPLY_CAN;
                                            end else begin
                                                // Continue propagation
                                                state <= PROPAGATE;
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                FIND_MAX: begin
                    // Scan dp_current for max score
                    if (loop_x < n_reg) begin
                        if (loop_y < n_reg) begin
                            if (loop_e <= 8) begin
                                reg [7:0] val;
                                val = dp_current[loop_x][loop_y][loop_e];
                                if (val > best_score) begin
                                    best_score <= val;
                                end
                                
                                if (loop_e < 8) loop_e <= loop_e + 1;
                                else begin
                                    loop_e <= 0;
                                    if (loop_y < n_reg - 1) loop_y <= loop_y + 1;
                                    else begin
                                        loop_y <= 0;
                                        if (loop_x < n_reg - 1) loop_x <= loop_x + 1;
                                        else begin
                                            state <= FINISH;
                                        end
                                    end
                                end
                            end
                        end
                    end else begin
                        // Init scan
                        loop_x <= 0; loop_y <= 0; loop_e <= 0;
                        best_score <= 8'd0;
                    end
                end

                FINISH: begin
                    result <= best_score;
                    done <= 1'b1;
                    busy <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule