module CourseSelector (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] k,
    input wire [7:0] diff [0:15],
    input wire [1:0] type [0:15],
    input wire [3:0] parent [0:15],
    output reg [15:0] result,
    output reg done,
    output reg valid
);

    // State definitions
    localparam [3:0] IDLE         = 4'd0;
    localparam [3:0] INIT         = 4'd1;
    localparam [3:0] CHECK_VALID  = 4'd2;
    localparam [3:0] SORT_START   = 4'd3;
    localparam [3:0] SORT_COMPARE = 4'd4;
    localparam [3:0] SORT_SWAP    = 4'd5;
    localparam [3:0] DP_INIT      = 4'd6;
    localparam [3:0] DP_PROCESS   = 4'd7;
    localparam [3:0] DP_UPDATE    = 4'd8;
    localparam [3:0] FIND_MIN     = 4'd9;
    localparam [3:0] FINISH       = 4'd10;

    reg [3:0] state, next_state;
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Input storage registers
    reg [3:0] n_reg, k_reg;
    reg [7:0] stored_diff [0:15];
    reg [1:0] stored_type [0:15];
    reg [3:0] stored_parent [0:15];
    integer i, j, idx;

    // Course structure for sorting (indexed by sorted order)
    reg [7:0] sorted_diff [0:15];
    reg [1:0] sorted_type [0:15];
    reg [3:0] sorted_parent [0:15];
    reg [3:0] sorted_id [0:15];  // Original ID for verification
    
    // Sorting variables
    reg [3:0] sort_i, sort_j;
    reg swap_needed;
    
    // DP variables
    reg [15:0] dp [0:15][0:255];  // [course_idx][mask] = min cost
    reg [15:0] next_dp [0:15][0:255];
    reg [7:0] mask;  // Selection mask (up to 16 bits)
    reg [15:0] min_cost, temp_cost;
    reg valid_check;
    reg [3:0] num_level_i, num_level_ii;
    
    // Bit counting for validation
    reg [3:0] bit_count;
    reg [3:0] current_mask_idx;
    
    // FSM logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            result <= 16'd0;
            cycle_counter <= 8'd0;
            n_reg <= 4'd0;
            k_reg <= 4'd0;
            sort_i <= 4'd0;
            sort_j <= 4'd0;
            mask <= 8'd0;
            min_cost <= 16'd65535;
            temp_cost <= 16'd0;
            valid_check <= 1'b0;
            num_level_i <= 4'd0;
            num_level_ii <= 4'd0;
            bit_count <= 4'd0;
            current_mask_idx <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                stored_diff[i] <= 8'd0;
                stored_type[i] <= 2'd0;
                stored_parent[i] <= 4'd0;
                sorted_diff[i] <= 8'd0;
                sorted_type[i] <= 2'd0;
                sorted_parent[i] <= 4'd0;
                sorted_id[i] <= 4'd0;
                for (j = 0; j < 256; j = j + 1) begin
                    dp[i][j] <= 16'd65535;
                    next_dp[i][j] <= 16'd65535;
                end
            end
        end else begin
            state <= next_state;
            cycle_counter <= cycle_counter + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    result <= 16'd0;
                    cycle_counter <= 8'd0;
                    min_cost <= 16'd65535;
                    for (i = 0; i < 16; i = i + 1) begin
                        for (j = 0; j < 256; j = j + 1) begin
                            dp[i][j] <= 16'd65535;
                        end
                    end
                end
                
                INIT: begin
                    n_reg <= n;
                    k_reg <= k;
                    for (i = 0; i < 16; i = i + 1) begin
                        stored_diff[i] <= diff[i];
                        stored_type[i] <= type[i];
                        stored_parent[i] <= parent[i];
                        sorted_diff[i] <= diff[i];
                        sorted_type[i] <= type[i];
                        sorted_parent[i] <= parent[i];
                        sorted_id[i] <= i[3:0];
                    end
                end
                
                CHECK_VALID: begin
                    num_level_i <= 4'd0;
                    num_level_ii <= 4'd0;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < n_reg) begin
                            if (stored_type[i] == 2'd1) num_level_i <= num_level_i + 4'd1;
                            if (stored_type[i] == 2'd2) num_level_ii <= num_level_ii + 4'd1;
                        end
                    end
                end
                
                SORT_START: begin
                    sort_i <= 4'd0;
                    sort_j <= 4'd0;
                end
                
                SORT_COMPARE: begin
                    if (sort_j < n_reg - 4'd1 - sort_i) begin
                        if (sorted_diff[sort_j] > sorted_diff[sort_j + 4'd1]) begin
                            // Swap
                            next_state <= SORT_SWAP;
                        end else begin
                            sort_j <= sort_j + 4'd1;
                            next_state <= SORT_COMPARE;
                        end
                    end else begin
                        sort_i <= sort_i + 4'd1;
                        sort_j <= 4'd0;
                        next_state <= (sort_i < n_reg - 4'd1) ? SORT_COMPARE : DP_INIT;
                    end
                end
                
                SORT_SWAP: begin
                    // Swap diff
                    sorted_diff[sort_j] <= sorted_diff[sort_j + 4'd1];
                    sorted_diff[sort_j + 4'd1] <= sorted_diff[sort_j];
                    // Swap type
                    sorted_type[sort_j] <= sorted_type[sort_j + 4'd1];
                    sorted_type[sort_j + 4'd1] <= sorted_type[sort_j];
                    // Swap parent
                    sorted_parent[sort_j] <= sorted_parent[sort_j + 4'd1];
                    sorted_parent[sort_j + 4'd1] <= sorted_parent[sort_j];
                    // Swap ID
                    sorted_id[sort_j] <= sorted_id[sort_j + 4'd1];
                    sorted_id[sort_j + 4'd1] <= sorted_id[sort_j];
                    sort_j <= sort_j + 4'd1;
                    next_state <= SORT_COMPARE;
                end
                
                DP_INIT: begin
                    // Initialize DP with base case
                    dp[0][0] <= 16'd0;
                    for (mask = 8'd1; mask < 8'd256; mask = mask + 8'd1) begin
                        dp[0][mask] <= 16'd65535;
                    end
                end
                
                DP_PROCESS: begin
                    if (mask < 8'd256) begin
                        // Process mask for current course
                        if (mask[sorted_id[0]]) begin
                            dp[0][mask] <= (sorted_type[0] == 2'd0 || sorted_type[0] == 2'd1) ? {8'd0, sorted_diff[0]} : 16'd65535;
                        end
                        mask <= mask + 8'd1;
                    end
                end
                
                DP_UPDATE: begin
                    // Main DP loop
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < n_reg) begin
                            for (mask = 8'd0; mask < 8'd256; mask = mask + 8'd1) begin
                                if (mask <= ((1 << n_reg) - 1)) begin
                                    if (i == 0) begin
                                        // Handled in DP_PROCESS
                                    end else begin
                                        // Check prerequisite
                                        if (sorted_type[i] == 2'd2) begin
                                            // LevelII - check parent in mask
                                            if (mask[sorted_parent[i]]) begin
                                                if (mask[i[3:0]]) begin
                                                    temp_cost <= dp[i-1][mask] + {8'd0, sorted_diff[i]};
                                                    if (temp_cost < dp[i][mask]) begin
                                                        dp[i][mask] <= temp_cost;
                                                    end
                                                end else begin
                                                    // Course not selected, inherit cost
                                                    dp[i][mask] <= dp[i-1][mask];
                                                end
                                            end else begin
                                                // Parent not selected - invalid
                                                if (mask[i[3:0]]) begin
                                                    dp[i][mask] <= 16'd65535;
                                                end else begin
                                                    dp[i][mask] <= dp[i-1][mask];
                                                end
                                            end
                                        end else begin
                                            // NoLevel or LevelI
                                            if (mask[i[3:0]]) begin
                                                dp[i][mask] <= dp[i-1][mask] + {8'd0, sorted_diff[i]};
                                            end else begin
                                                dp[i][mask] <= dp[i-1][mask];
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                
                FIND_MIN: begin
                    min_cost <= 16'd65535;
                    valid_check <= 1'b0;
                    current_mask_idx <= 4'd0;
                end
                
                FINISH: begin
                    result <= min_cost;
                    valid <= valid_check;
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = INIT;
            end
            INIT: begin
                next_state = CHECK_VALID;
            end
            CHECK_VALID: begin
                if (k_reg > n_reg || k_reg == 4'd0 || num_level_ii > num_level_i) begin
                    next_state = FINISH;
                end else begin
                    next_state = SORT_START;
                end
            end
            SORT_START: begin
                next_state = SORT_COMPARE;
            end
            SORT_COMPARE: begin
                // Handled in sequential
            end
            SORT_SWAP: begin
                // Handled in sequential
            end
            DP_INIT: begin
                next_state = DP_PROCESS;
                mask = 8'd0;
            end
            DP_PROCESS: begin
                if (mask >= 8'd256) begin
                    next_state = DP_UPDATE;
                end
            end
            DP_UPDATE: begin
                next_state = FIND_MIN;
            end
            FIND_MIN: begin
                // Check all masks with bit count = k_reg
                if (current_mask_idx < n_reg) begin
                    bit_count = 4'd0;
                    for (i = 0; i < 4; i = i + 1) begin
                        if (current_mask_idx[i]) bit_count = bit_count + 4'd1;
                    end
                    if (bit_count == k_reg) begin
                        if (dp[n_reg-1][current_mask_idx] < min_cost) begin
                            min_cost = dp[n_reg-1][current_mask_idx];
                            valid_check = 1'b1;
                        end
                    end
                    current_mask_idx = current_mask_idx + 4'd1;
                    next_state = FIND_MIN;
                end else begin
                    next_state = FINISH;
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule