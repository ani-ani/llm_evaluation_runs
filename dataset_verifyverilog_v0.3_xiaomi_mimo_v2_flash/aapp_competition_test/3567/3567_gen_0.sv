module CharacterCreation #(
    parameter K = 4,              // Number of features (up to 20)
    parameter N = 8               // Maximum number of players (up to 8)
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [K-1:0] str0,
    input wire [K-1:0] str1,
    input wire [K-1:0] str2,
    input wire [K-1:0] str3,
    input wire [K-1:0] str4,
    input wire [K-1:0] str5,
    input wire [K-1:0] str6,
    input wire [K-1:0] str7,
    input wire [3:0] n,          // Number of valid strings (1-8)
    output reg [K-1:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] LOOP_INNER = 3'd2;
    localparam [2:0] COMPARE = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;
    
    reg [2:0] state, next_state;
    
    // Registers for candidate and best result
    reg [K-1:0] candidate;
    reg [K-1:0] best_candidate;
    reg [7:0] min_dist;          // Current minimum distance for candidate
    reg [7:0] best_min_dist;     // Best minimum distance found so far
    
    // Counters
    reg [7:0] candidate_counter;  // 2^K - 1 iterations (0 to 2^K-1)
    reg [3:0] string_counter;     // Loop over n strings
    reg [3:0] popcount_temp;      // Temporary for Hamming distance
    
    // Maximum iterations
    localparam [7:0] MAX_ITER = 2**K - 1;  // Since we start from 1
    
    // Input strings array (unpacked for storage)
    reg [K-1:0] input_strs [0:7];
    
    // Combinational popcount function
    function automatic [3:0] popcount;
        input [K-1:0] val;
        integer i;
        begin
            popcount = 4'd0;
            for (i = 0; i < K; i = i + 1) begin
                if (val[i]) begin
                    popcount = popcount + 4'd1;
                end
            end
        end
    endfunction
    
    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= {K{1'b0}};
            done <= 1'b0;
            candidate <= {K{1'b0}};
            best_candidate <= {K{1'b0}};
            min_dist <= 8'd0;
            best_min_dist <= 8'd0;
            candidate_counter <= 8'd0;
            string_counter <= 4'd0;
            popcount_temp <= 4'd0;
            // Initialize input strings array
            input_strs[0] <= {K{1'b0}};
            input_strs[1] <= {K{1'b0}};
            input_strs[2] <= {K{1'b0}};
            input_strs[3] <= {K{1'b0}};
            input_strs[4] <= {K{1'b0}};
            input_strs[5] <= {K{1'b0}};
            input_strs[6] <= {K{1'b0}};
            input_strs[7] <= {K{1'b0}};
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    candidate_counter <= 8'd0;
                    string_counter <= 4'd0;
                    min_dist <= 8'd0;
                    best_min_dist <= 8'd0;
                    result <= {K{1'b0}};
                    best_candidate <= {K{1'b0}};
                end
                INIT: begin
                    // Load input strings into array
                    input_strs[0] <= str0;
                    input_strs[1] <= str1;
                    input_strs[2] <= str2;
                    input_strs[3] <= str3;
                    input_strs[4] <= str4;
                    input_strs[5] <= str5;
                    input_strs[6] <= str6;
                    input_strs[7] <= str7;
                    // Initialize candidate counter
                    candidate_counter <= 8'd1;  // Start from 1, skip 0
                    candidate <= {K{1'b0}};
                    best_min_dist <= 8'd0;
                    best_candidate <= {K{1'b0}};
                end
                LOOP_INNER: begin
                    // Set up candidate for current iteration
                    candidate <= candidate[K-1:0];
                    // Reset min_dist for new candidate
                    min_dist <= 8'd255;  // Initialize with max possible
                    string_counter <= 4'd0;
                end
                COMPARE: begin
                    // Calculate Hamming distance for current string
                    if (string_counter < n) begin
                        popcount_temp <= popcount(candidate ^ input_strs[string_counter]);
                        // Update minimum distance
                        if (popcount_temp < min_dist) begin
                            min_dist <= popcount_temp;
                        end
                        // Check if this is the best candidate so far
                        if (min_dist > best_min_dist) begin
                            best_min_dist <= min_dist;
                            best_candidate <= candidate;
                        end
                    end
                    // Increment counters
                    string_counter <= string_counter + 4'd1;
                    // Update candidate for next iteration
                    if (string_counter == n) begin
                        // Move to next candidate
                        candidate_counter <= candidate_counter + 8'd1;
                        candidate <= candidate_counter + 8'd1;
                    end
                end
                DONE_STATE: begin
                    result <= best_candidate;
                    done <= 1'b1;
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;  // Default: stay in current state
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end
            INIT: begin
                next_state = LOOP_INNER;
            end
            LOOP_INNER: begin
                next_state = COMPARE;
            end
            COMPARE: begin
                if (string_counter < n) begin
                    // Still processing strings for this candidate
                    next_state = COMPARE;
                end else if (candidate_counter <= MAX_ITER) begin
                    // Move to next candidate
                    next_state = LOOP_INNER;
                end else begin
                    // All candidates processed
                    next_state = DONE_STATE;
                end
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule