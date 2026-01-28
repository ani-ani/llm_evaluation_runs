module CourseSelector(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] k,
    input [7:0] diff [0:15],
    input [1:0] type [0:15],
    input [3:0] parent [0:15],
    output reg [15:0] result,
    output reg done,
    output reg valid
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SORT = 3'd1;
    localparam [2:0] DP_INIT = 3'd2;
    localparam [2:0] DP_COMPUTE = 3'd3;
    localparam [2:0] RESULT = 3'd4;
    
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Course sorting registers
    reg [3:0] sorted_idx [0:15];
    reg [3:0] sort_i, sort_j;
    reg [7:0] temp_diff;
    reg [1:0] temp_type;
    reg [3:0] temp_parent;

    // DP state registers
    reg [15:0] dp [0:15][0:255];
    reg [3:0] dp_i;
    reg [7:0] dp_mask;
    reg [3:0] dp_j;
    reg [15:0] min_cost;
    reg [15:0] current_cost;
    reg [3:0] popcount;
    reg [3:0] bit_idx;
    reg valid_mask;

    // Course selection tracking
    reg [3:0] course_idx;
    reg [3:0] parent_idx;
    reg parent_selected;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            
            // Initialize sorting registers
            sort_i <= 4'd0;
            sort_j <= 4'd0;
            
            // Initialize DP registers
            dp_i <= 4'd0;
            dp_mask <= 8'd0;
            dp_j <= 4'd0;
            min_cost <= 16'd32767;
            current_cost <= 16'd0;
            popcount <= 4'd0;
            bit_idx <= 4'd0;
            valid_mask <= 1'b0;
            
            course_idx <= 4'd0;
            parent_idx <= 4'd0;
            parent_selected <= 1'b0;
            
            // Initialize sorted indices
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                sorted_idx[i] <= i;
            end
            
            // Initialize DP table
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 256; j = j + 1) begin
                    dp[i][j] <= 16'd32767;
                end
            end
            
            result <= 16'd0;
            done <= 1'b0;
            valid <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SORT;
                end
            end
            
            SORT: begin
                if (cycle_count < 8'd10) begin
                    next_state = SORT;
                end else begin
                    next_state = DP_INIT;
                end
            end
            
            DP_INIT: begin
                if (cycle_count < 8'd20) begin
                    next_state = DP_INIT;
                end else begin
                    next_state = DP_COMPUTE;
                end
            end
            
            DP_COMPUTE: begin
                if (cycle_count < 8'd150) begin
                    next_state = DP_COMPUTE;
                end else begin
                    next_state = RESULT;
                end
            end
            
            RESULT: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sorting logic (bubble sort for simplicity)
    always @(posedge clk) begin
        if (state == SORT) begin
            if (sort_i < n - 1) begin
                if (sort_j < n - sort_i - 1) begin
                    if (diff[sorted_idx[sort_j]] > diff[sorted_idx[sort_j + 1]]) begin
                        // Swap indices
                        temp_diff = diff[sorted_idx[sort_j]];
                        temp_type = type[sorted_idx[sort_j]];
                        temp_parent = parent[sorted_idx[sort_j]];
                        
                        sorted_idx[sort_j] <= sorted_idx[sort_j + 1];
                        sorted_idx[sort_j + 1] <= sorted_idx[sort_j];
                    end
                    sort_j <= sort_j + 1;
                end else begin
                    sort_j <= 4'd0;
                    sort_i <= sort_i + 1;
                end
            end else begin
                sort_i <= 4'd0;
            end
        end
    end

    // DP initialization
    always @(posedge clk) begin
        if (state == DP_INIT) begin
            if (dp_i < n) begin
                if (dp_mask < 256) begin
                    // Initialize base cases
                    if (dp_i == 0) begin
                        if (dp_mask == 0) begin
                            dp[0][0] <= 16'd0;
                        end else begin
                            dp[0][dp_mask] <= 16'd32767;
                        end
                    end else begin
                        // Check if course can be selected
                        course_idx = sorted_idx[dp_i];
                        
                        // Check if it's a LevelII course
                        if (type[course_idx] == 2'd2) begin
                            parent_idx = parent[course_idx];
                            parent_selected = (dp_mask[parent_idx] == 1'b1);
                        end else begin
                            parent_selected = 1'b1;
                        end
                        
                        if (parent_selected) begin
                            // Option 1: Don't select current course
                            dp[dp_i][dp_mask] <= dp[dp_i - 1][dp_mask];
                            
                            // Option 2: Select current course
                            if (dp_mask[dp_i] == 1'b1) begin
                                current_cost = dp[dp_i - 1][dp_mask & ~(1 << dp_i)] + diff[course_idx];
                                if (current_cost < dp[dp_i][dp_mask]) begin
                                    dp[dp_i][dp_mask] <= current_cost;
                                end
                            end
                        end else begin
                            // Can't select this course
                            dp[dp_i][dp_mask] <= dp[dp_i - 1][dp_mask];
                        end
                    end
                    dp_mask <= dp_mask + 1;
                end else begin
                    dp_mask <= 8'd0;
                    dp_i <= dp_i + 1;
                end
            end else begin
                dp_i <= 4'd0;
            end
        end
    end

    // DP computation and result extraction
    always @(posedge clk) begin
        if (state == DP_COMPUTE) begin
            if (dp_mask < 256) begin
                // Count number of selected courses
                popcount = 0;
                for (bit_idx = 0; bit_idx < n; bit_idx = bit_idx + 1) begin
                    if (dp_mask[bit_idx] == 1'b1) begin
                        popcount = popcount + 1;
                    end
                end
                
                // Check if this is a valid selection
                if (popcount == k) begin
                    // Check all prerequisite constraints
                    valid_mask = 1'b1;
                    for (course_idx = 0; course_idx < n; course_idx = course_idx + 1) begin
                        if (dp_mask[course_idx] == 1'b1 && type[sorted_idx[course_idx]] == 2'd2) begin
                            parent_idx = parent[sorted_idx[course_idx]];
                            if (dp_mask[parent_idx] != 1'b1) begin
                                valid_mask = 1'b0;
                            end
                        end
                    end
                    
                    if (valid_mask && dp[n-1][dp_mask] < min_cost) begin
                        min_cost <= dp[n-1][dp_mask];
                    end
                end
                dp_mask <= dp_mask + 1;
            end else begin
                dp_mask <= 8'd0;
            end
        end
    end

    // Result output
    always @(posedge clk) begin
        if (state == RESULT) begin
            if (min_cost < 16'd32767) begin
                result <= min_cost;
                valid <= 1'b1;
            end else begin
                result <= 16'd0;
                valid <= 1'b0;
            end
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

    // Cycle counter
    always @(posedge clk) begin
        if (state != IDLE) begin
            if (cycle_count < MAX_CYCLES) begin
                cycle_count <= cycle_count + 1;
            end else begin
                cycle_count <= 8'd0;
            end
        end else begin
            cycle_count <= 8'd0;
        end
    end

endmodule