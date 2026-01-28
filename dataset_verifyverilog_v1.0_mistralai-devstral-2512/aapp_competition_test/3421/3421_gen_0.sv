module MaxSuccessSubsequence(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [8:0] k,
    input wire [7:0] s [255:0],
    output reg [7:0] start_idx,
    output reg [7:0] length,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] BINARY_SEARCH = 3'd2;
    localparam [2:0] COMPUTE_PREFIX = 3'd3;
    localparam [2:0] CHECK_FEASIBILITY = 3'd4;
    localparam [2:0] UPDATE_BEST = 3'd5;
    localparam [2:0] FINISH = 3'd6;

    // Registers
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    reg [7:0] i, j;
    reg [7:0] best_start, best_len;
    reg [7:0] current_k;
    reg [15:0] prefix [0:255];
    reg [15:0] min_prefix;
    reg [15:0] current_sum;
    reg [15:0] low, high, mid;
    reg [15:0] best_threshold;
    reg [7:0] s_reg [255:0];
    reg feasible;

    // Binary search parameters
    localparam [7:0] MAX_CYCLES = 8'd200;
    localparam [15:0] INIT_LOW = 16'd0;
    localparam [15:0] INIT_HIGH = 16'd256;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            i <= 8'd0;
            j <= 8'd0;
            best_start <= 8'd0;
            best_len <= 8'd0;
            current_k <= 8'd0;
            min_prefix <= 16'd0;
            current_sum <= 16'd0;
            low <= INIT_LOW;
            high <= INIT_HIGH;
            mid <= 16'd0;
            best_threshold <= 16'd0;
            feasible <= 1'b0;
            done <= 1'b0;
            start_idx <= 8'd0;
            length <= 8'd0;
            
            // Initialize s_reg array
            integer idx;
            for (idx = 0; idx < 256; idx = idx + 1) begin
                s_reg[idx] <= 8'd0;
            end
            
            // Initialize prefix array
            for (idx = 0; idx < 256; idx = idx + 1) begin
                prefix[idx] <= 16'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LOAD;
                    end
                end

                LOAD: begin
                    // Load input data
                    integer idx;
                    for (idx = 0; idx < 256; idx = idx + 1) begin
                        s_reg[idx] <= s[idx];
                    end
                    current_k <= k;
                    next_state <= BINARY_SEARCH;
                end

                BINARY_SEARCH: begin
                    if (cycle_count == 8'd0) begin
                        low <= INIT_LOW;
                        high <= INIT_HIGH;
                        best_threshold <= 16'd0;
                    end
                    
                    if (cycle_count < 8'd16) begin
                        mid <= (low + high) >> 1;
                        next_state <= COMPUTE_PREFIX;
                    end else begin
                        next_state <= UPDATE_BEST;
                    end
                end

                COMPUTE_PREFIX: begin
                    // Compute prefix sums for current threshold
                    prefix[0] <= 16'd0;
                    for (i = 1; i < 256; i = i + 1) begin
                        prefix[i] <= prefix[i-1] + (s_reg[i-1] ? 16'd1 : 16'd0) - mid;
                    end
                    i <= 8'd0;
                    min_prefix <= 16'd0;
                    next_state <= CHECK_FEASIBILITY;
                end

                CHECK_FEASIBILITY: begin
                    // Find minimum prefix in first N-k positions
                    if (i < 256 - current_k) begin
                        if (prefix[i] < min_prefix) begin
                            min_prefix <= prefix[i];
                        end
                        i <= i + 8'd1;
                    end else begin
                        // Check feasibility
                        feasible <= 1'b0;
                        for (j = current_k; j < 256; j = j + 1) begin
                            if (prefix[j] - min_prefix >= 16'd0) begin
                                feasible <= 1'b1;
                            end
                        end
                        
                        if (feasible) begin
                            best_threshold <= mid;
                            low <= mid + 16'd1;
                        end else begin
                            high <= mid - 16'd1;
                        end
                        
                        cycle_count <= cycle_count + 8'd1;
                        next_state <= BINARY_SEARCH;
                    end
                end

                UPDATE_BEST: begin
                    // Find the best subarray for best_threshold
                    // Recompute prefix sums for best_threshold
                    prefix[0] <= 16'd0;
                    for (i = 1; i < 256; i = i + 1) begin
                        prefix[i] <= prefix[i-1] + (s_reg[i-1] ? 16'd1 : 16'd0) - best_threshold;
                    end
                    
                    // Find the best subarray
                    best_start <= 8'd0;
                    best_len <= 8'd0;
                    integer max_len;
                    integer start_pos;
                    
                    for (i = 0; i < 256; i = i + 1) begin
                        for (j = i + current_k; j < 256; j = j + 1) begin
                            if (prefix[j] - prefix[i] >= 16'd0) begin
                                if (j - i > max_len) begin
                                    max_len = j - i;
                                    start_pos = i;
                                end
                            end
                        end
                    end
                    
                    best_start <= start_pos + 8'd1; // 1-based index
                    best_len <= max_len;
                    next_state <= FINISH;
                end

                FINISH: begin
                    start_idx <= best_start;
                    length <= best_len;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end
endmodule