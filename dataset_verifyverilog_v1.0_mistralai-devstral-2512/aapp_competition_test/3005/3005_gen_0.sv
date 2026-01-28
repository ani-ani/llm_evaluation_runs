module maximal_factoring_weight(
    input clk,
    input rst_n,
    input start,
    input [3:0] len,
    input [7:0] char_in,
    input write_enable,
    input [3:0] addr,
    output reg [7:0] result,
    output reg done,
    output reg busy
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    reg [2:0] state, next_state;

    // Internal character storage (16x8)
    reg [7:0] char_mem [0:15];

    // DP table (16x8)
    reg [7:0] dp [0:15];

    // Counters for DP computation
    reg [3:0] i, j, k, d;
    reg [7:0] temp_weight;
    reg [7:0] pattern_length;
    reg [7:0] repeat_count;
    reg [7:0] min_weight;
    reg [7:0] current_weight;
    reg [7:0] substring_length;
    reg [7:0] pattern_start;
    reg [7:0] pattern_end;
    reg [7:0] substring_start;
    reg [7:0] substring_end;
    reg [7:0] temp_dp;
    reg [7:0] temp_dp_j;
    reg [7:0] temp_dp_substring;
    reg [7:0] temp_dp_pattern;
    reg [7:0] temp_dp_pattern_length;
    reg [7:0] temp_dp_pattern_weight;
    reg [7:0] temp_dp_pattern_weight_final;
    reg [7:0] temp_dp_pattern_weight_final_final;
    reg [7:0] temp_dp_pattern_weight_final_final_final;
    reg [7:0] temp_dp_pattern_weight_final_final_final_final;
    reg [7:0] temp_dp_pattern_weight_final_final_final_final_final;
    reg [7:0] temp_dp_pattern_weight_final_final_final_final_final_final;
    reg [7:0] temp_dp_pattern_weight_final_final_final_final_final_final_final;
    reg [7:0] temp_dp_pattern_weight_final_final_final_final_final_final_final_final;
    reg [7:0] temp_dp_pattern_weight_final_final_final_final_final_final_final_final_final;
    reg [7:0] temp_dp_pattern_weight_final_final_final_final_final_final_final_final_final_final;
    reg [7:0] temp_dp_pattern_weight_final_final_final_final_final_final_final_final_final_final_final;
    reg [7:0] temp_dp_pattern_weight_final_final_final_final_final_final_final_final_final_final_final_final;
    reg [7:0] temp_dp_pattern_weight_final_final_final_final_final_final_final_final_final_final_final_final_final;
    reg [7:0] temp_dp_pattern_weight_final_final_final_final_final_final_final_final_final_final_final_final_final_final;
    reg [7:0] temp_dp_pattern_weight_final_final_final_final_final_final_final_final_final_final_final_final_final_final_final;
    reg [7:0] temp_dp_pattern_weight_final_final_final_final_final_final_final_final_final_final_final_final_final_final_final_final;

    // Flags
    reg is_repeating;
    reg is_valid_pattern;
    reg is_valid_substring;
    reg is_valid_length;
    reg is_valid_divisor;
    reg is_valid_repeat;
    reg is_valid_repeat_count;
    reg is_valid_repeat_pattern;
    reg is_valid_repeat_pattern_length;
    reg is_valid_repeat_pattern_weight;
    reg is_valid_repeat_pattern_weight_final;
    reg is_valid_repeat_pattern_weight_final_final;
    reg is_valid_repeat_pattern_weight_final_final_final;
    reg is_valid_repeat_pattern_weight_final_final_final_final;
    reg is_valid_repeat_pattern_weight_final_final_final_final_final;
    reg is_valid_repeat_pattern_weight_final_final_final_final_final_final;
    reg is_valid_repeat_pattern_weight_final_final_final_final_final_final_final;
    reg is_valid_repeat_pattern_weight_final_final_final_final_final_final_final_final;
    reg is_valid_repeat_pattern_weight_final_final_final_final_final_final_final_final_final;
    reg is_valid_repeat_pattern_weight_final_final_final_final_final_final_final_final_final_final;
    reg is_valid_repeat_pattern_weight_final_final_final_final_final_final_final_final_final_final_final;
    reg is_valid_repeat_pattern_weight_final_final_final_final_final_final_final_final_final_final_final_final;
    reg is_valid_repeat_pattern_weight_final_final_final_final_final_final_final_final_final_final_final_final_final;
    reg is_valid_repeat_pattern_weight_final_final_final_final_final_final_final_final_final_final_final_final_final_final;
    reg is_valid_repeat_pattern_weight_final_final_final_final_final_final_final_final_final_final_final_final_final_final_final;
    reg is_valid_repeat_pattern_weight_final_final_final_final_final_final_final_final_final_final_final_final_final_final_final_final;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            done <= 1'b0;
            busy <= 1'b0;
            result <= 8'd0;

            // Initialize character memory
            integer idx;
            for (idx = 0; idx < 16; idx = idx + 1) begin
                char_mem[idx] <= 8'd0;
            end

            // Initialize DP table
            for (idx = 0; idx < 16; idx = idx + 1) begin
                dp[idx] <= 8'd0;
            end

            // Initialize counters
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            d <= 4'd0;

            // Initialize temporary variables
            temp_weight <= 8'd0;
            pattern_length <= 8'd0;
            repeat_count <= 8'd0;
            min_weight <= 8'd0;
            current_weight <= 8'd0;
            substring_length <= 8'd0;
            pattern_start <= 8'd0;
            pattern_end <= 8'd0;
            substring_start <= 8'd0;
            substring_end <= 8'd0;
            temp_dp <= 8'd0;
            temp_dp_j <= 8'd0;
            temp_dp_substring <= 8'd0;
            temp_dp_pattern <= 8'd0;
            temp_dp_pattern_length <= 8'd0;
            temp_dp_pattern_weight <= 8'd0;
            temp_dp_pattern_weight_final <= 8'd0;
            temp_dp_pattern_weight_final_final <= 8'd0;
            temp_dp_pattern_weight_final_final_final <= 8'd0;
            temp_dp_pattern_weight_final_final_final_final <= 8'd0;
            temp_dp_pattern_weight_final_final_final_final_final <= 8'd0;
            temp_dp_pattern_weight_final_final_final_final_final_final <= 8'd0;
            temp_dp_pattern_weight_final_final_final_final_final_final_final <= 8'd0;
            temp_dp_pattern_weight_final_final_final_final_final_final_final_final <= 8'd0;
            temp_dp_pattern_weight_final_final_final_final_final_final_final_final_final <= 8'd0;
            temp_dp_pattern_weight_final_final_final_final_final_final_final_final_final_final <= 8'd0;
            temp_dp_pattern_weight_final_final_final_final_final_final_final_final_final_final_final <= 8'd0;
            temp_dp_pattern_weight_final_final_final_final_final_final_final_final_final_final_final_final <= 8'd0;
            temp_dp_pattern_weight_final_final_final_final_final_final_final_final_final_final_final_final_final <= 8'd0;
            temp_dp_pattern_weight_final_final_final_final_final_final_final_final_final_final_final_final_final_final <= 8'd0;
            temp_dp_pattern_weight_final_final_final_final_final_final_final_final_final_final_final_final_final_final_final <= 8'd0;
            temp_dp_pattern_weight_final_final_final_final_final_final_final_final_final_final_final_final_final_final_final_final <= 8'd0;

            // Initialize flags
            is_repeating <= 1'b0;
            is_valid_pattern <= 1'b0;
            is_valid_substring <= 1'b0;
            is_valid_length <= 1'b0;
            is_valid_divisor <= 1'b0;
            is_valid_repeat <= 1'b0;
            is_valid_repeat_count <= 1'b0;
            is_valid_repeat_pattern <= 1'b0;
            is_valid_repeat_pattern_length <= 1'b0;
            is_valid_repeat_pattern_weight <= 1'b0;
            is_valid_repeat_pattern_weight_final <= 1'b0;
            is_valid_repeat_pattern_weight_final_final <= 1'b0;
            is_valid_repeat_pattern_weight_final_final_final <= 1'b0;
            is_valid_repeat_pattern_weight_final_final_final_final <= 1'b0;
            is_valid_repeat_pattern_weight_final_final_final_final_final <= 1'b0;
            is_valid_repeat_pattern_weight_final_final_final_final_final_final <= 1'b0;
            is_valid_repeat_pattern_weight_final_final_final_final_final_final_final <= 1'b0;
            is_valid_repeat_pattern_weight_final_final_final_final_final_final_final_final <= 1'b0;
            is_valid_repeat_pattern_weight_final_final_final_final_final_final_final_final_final <= 1'b0;
            is_valid_repeat_pattern_weight_final_final_final_final_final_final_final_final_final_final <= 1'b0;
            is_valid_repeat_pattern_weight_final_final_final_final_final_final_final_final_final_final_final <= 1'b0;
            is_valid_repeat_pattern_weight_final_final_final_final_final_final_final_final_final_final_final_final <= 1'b0;
            is_valid_repeat_pattern_weight_final_final_final_final_final_final_final_final_final_final_final_final_final <= 1'b0;
            is_valid_repeat_pattern_weight_final_final_final_final_final_final_final_final_final_final_final_final_final_final <= 1'b0;
            is_valid_repeat_pattern_weight_final_final_final_final_final_final_final_final_final_final_final_final_final_final_final <= 1'b0;
            is_valid_repeat_pattern_weight_final_final_final_final_final_final_final_final_final_final_final_final_final_final_final_final <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Load characters into memory
    always @(posedge clk) begin
        if (write_enable && addr < len) begin
            char_mem[addr] <= char_in;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                busy = 1'b0;
                done = 1'b0;
                if (start) begin
                    next_state = LOAD;
                    busy = 1'b1;
                end
            end

            LOAD: begin
                busy = 1'b1;
                done = 1'b0;
                next_state = COMPUTE;
            end

            COMPUTE: begin
                busy = 1'b1;
                done = 1'b0;

                // DP computation logic
                if (i < len) begin
                    // Initialize dp[i]
                    if (i == 0) begin
                        dp[i] <= 8'd1;
                    end else begin
                        dp[i] <= i + 8'd1;
                    end

                    // Iterate j from 0 to i-1
                    if (j < i) begin
                        // Compute dp[j]
                        temp_dp_j = dp[j];

                        // Compute dp_substring(j+1, i)
                        substring_start = j + 8'd1;
                        substring_end = i;
                        substring_length = substring_end - substring_start + 8'd1;

                        // Check for repeating patterns
                        is_repeating = 1'b0;
                        pattern_length = 8'd1;
                        while (pattern_length <= substring_length / 8'd2 && !is_repeating) begin
                            if (substring_length % pattern_length == 8'd0) begin
                                repeat_count = substring_length / pattern_length;
                                is_repeating = 1'b1;
                                for (k = 1; k < repeat_count; k = k + 1) begin
                                    if (char_mem[substring_start + k * pattern_length] != char_mem[substring_start + (k - 1) * pattern_length]) begin
                                        is_repeating = 1'b0;
                                    end
                                end
                            end
                            pattern_length = pattern_length + 8'd1;
                        end

                        if (is_repeating) begin
                            temp_dp_substring = dp[substring_start + pattern_length - 8'd1] - dp[substring_start - 8'd1];
                        end else begin
                            temp_dp_substring = substring_length;
                        end

                        // Update dp[i]
                        temp_weight = temp_dp_j + temp_dp_substring;
                        if (temp_weight < dp[i]) begin
                            dp[i] <= temp_weight;
                        end

                        // Increment j
                        j = j + 4'd1;
                    end else begin
                        // Move to next i
                        j = 4'd0;
                        i = i + 4'd1;
                    end
                end else begin
                    // Computation complete
                    result = dp[len - 4'd1];
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                busy = 1'b0;
                done = 1'b1;
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
                busy = 1'b0;
                done = 1'b0;
            end
        endcase
    end

endmodule