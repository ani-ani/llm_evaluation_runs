module MaxSumIncreasingSubseq(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    input wire [2:0] target_index,
    input wire [2:0] target_k,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE_ROW_0 = 3'd2;
    localparam [2:0] COMPUTE_ROWS = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;

    reg [2:0] state, next_state;

    // DP table storage (8x8, 16-bit entries)
    reg [15:0] dp [0:7];
    reg [15:0] dp_next [0:7];

    // Internal array storage
    reg [7:0] arr [0:7];

    // Counters
    reg [2:0] i_counter;
    reg [2:0] j_counter;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i_counter <= 3'd0;
            j_counter <= 3'd0;
            
            // Initialize DP table
            integer k;
            for (k = 0; k < 8; k = k + 1) begin
                dp[k] <= 16'd0;
                dp_next[k] <= 16'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end
            
            LOAD: begin
                next_state = COMPUTE_ROW_0;
            end
            
            COMPUTE_ROW_0: begin
                if (j_counter == 3'd7) begin
                    next_state = COMPUTE_ROWS;
                    i_counter = 3'd1;
                    j_counter = 3'd0;
                end
            end
            
            COMPUTE_ROWS: begin
                if (i_counter == 3'd7 && j_counter == 3'd7) begin
                    next_state = OUTPUT;
                end
            end
            
            OUTPUT: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Load inputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in state machine reset
        end else if (state == LOAD) begin
            arr[0] <= arr_0;
            arr[1] <= arr_1;
            arr[2] <= arr_2;
            arr[3] <= arr_3;
            arr[4] <= arr_4;
            arr[5] <= arr_5;
            arr[6] <= arr_6;
            arr[7] <= arr_7;
            
            // Initialize DP table row 0
            dp[0] <= arr[0];
            j_counter <= 3'd1;
        end
    end

    // Compute row 0
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled
        end else if (state == COMPUTE_ROW_0) begin
            if (arr[j_counter] > arr[0]) begin
                dp[j_counter] <= arr[j_counter] + arr[0];
            end else begin
                dp[j_counter] <= arr[j_counter];
            end
            
            if (j_counter < 3'd7) begin
                j_counter <= j_counter + 3'd1;
            end
        end
    end

    // Compute remaining rows
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled
        end else if (state == COMPUTE_ROWS) begin
            // Copy current row to next row
            integer k;
            for (k = 0; k < 8; k = k + 1) begin
                dp_next[k] <= dp[k];
            end
            
            // Compute dp[i][j]
            if (arr[j_counter] > arr[i_counter] && j_counter > i_counter) begin
                if (dp[i_counter] + arr[j_counter] > dp[j_counter]) begin
                    dp_next[j_counter] <= dp[i_counter] + arr[j_counter];
                end else begin
                    dp_next[j_counter] <= dp[j_counter];
                end
            end else begin
                dp_next[j_counter] <= dp[j_counter];
            end
            
            // Update counters
            if (j_counter < 3'd7) begin
                j_counter <= j_counter + 3'd1;
            end else begin
                j_counter <= 3'd0;
                if (i_counter < 3'd7) begin
                    i_counter <= i_counter + 3'd1;
                    // Copy dp_next back to dp
                    for (k = 0; k < 8; k = k + 1) begin
                        dp[k] <= dp_next[k];
                    end
                end
            end
        end
    end

    // Output result
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else if (state == OUTPUT) begin
            result <= dp[target_k];
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

    // Cycle counter for safety
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
        end else if (state != IDLE) begin
            cycle_count <= cycle_count + 8'd1;
            if (cycle_count >= MAX_CYCLES) begin
                state <= IDLE;
                done <= 1'b0;
            end
        end
    end

endmodule