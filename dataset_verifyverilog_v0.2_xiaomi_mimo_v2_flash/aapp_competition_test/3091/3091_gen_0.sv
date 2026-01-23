module kenken_section (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,             // Grid size (max 9)
    input [3:0] m,             // Section size (max 3)
    input [31:0] t_fixed,      // Target value in Q16.16 format
    input [1:0] op,            // 0:+, 1:-, 2:*, 3:/
    input [3:0] row_addr,      // Address for row input
    input [3:0] col_addr,      // Address for col input
    input [3:0] row_data_in,   // Row coordinate data
    input [3:0] col_data_in,   // Col coordinate data
    input write_en,            // Write coordinate enable
    output reg [31:0] count,   // Number of valid assignments
    output reg done            // High when finished
);

    // Internal arrays for coordinates (max m=3)
    reg [3:0] rows [0:2];
    reg [3:0] cols [0:2];

    // State definitions
    localparam IDLE = 3'b000;
    localparam SETUP = 3'b001;
    localparam GEN_PERM = 3'b010;
    localparam CHECK_UNIQUE = 3'b011;
    localparam CHECK_ARITH = 3'b100;
    localparam UPDATE_COUNT = 3'b101;
    localparam NEXT_PERM = 3'b110;
    localparam FINISHED = 3'b111;

    reg [2:0] state;
    reg [2:0] next_state;

    // Permutation generation
    reg [3:0] nums [0:2];      // Current values (1 to n)
    reg [3:0] used_mask;       // Bitmask to track used numbers in current permutation
    reg [2:0] idx;             // Current index being filled
    reg [3:0] cursor;          // Helper for finding next number

    // Arithmetic intermediates
    reg is_valid;
    reg [31:0] accum_sum;
    reg [31:0] accum_prod;
    reg [31:0] div_check_val;
    reg [2:0] arith_idx;

    // Coordinate write logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset logic handled in state machine usually, but arrays need care
        end else if (write_en) begin
            if (row_addr < 3'd3) rows[row_addr] <= row_data_in;
            if (col_addr < 3'd3) cols[col_addr] <= col_data_in;
        end
    end

    // State Transition and Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 0;
            done <= 0;
            idx <= 0;
            used_mask <= 0;
            arith_idx <= 0;
            is_valid <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start && m > 0) begin
                        state <= SETUP;
                        count <= 0;
                        done <= 0;
                    end
                end

                SETUP: begin
                    // Initialize for permutation generation
                    idx <= 0;
                    used_mask <= 0;
                    nums[0] <= 0;
                    nums[1] <= 0;
                    nums[2] <= 0;
                    cursor <= 1;
                    state <= GEN_PERM;
                end

                GEN_PERM: begin
                    // Logic to find next valid number for current index 'idx'
                    // We scan 'cursor' from nums[idx] + 1 up to n
                    // Since this is combinational logic essentially, we do one step per cycle or loop inside
                    // To keep it synthesizable and efficient, we process the "add" operation here.
                    
                    // First, check if we need to backtrack
                    if (nums[idx] == 0 && idx > 0 && cursor == 1) begin
                        // Just backtracked, need to try numbers for this index starting from 1
                    end

                    // Try current cursor
                    if (cursor <= n) begin
                        if (used_mask[cursor] == 0) begin
                            // Found a valid number
                            nums[idx] <= cursor;
                            used_mask[cursor] <= 1;
                            idx <= idx + 1;
                            cursor <= 1; // Reset cursor for next index
                            
                            // Check if permutation is full
                            if (idx + 1 == m) begin
                                state <= CHECK_UNIQUE;
                            end else begin
                                state <= GEN_PERM;
                            end
                        end else begin
                            // Used, try next
                            cursor <= cursor + 1;
                            state <= GEN_PERM;
                        end
                    end else begin
                        // Exhausted numbers at this index, backtrack
                        if (idx > 0) begin
                            idx <= idx - 1;
                            used_mask[nums[idx]] <= 0; // Unmark the number at previous index
                            cursor <= nums[idx] + 1;    // Start searching from next number
                            nums[idx] <= 0;
                            state <= GEN_PERM;
                        end else begin
                            // Exhausted all permutations
                            state <= FINISHED;
                        end
                    end
                end

                CHECK_UNIQUE: begin
                    // Check row and column uniqueness
                    is_valid <= 1;
                    if (m >= 2) begin
                        if (rows[0] == rows[1] || cols[0] == cols[1]) is_valid <= 0;
                    end
                    if (m >= 3) begin
                        if (rows[0] == rows[2] || rows[0] == rows[1] || rows[1] == rows[2]) is_valid <= 0;
                        if (cols[0] == cols[2] || cols[0] == cols[1] || cols[1] == cols[2]) is_valid <= 0;
                    end
                    arith_idx <= 0;
                    state <= CHECK_ARITH;
                end

                CHECK_ARITH: begin
                    // Process arithmetic based on op
                    // We use arith_idx to iterate 1 to m-1 (since we initialize with nums[0])
                    if (arith_idx == 0) begin
                        // Initialize accumulators
                        accum_sum <= nums[0] * 65536;
                        accum_prod <= nums[0] * 65536;
                        div_check_val <= nums[0] * 65536; // Store first value for division/subtraction
                        arith_idx <= 1;
                    end else if (arith_idx < m) begin
                        // Perform operation
                        if (op == 0) // Add
                            accum_sum <= accum_sum + (nums[arith_idx] * 65536);
                        else if (op == 2) // Multiply
                            accum_prod <= (accum_prod * (nums[arith_idx] * 65536)) >> 16;
                        
                        arith_idx <= arith_idx + 1;
                    end else begin
                        state <= UPDATE_COUNT;
                    end
                end

                UPDATE_COUNT: begin
                    if (is_valid) begin
                        // Check condition
                        // Note: t_fixed is Q16.16. nums are integers.
                        if (op == 0) begin // +
                            if (accum_sum == t_fixed) count <= count + 1;
                        end else if (op == 2) begin // *
                            if (accum_prod == t_fixed) count <= count + 1;
                        end else if (op == 1) begin // -
                            // Check |nums[0] - nums[1]| ... tricky with variables.
                            // Simplification: Loop calculation is robust. 
                            // For m=2: A - B == T or B - A == T
                            // We have nums array. Let's do combinational check for small m
                            // Since it's sequential, we just check the specific case
                            if (m == 2) begin
                                if ( ((nums[0] * 65536) - (nums[1] * 65536) == t_fixed) ||
                                     ((nums[1] * 65536) - (nums[0] * 65536) == t_fixed) )
                                    count <= count + 1;
                            end else if (m == 3) begin
                                if ( ((nums[0]*65536 + nums[1]*65536) - (nums[2]*65536) == t_fixed) ||
                                     ((nums[0]*65536 + nums[2]*65536) - (nums[1]*65536) == t_fixed) ||
                                     ((nums[1]*65536 + nums[2]*65536) - (nums[0]*65536) == t_fixed) ||
                                     ((nums[0]*65536) - (nums[1]*65536 + nums[2]*65536) == t_fixed) ||
                                     ((nums[1]*65536) - (nums[0]*65536 + nums[2]*65536) == t_fixed) ||
                                     ((nums[2]*65536) - (nums[0]*65536 + nums[1]*65536) == t_fixed) )
                                    count <= count + 1;
                            end
                        end else if (op == 3) begin // /
                            // Check a/b == T or b/a == T
                            // Using fixed point: a == T * b
                            if (m == 2) begin
                                // Avoid divide by zero, use multiply check
                                if ( (nums[1] != 0 && (nums[0]*65536) == (t_fixed * nums[1])) ||
                                     (nums[0] != 0 && (nums[1]*65536) == (t_fixed * nums[0])) )
                                    count <= count + 1;
                            end else if (m == 3) begin
                                // Complex div 3 operands: e.g., a / b / c = T -> a = T*b*c. Or a / (b/c) = T. 
                                // KenKen usually binary or strict. Assume simple binary ops for m=3 if op is /.
                                // Or perhaps (a+b)/c. 
                                // Let's assume standard KenKen: (a+b)/c == T, etc.
                                // Check all permutations of (X op Y) op Z
                                // This requires intermediate storage. Since we used accum_sum for sum, we can use it.
                                // But we need to check: (X+Y)/Z == T -> X+Y == T*Z
                                if ( ((nums[0]*65536 + nums[1]*65536) == (t_fixed * nums[2])) && nums[2]!=0 ) count <= count + 1;
                                if ( ((nums[0]*65536 + nums[2]*65536) == (t_fixed * nums[1])) && nums[1]!=0 ) count <= count + 1;
                                if ( ((nums[1]*65536 + nums[2]*65536) == (t_fixed * nums[0])) && nums[0]!=0 ) count <= count + 1;
                                // Check X/(Y+Z) == T -> X == T*(Y+Z)
                                if ( (nums[0]*65536 == (t_fixed * (nums[1]*65536 + nums[2]*65536)>>16)) && (nums[1]+nums[2])!=0 ) count <= count + 1;
                                if ( (nums[1]*65536 == (t_fixed * (nums[0]*65536 + nums[2]*65536)>>16)) && (nums[0]+nums[2])!=0 ) count <= count + 1;
                                if ( (nums[2]*65536 == (t_fixed * (nums[0]*65536 + nums[1]*65536)>>16)) && (nums[0]+nums[1])!=0 ) count <= count + 1;
                            end
                        end
                    end
                    state <= NEXT_PERM;
                end

                NEXT_PERM: begin
                    // Trigger next permutation generation by resetting cursor for the modified index
                    // The GEN_PERM state will handle the logic
                    // We need to backtrack to the previous index to increment it
                    // Actually, the GEN_PERM logic above handles backtrack when nums[idx]==0.
                    // Here we just set up the state to enter GEN_PERM.
                    // If we just finished a valid perm (idx==m), we need to backtrack from m-1.
                    if (idx == m) begin
                        idx <= m - 1;
                        used_mask[nums[m-1]] <= 0;
                        cursor <= nums[m-1] + 1;
                        nums[m-1] <= 0;
                    end
                    state <= GEN_PERM;
                end

                FINISHED: begin
                    done <= 1;
                    state <= FINISHED;
                end
            endcase
        end
    end

endmodule
