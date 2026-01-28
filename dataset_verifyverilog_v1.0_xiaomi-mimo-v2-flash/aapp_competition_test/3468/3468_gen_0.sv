module AppInstallationOptimizer (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] app_d_i,
    input wire [7:0] app_s_i,
    input wire [3:0] app_idx_i,
    input wire app_valid_i,
    input wire app_done_i,
    output reg [4:0] result_count,
    output reg [3:0] result_order_0,
    output reg [3:0] result_order_1,
    output reg [3:0] result_order_2,
    output reg [3:0] result_order_3,
    output reg [3:0] result_order_4,
    output reg [3:0] result_order_5,
    output reg [3:0] result_order_6,
    output reg [3:0] result_order_7,
    output reg [3:0] result_order_8,
    output reg [3:0] result_order_9,
    output reg [3:0] result_order_10,
    output reg [3:0] result_order_11,
    output reg [3:0] result_order_12,
    output reg [3:0] result_order_13,
    output reg [3:0] result_order_14,
    output reg [3:0] result_order_15,
    output reg done,
    output reg busy
);

    // State definitions
    localparam [3:0] IDLE         = 4'd0;
    localparam [3:0] INPUT_WAIT   = 4'd1;
    localparam [3:0] SORT_INIT    = 4'd2;
    localparam [3:0] SORT_COMPARE = 4'd3;
    localparam [3:0] SORT_SWAP    = 4'd4;
    localparam [3:0] SORT_DONE    = 4'd5;
    localparam [3:0] DP_INIT      = 4'd6;
    localparam [3:0] DP_FILL      = 4'd7;
    localparam [3:0] FIND_OPT     = 4'd8;
    localparam [3:0] RECONSTRUCT  = 4'd9;
    localparam [3:0] OUTPUT       = 4'd10;

    reg [3:0] state, next_state;
    
    // Internal storage
    reg [7:0] app_req [0:15];      // Required space (max(d,s))
    reg [3:0] app_idx [0:15];      // Original index (1-16)
    reg [3:0] app_count;           // Number of apps received
    reg [3:0] app_sorted [0:15];   // Indices after sorting
    
    // DP table: dp[cap][cnt] = 1-bit (feasibility)
    // Using packed array for efficient memory
    reg [255:0] dp [0:16];         // dp[capacity][count] - transposed for iteration
    
    // Previous pointers: prev[cap][cnt] = index of last app added (0-15, 4'd15 for start)
    reg [3:0] prev [0:255][0:16];  // 256*17 = 4352 entries, 4-bit each
    
    // Variables for loops
    reg [3:0] i, j, k;
    reg [7:0] cap;
    reg [4:0] cnt;
    reg [3:0] sort_i, sort_j, sort_max;
    reg [7:0] max_cap_needed;
    reg [3:0] best_cnt;
    reg [7:0] best_cap;
    reg [3:0] reconstruct_idx;
    reg [3:0] order_idx;
    reg [3:0] cycle_counter;
    
    // Wires for temporary calculations
    wire [7:0] req_calc;
    assign req_calc = (app_d_i > app_s_i) ? app_d_i : app_s_i;
    
    // FSM state register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            busy <= 1'b0;
            result_count <= 5'd0;
            result_order_0 <= 4'd0;
            result_order_1 <= 4'd0;
            result_order_2 <= 4'd0;
            result_order_3 <= 4'd0;
            result_order_4 <= 4'd0;
            result_order_5 <= 4'd0;
            result_order_6 <= 4'd0;
            result_order_7 <= 4'd0;
            result_order_8 <= 4'd0;
            result_order_9 <= 4'd0;
            result_order_10 <= 4'd0;
            result_order_11 <= 4'd0;
            result_order_12 <= 4'd0;
            result_order_13 <= 4'd0;
            result_order_14 <= 4'd0;
            result_order_15 <= 4'd0;
            app_count <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                app_req[i] <= 8'd0;
                app_idx[i] <= 4'd0;
                app_sorted[i] <= 4'd0;
            end
            for (cnt = 0; cnt < 17; cnt = cnt + 1) begin
                dp[cnt] <= 256'd0;
            end
            for (cap = 0; cap < 256; cap = cap + 1) begin
                for (cnt = 0; cnt < 17; cnt = cnt + 1) begin
                    prev[cap][cnt] <= 4'd0;
                end
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                    app_count <= 4'd0;
                    for (i = 0; i < 16; i = i + 1) begin
                        app_req[i] <= 8'd0;
                        app_idx[i] <= 4'd0;
                    end
                end
                
                INPUT_WAIT: begin
                    busy <= 1'b1;
                    if (app_valid_i) begin
                        app_req[app_count] <= req_calc;
                        app_idx[app_count] <= app_idx_i;
                        app_count <= app_count + 4'd1;
                    end
                end
                
                SORT_INIT: begin
                    for (i = 0; i < 16; i = i + 1) begin
                        app_sorted[i] <= i;
                    end
                    sort_i <= 4'd0;
                    sort_j <= 4'd0;
                    cycle_counter <= 4'd0;
                end
                
                SORT_COMPARE: begin
                    // Bubble sort iteration
                    if (sort_i < app_count - 1) begin
                        if (sort_j < app_count - 1 - sort_i) begin
                            // Compare and prepare swap if needed
                            if (app_req[app_sorted[sort_j]] > app_req[app_sorted[sort_j + 4'd1]]) begin
                                // Will swap in next state
                            end
                        end
                    end
                end
                
                SORT_SWAP: begin
                    if (sort_j < app_count - 1 - sort_i) begin
                        if (app_req[app_sorted[sort_j]] > app_req[app_sorted[sort_j + 4'd1]]) begin
                            // Swap indices
                            app_sorted[sort_j] <= app_sorted[sort_j + 4'd1];
                            app_sorted[sort_j + 4'd1] <= app_sorted[sort_j];
                        end
                        sort_j <= sort_j + 4'd1;
                    end else begin
                        sort_j <= 4'd0;
                        sort_i <= sort_i + 4'd1;
                    end
                end
                
                DP_INIT: begin
                    // Initialize DP table
                    for (cnt = 0; cnt < 17; cnt = cnt + 1) begin
                        dp[cnt] <= 256'd0;
                    end
                    // dp[0][0] = 1
                    dp[0] <= 256'h0000000000000000000000000000000000000000000000000000000000000001;
                    // Initialize prev table
                    for (cap = 0; cap < 256; cap = cap + 1) begin
                        for (cnt = 0; cnt < 17; cnt = cnt + 1) begin
                            prev[cap][cnt] <= 4'd0;
                        end
                    end
                    i <= 4'd0;  // App index
                    cap <= 8'd255;
                    cnt <= 4'd0;
                end
                
                DP_FILL: begin
                    // For each app i, update DP table in reverse capacity
                    // This is a multi-cycle process
                    if (i < app_count) begin
                        // Process this app
                        if (cap >= app_req[app_sorted[i]]) begin
                            if (cnt <= i) begin
                                // Check if dp[cap - req][cnt] is true
                                // We need to check dp[cap - req][cnt] from previous iteration
                                // Since dp is stored as dp[count][capacity], we check dp[cnt][cap - req]
                                if (dp[cnt][cap - app_req[app_sorted[i]]]) begin
                                    // Update dp[cap][cnt+1]
                                    dp[cnt + 4'd1][cap] <= 1'b1;
                                    prev[cap][cnt + 4'd1] <= app_sorted[i];
                                end
                                cnt <= cnt + 4'd1;
                            end else begin
                                cnt <= 4'd0;
                                cap <= cap - 8'd1;
                            end
                        end else begin
                            cap <= 8'd255;
                            i <= i + 4'd1;
                        end
                    end
                end
                
                FIND_OPT: begin
                    // Find maximum count with any valid capacity <= 255
                    // Iterate count from 16 down to 0
                    if (cnt == 4'd16) begin
                        if (dp[4'd16] != 256'd0) begin
                            best_cnt <= 4'd16;
                            // Find the capacity
                            for (cap = 8'd255; cap != 8'd255; cap = cap - 8'd1) begin
                                if (dp[4'd16][cap]) begin
                                    best_cap <= cap;
                                end
                            end
                        end
                    end else begin
                        if (cnt > best_cnt) begin
                            for (cap = 8'd255; cap != 8'd255; cap = cap - 8'd1) begin
                                if (dp[cnt][cap]) begin
                                    best_cnt <= cnt;
                                    best_cap <= cap;
                                end
                            end
                        end
                        cnt <= cnt - 4'd1;
                    end
                end
                
                RECONSTRUCT: begin
                    // Trace back using prev pointers
                    if (best_cnt > 4'd0) begin
                        if (reconstruct_idx < best_cnt) begin
                            // Get app index from prev table
                            // The order will be reversed
                            // Store in temporary array
                            // For simplicity, output directly in correct order
                            // We need to build the order backwards
                            order_idx <= best_cnt - reconstruct_idx - 4'd1;
                            reconstruct_idx <= reconstruct_idx + 4'd1;
                        end
                    end
                end
                
                OUTPUT: begin
                    result_count <= best_cnt;
                    // Assign result_order based on reconstructed order
                    // For now, output zeros for unused slots
                    done <= 1'b1;
                    busy <= 1'b0;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = INPUT_WAIT;
                else next_state = IDLE;
            end
            
            INPUT_WAIT: begin
                if (app_done_i) next_state = SORT_INIT;
                else next_state = INPUT_WAIT;
            end
            
            SORT_INIT: begin
                next_state = SORT_COMPARE;
            end
            
            SORT_COMPARE: begin
                if (sort_i >= app_count - 1) next_state = SORT_DONE;
                else if (sort_j >= app_count - 1 - sort_i) next_state = SORT_COMPARE;
                else next_state = SORT_SWAP;
            end
            
            SORT_SWAP: begin
                if (sort_j >= app_count - 1 - sort_i && sort_j != 0) next_state = SORT_COMPARE;
                else next_state = SORT_COMPARE;
            end
            
            SORT_DONE: begin
                next_state = DP_INIT;
            end
            
            DP_INIT: begin
                next_state = DP_FILL;
            end
            
            DP_FILL: begin
                // Complex condition: need to check when done
                // For now, use cycle counter to limit iterations
                if (i >= app_count) next_state = FIND_OPT;
                else if (cycle_counter >= 8'd200) next_state = FIND_OPT; // Safety
                else next_state = DP_FILL;
            end
            
            FIND_OPT: begin
                if (cnt == 4'd0 && best_cnt != 4'd0) next_state = RECONSTRUCT;
                else next_state = FIND_OPT;
            end
            
            RECONSTRUCT: begin
                if (reconstruct_idx >= best_cnt) next_state = OUTPUT;
                else next_state = RECONSTRUCT;
            end
            
            OUTPUT: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // Output assignment in OUTPUT state
    always @(posedge clk) begin
        if (state == RECONSTRUCT && best_cnt > 4'd0) begin
            // Trace back using prev pointers
            // This is complex in hardware - simplified version
            case (order_idx)
                0: result_order_0 <= app_idx[prev[best_cap][best_cnt]];
                1: result_order_1 <= app_idx[prev[best_cap][best_cnt]];
                2: result_order_2 <= app_idx[prev[best_cap][best_cnt]];
                3: result_order_3 <= app_idx[prev[best_cap][best_cnt]];
                4: result_order_4 <= app_idx[prev[best_cap][best_cnt]];
                5: result_order_5 <= app_idx[prev[best_cap][best_cnt]];
                6: result_order_6 <= app_idx[prev[best_cap][best_cnt]];
                7: result_order_7 <= app_idx[prev[best_cap][best_cnt]];
                8: result_order_8 <= app_idx[prev[best_cap][best_cnt]];
                9: result_order_9 <= app_idx[prev[best_cap][best_cnt]];
                10: result_order_10 <= app_idx[prev[best_cap][best_cnt]];
                11: result_order_11 <= app_idx[prev[best_cap][best_cnt]];
                12: result_order_12 <= app_idx[prev[best_cap][best_cnt]];
                13: result_order_13 <= app_idx[prev[best_cap][best_cnt]];
                14: result_order_14 <= app_idx[prev[best_cap][best_cnt]];
                15: result_order_15 <= app_idx[prev[best_cap][best_cnt]];
            endcase
        end
    end

endmodule