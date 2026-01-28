module max_sum_inc_subseq (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_in,
    input wire [1:0] index,
    input wire [1:0] k,
    input wire write_en,
    output reg [15:0] result,
    output reg done,
    output reg arr_ready
);

    // State definitions
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] LOAD_ARRAY   = 3'd1;
    localparam [2:0] COMPUTE_INIT = 3'd2;
    localparam [2:0] COMPUTE_LOOP = 3'd3;
    localparam [2:0] FETCH_RESULT = 3'd4;
    localparam [2:0] OUTPUT_DONE  = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] arr [0:7];          // 8-element array
    reg [15:0] dp [0:3][0:3];     // 4x4 DP table (scaled down from 8x8)
    reg [3:0] load_cnt;           // Counter for loading (0-7)
    reg [2:0] i_idx, next_i;      // Outer loop index (0-3)
    reg [2:0] j_idx, next_j;      // Inner loop index (0-3)
    reg [15:0] temp_result;       // Temporary result storage
    reg [15:0] temp_dp_val;       // Temporary DP value
    reg [15:0] temp_val_a, temp_val_b; // Intermediate values for comparison
    reg [15:0] val_i_j, val_i1_j, val_i1_i; // Specific DP values
    
    // Control signals
    reg load_done;
    reg compute_done;
    reg loop_done;
    
    // Helper variables (no break/continue allowed)
    reg loop_active;
    reg [2:0] current_i;
    reg [2:0] current_j;

    // Load counter logic (counts 0 to 7)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_cnt <= 4'd0;
        end else if (state == LOAD_ARRAY && write_en) begin
            load_cnt <= load_cnt + 4'd1;
        end else if (state == IDLE) begin
            load_cnt <= 4'd0;
        end
    end

    // Load array data
    integer m;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (m = 0; m < 8; m = m + 1) begin
                arr[m] <= 8'd0;
            end
        end else if (state == LOAD_ARRAY && write_en) begin
            if (load_cnt < 4'd8) begin
                arr[load_cnt[2:0]] <= arr_in;
            end
        end
    end

    // Load done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_done <= 1'b0;
            arr_ready <= 1'b0;
        end else begin
            if (state == LOAD_ARRAY && load_cnt == 4'd7 && write_en) begin
                load_done <= 1'b1;
                arr_ready <= 1'b1;
            end else begin
                load_done <= 1'b0;
                arr_ready <= 1'b0;
            end
        end
    end

    // DP Table initialization and update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i_idx = 0; i_idx < 4; i_idx = i_idx + 1) begin
                for (j_idx = 0; j_idx < 4; j_idx = j_idx + 1) begin
                    dp[i_idx][j_idx] <= 16'sd0;
                end
            end
        end else if (state == COMPUTE_INIT) begin
            // Initialize i=0 row
            for (j_idx = 0; j_idx < 4; j_idx = j_idx + 1) begin
                if (arr[j_idx] > arr[0]) begin
                    dp[0][j_idx] <= {8'd0, arr[0]} + {8'd0, arr[j_idx]};
                end else begin
                    dp[0][j_idx] <= {8'd0, arr[j_idx]};
                end
            end
        end else if (state == COMPUTE_LOOP && loop_active) begin
            // Store values for next cycle logic
            if (current_i > 0) begin
                dp[current_i][current_j] <= temp_dp_val;
            end
        end
    end

    // Loop index control
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i_idx <= 3'd0;
            j_idx <= 3'd0;
        end else begin
            if (state == COMPUTE_LOOP && loop_active) begin
                // Update indices based on previous cycle's active state
                // Use prev values to determine next values, handled in combinational logic below
            end
        end
    end

    // Combinational logic for loop progression and DP calculation
    always @(*) begin
        // Default values
        next_i = i_idx;
        next_j = j_idx;
        loop_done = 1'b0;
        compute_done = 1'b0;
        
        // Only update if we are active
        if (loop_active) begin
            // Increment inner loop
            next_j = current_j + 1;
            
            // Check if inner loop finished
            if (next_j >= 4'd4) begin
                next_j = 3'd0;
                next_i = current_i + 1;
                
                // Check if outer loop finished
                if (next_i >= 4'd4) begin
                    next_i = 3'd0;
                    compute_done = 1'b1; // Signal completion
                end
            end else begin
                next_i = current_i;
            end
            
            // Check loop termination (if flagged done externally)
            if (compute_done) begin
                loop_done = 1'b1;
            end
        end

        // DP Calculation Logic
        temp_dp_val = 16'sd0;
        
        // Safe access to arrays (Verilog 2001 compatibility)
        // Current: i, j. Previous: i-1
        // Values needed: arr[i], arr[j], dp[i-1][i], dp[i-1][j]
        
        // Fetch values safely
        if (current_i == 0) begin
            // Base case handled in init block
            val_i_j = 16'sd0;
            val_i1_j = 16'sd0;
            val_i1_i = 16'sd0;
        end else begin
            // For i > 0
            // Check bounds for array access
            if (current_j < 4 && current_i < 4) begin
                 // arr[j] > arr[i] AND j > i (strictly increasing index)
                 if ((arr[current_j] > arr[current_i]) && (current_j > current_i)) begin
                     // dp[i-1][i] + arr[j]
                     // dp[i-1][j]
                     
                     // Retrieve dp[i-1][i]
                     val_i1_i = dp[current_i - 1][current_i];
                     // Retrieve dp[i-1][j] 
                     val_i1_j = dp[current_i - 1][current_j];
                     
                     // Max comparison
                     temp_val_a = val_i1_i + {8'd0, arr[current_j]};
                     temp_val_b = val_i1_j;
                     
                     if (temp_val_a > temp_val_b) begin
                         temp_dp_val = temp_val_a;
                     end else begin
                         temp_dp_val = temp_val_b;
                     end
                 end else begin
                     // dp[i-1][j]
                     val_i1_j = dp[current_i - 1][current_j];
                     temp_dp_val = val_i1_j;
                 end
            end else begin
                temp_dp_val = 16'sd0;
            end
        end
    end

    // Result fetch and output
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 16'sd0;
            done <= 1'b0;
            temp_result <= 16'sd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                end
                
                FETCH_RESULT: begin
                    // Fetch dp[index][k]
                    if (index < 4 && k < 4) begin
                        temp_result <= dp[index][k];
                    end else begin
                        temp_result <= 16'sd0;
                    end
                end
                
                OUTPUT_DONE: begin
                    result <= temp_result;
                    done <= 1'b1;
                end
                
                default: begin
                    done <= 1'b0;
                end
            endcase
        end
    end

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            loop_active <= 1'b0;
            current_i <= 3'd0;
            current_j <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (load_done) begin
                        if (start) begin
                            state <= COMPUTE_INIT;
                            loop_active <= 1'b0;
                        end else begin
                            state <= LOAD_ARRAY; // Stay ready if not started
                            loop_active <= 1'b0;
                        end
                    end else begin
                        state <= LOAD_ARRAY;
                        loop_active <= 1'b0;
                    end
                end
                
                LOAD_ARRAY: begin
                    if (load_done) begin
                        if (start) begin
                            state <= COMPUTE_INIT;
                        end else begin
                            state <= IDLE;
                        end
                    end else begin
                        state <= LOAD_ARRAY;
                    end
                end
                
                COMPUTE_INIT: begin
                    state <= COMPUTE_LOOP;
                    loop_active <= 1'b1;
                    current_i <= 3'd1; // Start at i=1 (base case i=0 is done)
                    current_j <= 3'd0;
                end
                
                COMPUTE_LOOP: begin
                    if (loop_done) begin
                        state <= FETCH_RESULT;
                        loop_active <= 1'b0;
                    end else begin
                        // Update loop indices for next cycle
                        current_i <= next_i;
                        current_j <= next_j;
                        state <= COMPUTE_LOOP;
                    end
                end
                
                FETCH_RESULT: begin
                    state <= OUTPUT_DONE;
                end
                
                OUTPUT_DONE: begin
                    state <= IDLE;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    loop_active <= 1'b0;
                end
            endcase
        end
    end

endmodule