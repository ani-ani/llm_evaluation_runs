module StealthNavigation (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] start_r,
    input wire [3:0] start_c,
    input wire [3:0] target_r,
    input wire [3:0] target_c,
    input wire [255:0] grid_flat,
    input wire [3:0] num_masters,
    input wire [63:0] path_data_0,
    input wire [63:0] path_data_1,
    input wire [63:0] path_data_2,
    input wire [63:0] path_data_3,
    output reg [9:0] result,
    output reg done
);

    // Grid dimensions
    localparam [3:0] GRID_SIZE = 4'd15;
    localparam [6:0] MAX_STATES = 7'd100; // Limit for visited array
    localparam [9:0] MAX_CYCLES = 10'd1024;
    localparam [5:0] MAX_PATH_LENGTH = 6'd8;
    localparam [5:0] MAX_LCM = 6'd64;

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT_LUT = 4'd1;
    localparam [3:0] PRECOMP_DANGER = 4'd2;
    localparam [3:0] SEARCH = 4'd3;
    localparam [3:0] FINISHED = 4'd4;

    reg [3:0] state;
    reg [9:0] cycle_counter;

    // Registers for inputs
    reg [3:0] start_r_reg, start_c_reg;
    reg [3:0] target_r_reg, target_c_reg;
    reg [255:0] grid_flat_reg;
    reg [3:0] num_masters_reg;
    reg [63:0] path_data_reg [0:3];

    // Master Path LUT (Time x Master ID -> Position)
    // 64 times * 4 masters = 256 entries
    // Each entry: {row[3:0], col[3:0]}
    reg [7:0] master_pos_lut [0:255];
    reg [5:0] lut_time_ptr;
    reg [1:0] lut_master_ptr;
    reg [1:0] path_len [0:3];
    reg [1:0] path_len_reg [0:3];
    reg [7:0] path_points [0:3][0:7];
    integer i, j, k;

    // Danger Map: 16x16 array for current time
    reg [15:0] danger_grid [0:15]; // 1 bit per cell
    reg [5:0] danger_time_ptr;

    // BFS Queue (Dual-port RAM style)
    // Queue entry: {valid, r[3:0], c[3:0], time[5:0]}
    // Depth 64
    reg [10:0] queue_ram [0:63];
    reg [5:0] queue_head;
    reg [5:0] queue_tail;
    reg [5:0] queue_count;
    reg queue_full;

    // Visited Array: 16x16x64 bits
    // Flattened: index = {r, c, time}
    reg visited [0:16383]; // 16k bits, implied size
    wire [13:0] visited_idx;
    wire [13:0] visited_idx_next;
    reg [13:0] visited_idx_reg;
    reg visited_read_data;
    reg visited_write_enable;
    reg [13:0] visited_write_addr;
    reg visited_write_data;

    // Temporary registers for computation
    reg [3:0] curr_r, curr_c;
    reg [5:0] curr_time;
    reg [3:0] next_r, next_c;
    reg [5:0] next_time;
    reg [3:0] nr, nc;
    reg [5:0] nt;
    reg [1:0] m_id;
    reg [3:0] m_r, m_c;
    reg [3:0] cell_r, cell_c;
    reg is_safe;
    reg is_walkable;
    reg is_visited;
    reg line_of_sight_blocked;
    reg [3:0] dist;
    reg [3:0] min_r, max_r;
    reg [3:0] min_c, max_c;

    // Helper signals for read
    wire [10:0] queue_entry;
    assign queue_entry = queue_ram[queue_head];

    // Initialize visited array logic (simulated)
    // In real hardware, this would be a BRAM.
    // For simulation/synthesis, we use a loop to initialize in reset.

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 10'd0;
            done <= 1'b0;
            cycle_counter <= 10'd0;
            start_r_reg <= 4'd0;
            start_c_reg <= 4'd0;
            target_r_reg <= 4'd0;
            target_c_reg <= 4'd0;
            grid_flat_reg <= 256'd0;
            num_masters_reg <= 4'd0;
            for (i = 0; i < 4; i = i + 1) begin
                path_data_reg[i] <= 64'd0;
            end
            lut_time_ptr <= 6'd0;
            lut_master_ptr <= 2'd0;
            danger_time_ptr <= 6'd0;
            queue_head <= 6'd0;
            queue_tail <= 6'd0;
            queue_count <= 6'd0;
            queue_full <= 1'b0;
            visited_write_enable <= 1'b0;
            // Reset visited array content (loop unrolled for synthesis tool)
            for (k = 0; k < 16384; k = k + 1) begin
                visited[k] <= 1'b0;
            end
            for (i = 0; i < 16; i = i + 1) begin
                danger_grid[i] <= 16'd0;
            end
            result <= 10'h3FF; // Default impossible
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 10'h3FF;
                    cycle_counter <= 10'd0;
                    if (start) begin
                        start_r_reg <= start_r;
                        start_c_reg <= start_c;
                        target_r_reg <= target_r;
                        target_c_reg <= target_c;
                        grid_flat_reg <= grid_flat;
                        num_masters_reg <= num_masters;
                        path_data_reg[0] <= path_data_0;
                        path_data_reg[1] <= path_data_1;
                        path_data_reg[2] <= path_data_2;
                        path_data_reg[3] <= path_data_3;
                        
                        // Parse path lengths (first 2 bits of each path data)
                        path_len[0] <= path_data_0[1:0];
                        path_len[1] <= path_data_1[1:0];
                        path_len[2] <= path_data_2[1:0];
                        path_len[3] <= path_data_3[1:0];
                        path_len_reg[0] <= path_data_0[1:0];
                        path_len_reg[1] <= path_data_1[1:0];
                        path_len_reg[2] <= path_data_2[1:0];
                        path_len_reg[3] <= path_data_3[1:0];

                        // Parse points (up to 8)
                        // Point 0: bits [7:0], Point 1: [15:8], etc.
                        // We assume points are packed row/col
                        for (i = 0; i < 4; i = i + 1) begin
                            for (j = 0; j < 8; j = j + 1) begin
                                path_points[i][j] <= path_data_reg[i][(j*8)+7:(j*8)];
                            end
                        end

                        lut_time_ptr <= 6'd0;
                        lut_master_ptr <= 2'd0;
                        state <= INIT_LUT;
                    end
                end

                INIT_LUT: begin
                    // Fill master_pos_lut for MAX_LCM (64) cycles
                    // LUT index: {lut_time_ptr, lut_master_ptr} -> 8 bits
                    if (lut_time_ptr < MAX_LCM) begin
                        if (lut_master_ptr < num_masters_reg) begin
                            // Calculate position based on path
                            // Ping-pong: 0->1->2->...->len-1->len-2->...->0
                            // Path length L. Cycle T. Index I.
                            // I = T % (2*L - 2)
                            // If I >= L, I = 2*L - 2 - I
                            
                            // Since this is hardware, we calculate simply
                            // We stored path points in path_points
                            // We need to compute index for this lut_time_ptr
                            // Note: This part is complex for combinational logic without multipliers.
                            // We will do it sequentially: One master position per cycle.
                            
                            // Combinational calculation of index
                            reg [5:0] mod_idx;
                            reg [1:0] p_len;
                            p_len = path_len_reg[lut_master_ptr];
                            
                            if (p_len == 2'd0) begin
                                // Stationary at start
                                master_pos_lut[{lut_time_ptr, lut_master_ptr}] <= path_points[lut_master_ptr][0];
                            end else begin
                                reg [5:0] period;
                                period = (p_len * 2) - 2;
                                mod_idx = lut_time_ptr % period;
                                if (mod_idx < p_len) begin
                                    master_pos_lut[{lut_time_ptr, lut_master_ptr}] <= path_points[lut_master_ptr][mod_idx[2:0]];
                                end else begin
                                    master_pos_lut[{lut_time_ptr, lut_master_ptr}] <= path_points[lut_master_ptr][period - mod_idx];
                                end
                            end
                            
                            lut_master_ptr <= lut_master_ptr + 2'd1;
                        end else begin
                            lut_master_ptr <= 2'd0;
                            lut_time_ptr <= lut_time_ptr + 6'd1;
                        end
                    end else begin
                        state <= PRECOMP_DANGER;
                        danger_time_ptr <= 6'd0;
                    end
                end

                PRECOMP_DANGER: begin
                    // Generate danger map for each time step (0 to 63)
                    // For each cell, check visibility against all masters at that time
                    // Optimization: Compute one row of grid per cycle for the current time
                    
                    if (danger_time_ptr < MAX_LCM) begin
                        // Current danger row index
                        cell_r <= danger_time_ptr[3:0]; // Cycles 0-15: Row 0, 16-31: Row 1, etc? No, simpler.
                        // Actually, let's compute row by row. 16 rows per time.
                        // Cycle 0-15: Row 0-15 for Time 0.
                        // But we need to store 16x16 per time. 
                        // Let's just do one cell per cycle? 64*256 = 16384 cycles. Too slow.
                        // Let's do one row (16 cells) per cycle. 64*16 = 1024 cycles. OK.
                        
                        // danger_time_ptr 0..63: Time index
                        // danger_time_ptr[5:4]: Not used directly for row.
                        // Let's use a counter for the row within the time.
                        // Let's just compute the whole grid for `danger_time_ptr` in one cycle.
                        // 256 cells * 4 masters = 1024 checks. Might be heavy but doable in logic.
                        
                        // Let's do it row by row to save area.
                        // Use a sub-counter. We'll just assume we compute one row per cycle.
                        // Row index = danger_time_ptr % 16. Time index = danger_time_ptr / 16.
                        
                        reg [3:0] t_idx;
                        reg [3:0] r_idx;
                        r_idx = danger_time_ptr[3:0];
                        t_idx = danger_time_ptr[5:4]; // Only 0-3 fits in 4 bits? No, we need 0-63.
                        // Let's use a separate counter for Time.
                        // We need to store results. 
                        // We will skip precomputation and compute danger on the fly in SEARCH phase
                        // because 64*16 = 1024 cycles is acceptable for search setup.
                        // Wait, searching takes cycles too. 
                        // Optimization: Just compute danger map for current search time in SEARCH phase.
                    end
                    state <= SEARCH;
                end

                SEARCH: begin
                    // Check if queue is empty or timeout
                    if (queue_count == 6'd0 && cycle_counter == 10'd0) begin
                        // First cycle of search: Enqueue start
                        // Check if start is safe?
                        // We need danger map for time 0.
                        // Let's generate danger map for `curr_time` on the fly.
                        // Since BFS is sequential, we only need one danger map at a time.
                        // We can generate it in parallel with dequeuing.
                        
                        // Enqueue Start
                        if (!queue_full) begin
                            queue_ram[queue_tail] <= {1'b1, start_r_reg, start_c_reg, 6'd0};
                            queue_tail <= queue_tail + 6'd1;
                            queue_count <= queue_count + 6'd1;
                            if (queue_tail + 6'd1 == queue_head) queue_full <= 1'b1;
                            
                            // Mark visited
                            visited[{start_r_reg, start_c_reg, 6'd0}] <= 1'b1;
                            
                            cycle_counter <= cycle_counter + 10'd1;
                        end
                    end else if (queue_count > 6'd0) begin
                        // Dequeue
                        {1'b0, curr_r, curr_c, curr_time} <= queue_entry;
                        queue_head <= queue_head + 6'd1;
                        queue_count <= queue_count - 6'd1;
                        queue_full <= 1'b0;
                        
                        // Check target
                        if (curr_r == target_r_reg && curr_c == target_c_reg) begin
                            state <= FINISHED;
                            result <= cycle_counter; // Or curr_time? Requirement: Min turns T. BFS guarantees min depth.
                            // BFS level = curr_time. 
                            result <= curr_time;
                        end else begin
                            // Generate neighbors if time < max
                            if (curr_time < 10'd1023) begin
                                // Generate Danger Map for curr_time + 1
                                // This logic is combinational below, or sequential?
                                // Let's do sequential: Generate map for next_time, then enqueue.
                                // Actually, we need to check safety for `curr_time + 1`.
                                
                                // We need to check 5 moves: Stay, N, S, E, W.
                                // We will check them one by one.
                                // Use a sub-state or counter inside SEARCH.
                                // Let's use `lut_time_ptr` as neighbor counter.
                                if (lut_time_ptr == 5'd0) begin // Check Stay
                                    next_r = curr_r;
                                    next_c = curr_c;
                                    nt = curr_time + 6'd1;
                                    // Check bounds (always valid for stay)
                                    // Check walkable
                                    if (grid_flat_reg[{next_r, next_c}] && !visited[{next_r, next_c, nt}]) begin
                                        // Check Safety
                                        // We need to check if safe at time `nt`
                                        // This requires checking all masters at `nt`.
                                        // Combinational safety check block:
                                        // is_safe = 1;
                                        // for each master: check line of sight
                                        is_safe = 1'b1;
                                        for (m_id = 0; m_id < 4; m_id = m_id + 1) begin
                                            if (m_id < num_masters_reg) begin
                                                // Get master pos at time nt
                                                m_r = master_pos_lut[{nt, m_id}][7:4];
                                                m_c = master_pos_lut[{nt, m_id}][3:0];
                                                
                                                // Line of sight check
                                                if (next_r == m_r || next_c == m_c) begin
                                                    // Same row or col
                                                    // Check obstruction
                                                    line_of_sight_blocked = 1'b0;
                                                    if (next_r == m_r) begin
                                                        min_c = (next_c < m_c) ? next_c : m_c;
                                                        max_c = (next_c > m_c) ? next_c : m_c;
                                                        for (k = min_c + 4'd1; k < max_c; k = k + 1) begin
                                                            if (!grid_flat_reg[{next_r, k}]) line_of_sight_blocked = 1'b1;
                                                        end
                                                    end else begin
                                                        min_r = (next_r < m_r) ? next_r : m_r;
                                                        max_r = (next_r > m_r) ? next_r : m_r;
                                                        for (k = min_r + 4'd1; k < max_r; k = k + 1) begin
                                                            if (!grid_flat_reg[{k, next_c}]) line_of_sight_blocked = 1'b1;
                                                        end
                                                    end
                                                    if (!line_of_sight_blocked) is_safe = 1'b0;
                                                end
                                            end
                                        end
                                        
                                        if (is_safe) begin
                                            // Enqueue
                                            if (!queue_full) begin
                                                queue_ram[queue_tail] <= {1'b1, next_r, next_c, nt};
                                                queue_tail <= queue_tail + 6'd1;
                                                queue_count <= queue_count + 6'd1;
                                                if (queue_tail + 6'd1 == queue_head) queue_full <= 1'b1;
                                                visited[{next_r, next_c, nt}] <= 1'b1;
                                            end
                                        end
                                    end
                                    lut_time_ptr <= 5'd1;
                                end else if (lut_time_ptr == 5'd1) begin // Check North
                                    if (curr_r > 4'd0) begin
                                        next_r = curr_r - 4'd1;
                                        next_c = curr_c;
                                        nt = curr_time + 6'd1;
                                        if (grid_flat_reg[{next_r, next_c}] && !visited[{next_r, next_c, nt}]) begin
                                            // Safety Check (Repeated for brevity, in reality wrap in task/function or combinational block)
                                            // Inline safety check logic same as above
                                            is_safe = 1'b1;
                                            for (m_id = 0; m_id < 4; m_id = m_id + 1) begin
                                                if (m_id < num_masters_reg) begin
                                                    m_r = master_pos_lut[{nt, m_id}][7:4];
                                                    m_c = master_pos_lut[{nt, m_id}][3:0];
                                                    if (next_r == m_r || next_c == m_c) begin
                                                        line_of_sight_blocked = 1'b0;
                                                        if (next_r == m_r) begin
                                                            min_c = (next_c < m_c) ? next_c : m_c;
                                                            max_c = (next_c > m_c) ? next_c : m_c;
                                                            for (k = min_c + 4'd1; k < max_c; k = k + 1) begin
                                                                if (!grid_flat_reg[{next_r, k}]) line_of_sight_blocked = 1'b1;
                                                            end
                                                        end else begin
                                                            min_r = (next_r < m_r) ? next_r : m_r;
                                                            max_r = (next_r > m_r) ? next_r : m_r;
                                                            for (k = min_r + 4'd1; k < max_r; k = k + 1) begin
                                                                if (!grid_flat_reg[{k, next_c}]) line_of_sight_blocked = 1'b1;
                                                            end
                                                        end
                                                        if (!line_of_sight_blocked) is_safe = 1'b0;
                                                    end
                                                end
                                            end
                                            if (is_safe) begin
                                                if (!queue_full) begin
                                                    queue_ram[queue_tail] <= {1'b1, next_r, next_c, nt};
                                                    queue_tail <= queue_tail + 6'd1;
                                                    queue_count <= queue_count + 6'd1;
                                                    if (queue_tail + 6'd1 == queue_head) queue_full <= 1'b1;
                                                    visited[{next_r, next_c, nt}] <= 1'b1;
                                                end
                                            end
                                        end
                                    end
                                    lut_time_ptr <= 5'd2;
                                end else if (lut_time_ptr == 5'd2) begin // South
                                    if (curr_r < GRID_SIZE) begin
                                        next_r = curr_r + 4'd1;
                                        next_c = curr_c;
                                        nt = curr_time + 6'd1;
                                        if (grid_flat_reg[{next_r, next_c}] && !visited[{next_r, next_c, nt}]) begin
                                            // Safety Check
                                            is_safe = 1'b1;
                                            for (m_id = 0; m_id < 4; m_id = m_id + 1) begin
                                                if (m_id < num_masters_reg) begin
                                                    m_r = master_pos_lut[{nt, m_id}][7:4];
                                                    m_c = master_pos_lut[{nt, m_id}][3:0];
                                                    if (next_r == m_r || next_c == m_c) begin
                                                        line_of_sight_blocked = 1'b0;
                                                        if (next_r == m_r) begin
                                                            min_c = (next_c < m_c) ? next_c : m_c;
                                                            max_c = (next_c > m_c) ? next_c : m_c;
                                                            for (k = min_c + 4'd1; k < max_c; k = k + 1) begin
                                                                if (!grid_flat_reg[{next_r, k}]) line_of_sight_blocked = 1'b1;
                                                            end
                                                        end else begin
                                                            min_r = (next_r < m_r) ? next_r : m_r;
                                                            max_r = (next_r > m_r) ? next_r : m_r;
                                                            for (k = min_r + 4'd1; k < max_r; k = k + 1) begin
                                                                if (!grid_flat_reg[{k, next_c}]) line_of_sight_blocked = 1'b1;
                                                            end
                                                        end
                                                        if (!line_of_sight_blocked) is_safe = 1'b0;
                                                    end
                                                end
                                            end
                                            if (is_safe) begin
                                                if (!queue_full) begin
                                                    queue_ram[queue_tail] <= {1'b1, next_r, next_c, nt};
                                                    queue_tail <= queue_tail + 6'd1;
                                                    queue_count <= queue_count + 6'd1;
                                                    if (queue_tail + 6'd1 == queue_head) queue_full <= 1'b1;
                                                    visited[{next_r, next_c, nt}] <= 1'b1;
                                                end
                                            end
                                        end
                                    end
                                    lut_time_ptr <= 5'd3;
                                end else if (lut_time_ptr == 5'd3) begin // East
                                    if (curr_c < GRID_SIZE) begin
                                        next_r = curr_r;
                                        next_c = curr_c + 4'd1;
                                        nt = curr_time + 6'd1;
                                        if (grid_flat_reg[{next_r, next_c}] && !visited[{next_r, next_c, nt}]) begin
                                            // Safety Check
                                            is_safe = 1'b1;
                                            for (m_id = 0; m_id < 4; m_id = m_id + 1) begin
                                                if (m_id < num_masters_reg) begin
                                                    m_r = master_pos_lut[{nt, m_id}][7:4];
                                                    m_c = master_pos_lut[{nt, m_id}][3:0];
                                                    if (next_r == m_r || next_c == m_c) begin
                                                        line_of_sight_blocked = 1'b0;
                                                        if (next_r == m_r) begin
                                                            min_c = (next_c < m_c) ? next_c : m_c;
                                                            max_c = (next_c > m_c) ? next_c : m_c;
                                                            for (k = min_c + 4'd1; k < max_c; k = k + 1) begin
                                                                if (!grid_flat_reg[{next_r, k}]) line_of_sight_blocked = 1'b1;
                                                            end
                                                        end else begin
                                                            min_r = (next_r < m_r) ? next_r : m_r;
                                                            max_r = (next_r > m_r) ? next_r : m_r;
                                                            for (k = min_r + 4'd1; k < max_r; k = k + 1) begin
                                                                if (!grid_flat_reg[{k, next_c}]) line_of_sight_blocked = 1'b1;
                                                            end
                                                        end
                                                        if (!line_of_sight_blocked) is_safe = 1'b0;
                                                    end
                                                end
                                            end
                                            if (is_safe) begin
                                                if (!queue_full) begin
                                                    queue_ram[queue_tail] <= {1'b1, next_r, next_c, nt};
                                                    queue_tail <= queue_tail + 6'd1;
                                                    queue_count <= queue_count + 6'd1;
                                                    if (queue_tail + 6'd1 == queue_head) queue_full <= 1'b1;
                                                    visited[{next_r, next_c, nt}] <= 1'b1;
                                                end
                                            end
                                        end
                                    end
                                    lut_time_ptr <= 5'd4;
                                end else if (lut_time_ptr == 5'd4) begin // West
                                    if (curr_c > 4'd0) begin
                                        next_r = curr_r;
                                        next_c = curr_c - 4'd1;
                                        nt = curr_time + 6'd1;
                                        if (grid_flat_reg[{next_r, next_c}] && !visited[{next_r, next_c, nt}]) begin
                                            // Safety Check
                                            is_safe = 1'b1;
                                            for (m_id = 0; m_id < 4; m_id = m_id + 1) begin
                                                if (m_id < num_masters_reg) begin
                                                    m_r = master_pos_lut[{nt, m_id}][7:4];
                                                    m_c = master_pos_lut[{nt, m_id}][3:0];
                                                    if (next_r == m_r || next_c == m_c) begin
                                                        line_of_sight_blocked = 1'b0;
                                                        if (next_r == m_r) begin
                                                            min_c = (next_c < m_c) ? next_c : m_c;
                                                            max_c = (next_c > m_c) ? next_c : m_c;
                                                            for (k = min_c + 4'd1; k < max_c; k = k + 1) begin
                                                                if (!grid_flat_reg[{next_r, k}]) line_of_sight_blocked = 1'b1;
                                                            end
                                                        end else begin
                                                            min_r = (next_r < m_r) ? next_r : m_r;
                                                            max_r = (next_r > m_r) ? next_r : m_r;
                                                            for (k = min_r + 4'd1; k < max_r; k = k + 1) begin
                                                                if (!grid_flat_reg[{k, next_c}]) line_of_sight_blocked = 1'b1;
                                                            end
                                                        end
                                                        if (!line_of_sight_blocked) is_safe = 1'b0;
                                                    end
                                                end
                                            end
                                            if (is_safe) begin
                                                if (!queue_full) begin
                                                    queue_ram[queue_tail] <= {1'b1, next_r, next_c, nt};
                                                    queue_tail <= queue_tail + 6'd1;
                                                    queue_count <= queue_count + 6'd1;
                                                    if (queue_tail + 6'd1 == queue_head) queue_full <= 1'b1;
                                                    visited[{next_r, next_c, nt}] <= 1'b1;
                                                end
                                            end
                                        end
                                    end
                                    lut_time_ptr <= 5'd0;
                                    cycle_counter <= cycle_counter + 10'd1;
                                    // Check timeout
                                    if (cycle_counter >= MAX_CYCLES) begin
                                        state <= FINISHED;
                                        result <= 10'h3FF;
                                    end
                                end
                            end else begin
                                // Timeout at curr_time
                                state <= FINISHED;
                                result <= 10'h3FF;
                            end
                        end
                    end else begin
                        // Queue empty and search started
                        if (cycle_counter > 10'd0) begin
                            state <= FINISHED;
                            result <= 10'h3FF;
                        end
                    end
                end

                FINISHED: begin
                    done <= 1'b1;
                    // Wait for start to go low
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule