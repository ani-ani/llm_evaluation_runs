module nds_turbo (
    input clk,
    input rst_n,
    input start,
    input [7:0] seq_in,
    input [9:0] T_in,
    output reg [31:0] result,
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b000;
    localparam READING = 3'b001;
    localparam CALC_LIS_PREFIX = 3'b010;
    localparam CALC_LIS_TOTAL = 3'b011;
    localparam CALC_LIS_SUFFIX = 3'b100;
    localparam CALC_GAP = 3'b101;
    localparam FINISHED = 3'b110;

    reg [2:0] state, next_state;
    
    // Storage for sequence (N=8)
    reg [7:0] seq [0:7];
    
    // Counters
    reg [3:0] idx; // Loop counter 0-8
    reg [3:0] read_cnt; // 0-7
    
    // Inputs storage
    reg [9:0] T_reg;
    
    // Intermediate Results
    reg [31:0] total_len;
    reg [31:0] left_len;
    reg [31:0] right_len;
    reg [31:0] gap;
    
    // LIS Engine Registers
    reg [7:0] dp [0:7]; // DP table values for current pass
    reg [7:0] current_val; // Value being processed
    reg [31:0] max_len; // Max length found so far in pass
    reg [31:0] current_max_dp; // Current max DP value used for gap logic
    
    // Sequential State Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            idx <= 0;
            read_cnt <= 0;
            T_reg <= 0;
            // Reset DP array
            dp[0] <= 0; dp[1] <= 0; dp[2] <= 0; dp[3] <= 0;
            dp[4] <= 0; dp[5] <= 0; dp[6] <= 0; dp[7] <= 0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        read_cnt <= 0;
                        T_reg <= T_in; // Capture T
                    end
                end

                READING: begin
                    seq[read_cnt] <= seq_in;
                    read_cnt <= read_cnt + 1;
                end

                CALC_LIS_PREFIX: begin
                    // Initialize for prefix pass (only seq[0..7] logic, loop runs N times)
                    if (idx == 0) begin
                        dp[0] <= 1;
                        max_len <= 1;
                        current_val <= seq[0];
                    end else if (idx < 4) begin
                        // LIS Logic: dp[i] = 1 + max(dp[j]) where seq[j] <= seq[i]
                        integer j;
                        reg [31:0] max_prev;
                        max_prev = 0;
                        for (j = 0; j < idx; j = j + 1)
                            if (seq[j] <= seq[idx] && dp[j] > max_prev)
                                max_prev = dp[j];
                        dp[idx] <= max_prev + 1;
                        max_len <= (max_prev + 1 > max_len) ? (max_prev + 1) : max_len;
                    end
                    
                    if (idx < 4) idx <= idx + 1;
                    else begin
                        left_len <= max_len;
                        idx <= 0; // Reset for next pass
                    end
                end

                CALC_LIS_TOTAL: begin
                    // Standard LIS pass on the sequence, re-initializing DP
                    if (idx == 0) begin
                        dp[0] <= 1;
                        max_len <= 1;
                    end else if (idx < 8) begin
                        // Update logic similar to prefix
                        integer j;
                        reg [31:0] max_prev;
                        max_prev = 0;
                        for (j = 0; j < idx; j = j + 1)
                            if (seq[j] <= seq[idx] && dp[j] > max_prev)
                                max_prev = dp[j];
                        dp[idx] <= max_prev + 1;
                        max_len <= (max_prev + 1 > max_len) ? (max_prev + 1) : max_len;
                    end
                    
                    if (idx < 8) idx <= idx + 1;
                    else begin
                        total_len <= max_len;
                        idx <= 0;
                    end
                end

                CALC_LIS_SUFFIX: begin
                    // We need LIS of the suffix. 
                    if (idx == 0) begin
                        dp[0] <= 1; // dp[0] corresponds to seq[7]
                        max_len <= 1;
                    end else if (idx < 4) begin
                        // Logic: process seq[7-idx]
                        integer j;
                        reg [31:0] max_prev;
                        max_prev = 0;
                        for (j = 0; j < idx; j = j + 1)
                            if (seq[7-j] <= seq[7-idx] && dp[j] > max_prev)
                                max_prev = dp[j];
                        dp[idx] <= max_prev + 1;
                        max_len <= (max_prev + 1 > max_len) ? (max_prev + 1) : max_len;
                    end
                    
                    if (idx < 4) idx <= idx + 1;
                    else begin
                        right_len <= max_len;
                        idx <= 0;
                    end
                end

                CALC_GAP: begin
                    // Calculate max_val and min_val of the sequence.
                    if (idx == 0) begin
                        current_max_dp <= seq[0]; // Temp use for max
                        gap <= seq[0]; // Temp use for min
                        idx <= 1;
                    end else if (idx < 8) begin
                        if (seq[idx] > current_max_dp) current_max_dp <= seq[idx];
                        if (seq[idx] < gap) gap <= seq[idx];
                        idx <= idx + 1;
                    end else begin
                        // End of calculation
                        // gap variable holds min_val, current_max_dp holds max_val
                        // gap = 1 if max <= min, else 2.
                        if (current_max_dp <= gap) gap <= 1;
                        else gap <= 2;
                        idx <= 0;
                    end
                end

                FINISHED: begin
                    // Compute Result
                    if (T_reg == 1) begin
                        result <= total_len;
                    end else begin
                        reg [31:0] middle_part;
                        if (total_len > left_len + right_len)
                            middle_part = total_len - left_len - right_len;
                        else
                            middle_part = 0;
                        result <= left_len + right_len + (T_reg - 2) * gap + middle_part;
                    end
                    done <= 1;
                end
            endcase
        end
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? READING : IDLE;
            
            READING: next_state = (read_cnt == 8) ? CALC_LIS_PREFIX : READING;
            
            CALC_LIS_PREFIX: next_state = (idx == 4) ? CALC_LIS_TOTAL : CALC_LIS_PREFIX;
            
            CALC_LIS_TOTAL: next_state = (idx == 8) ? CALC_LIS_SUFFIX : CALC_LIS_TOTAL;
            
            CALC_LIS_SUFFIX: next_state = (idx == 4) ? CALC_GAP : CALC_LIS_SUFFIX;
            
            CALC_GAP: next_state = (idx == 8) ? FINISHED : CALC_GAP;
            
            FINISHED: next_state = IDLE;
            
            default: next_state = IDLE;
        endcase
    end

endmodule