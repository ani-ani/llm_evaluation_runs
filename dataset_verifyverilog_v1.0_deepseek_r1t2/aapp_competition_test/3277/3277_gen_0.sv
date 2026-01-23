module smooth_array(
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [3:0] K,
    input [4:0] S,
    input [7:0] A0,
    input [7:0] A1,
    input [7:0] A2,
    input [7:0] A3,
    input [7:0] A4,
    input [7:0] A5,
    input [7:0] A6,
    input [7:0] A7,
    input [7:0] A8,
    input [7:0] A9,
    input [7:0] A10,
    input [7:0] A11,
    input [7:0] A12,
    input [7:0] A13,
    input [7:0] A14,
    input [7:0] A15,
    output reg [4:0] result,
    output reg done
);

// State definitions
localparam [2:0] IDLE       = 3'd0;
localparam [2:0] LOAD       = 3'd1;
localparam [2:0] COUNT_FREQ = 3'd2;
localparam [2:0] DP_INIT    = 3'd3;
localparam [2:0] DP_ITER    = 3'd4;
localparam [2:0] DONE_STATE = 3'd5;

// Internal registers
reg [2:0] state, next_state;
reg [7:0] captured_A [0:15];
reg [7:0] freq [0:15][0:16];  // K_max=16, S_max=16
reg [7:0] curr_max;
reg [7:0] max_profit;
reg [7:0] dp [0:16];          // Current DP array
reg [7:0] new_dp [0:16];      // Next DP array

// Indices and counters
reg [3:0] residue_idx;        // 0..K-1
reg [3:0] elem_idx;           // 0..N-1
reg [4:0] val_idx;            // 0..S
reg [4:0] curr_sum;           // 0..S
reg [4:0] s_prime;            // temp for DP

// Control flags
reg freq_count_done;
reg dp_init_done;
reg dp_iter_done;

// Cycle counters for safety
reg [7:0] cycle_count;
localparam [7:0] MAX_CYCLES = 8'd200;

integer i, j; // Loop variables

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all registers
        state <= IDLE;
        result <= 5'd0;
        done <= 1'b0;
        cycle_count <= 8'd0;
        residue_idx <= 4'd0;
        elem_idx <= 4'd0;
        val_idx <= 5'd0;
        curr_sum <= 5'd0;
        s_prime <= 5'd0;
        freq_count_done <= 1'b0;
        dp_init_done <= 1'b0;
        dp_iter_done <= 1'b0;
        max_profit <= 8'd0;
        curr_max <= 8'd0;
        
        // Initialize arrays with for-loops
        for (i = 0; i < 16; i = i + 1) begin
            captured_A[i] <= 8'd0;
            for (j = 0; j <= 16; j = j + 1) begin
                freq[i][j] <= 8'd0;
            end
        end
        
        for (i = 0; i <= 16; i = i + 1) begin
            dp[i] <= 8'd0;
            new_dp[i] <= 8'd0;
        end
        
    end else begin
        cycle_count <= cycle_count + 8'd1;
        state <= next_state;
        
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    // Load A0-A15 into captured_A
                    captured_A[0] <= A0;
                    captured_A[1] <= A1;
                    captured_A[2] <= A2;
                    captured_A[3] <= A3;
                    captured_A[4] <= A4;
                    captured_A[5] <= A5;
                    captured_A[6] <= A6;
                    captured_A[7] <= A7;
                    captured_A[8] <= A8;
                    captured_A[9] <= A9;
                    captured_A[10] <= A10;
                    captured_A[11] <= A11;
                    captured_A[12] <= A12;
                    captured_A[13] <= A13;
                    captured_A[14] <= A14;
                    captured_A[15] <= A15;
                    next_state <= LOAD;
                end else begin
                    next_state <= IDLE;
                end
            end
            
            LOAD: begin
                // Initialize frequency counters to zero
                for (i = 0; i < 16; i = i + 1) begin
                    for (j = 0; j <= 16; j = j + 1) begin
                        freq[i][j] <= 8'd0;
                    end
                end
                residue_idx <= 4'd0;
                elem_idx <= 4'd0;
                freq_count_done <= 1'b0;
                next_state <= COUNT_FREQ;
            end
            
            COUNT_FREQ: begin
                if (elem_idx < N) begin
                    if ((elem_idx % K) == residue_idx) begin
                        if (captured_A[elem_idx] <= S) begin
                            freq[residue_idx][captured_A[elem_idx]] <= 
                                freq[residue_idx][captured_A[elem_idx]] + 8'd1;
                        end
                    end
                    elem_idx <= elem_idx + 4'd1;
                end else begin
                    residue_idx <= residue_idx + 4'd1;
                    elem_idx <= 4'd0;
                    if (residue_idx == (K - 4'd1)) begin
                        freq_count_done <= 1'b1;
                    end
                end
                
                if (freq_count_done) begin
                    next_state <= DP_INIT;
                end else if (cycle_count >= MAX_CYCLES) begin
                    next_state <= IDLE;
                end else begin
                    next_state <= COUNT_FREQ;
                end
            end
            
            DP_INIT: begin
                // Initialize DP: dp[0] = 0, others = 0
                dp[0] <= 8'd0;
                for (i = 1; i <= 16; i = i + 1) begin
                    dp[i] <= 8'd0;
                end
                residue_idx <= 4'd0;
                dp_init_done <= 1'b1;
                next_state <= DP_ITER;
            end
            
            DP_ITER: begin
                if (residue_idx < K) begin
                    if (curr_sum <= S) begin
                        curr_max <= 8'd0;
                        if (val_idx <= S) begin
                            s_prime <= curr_sum - val_idx;
                            if (s_prime <= S && s_prime >= 0) begin
                                if (dp[s_prime] + freq[residue_idx][val_idx] > curr_max) begin
                                    curr_max <= dp[s_prime] + freq[residue_idx][val_idx];
                                end
                            end
                            val_idx <= val_idx + 5'd1;
                        end else begin
                            new_dp[curr_sum] <= curr_max;
                            val_idx <= 5'd0;
                            curr_sum <= curr_sum + 5'd1;
                        end
                    end else begin
                        // Move to next residue
                        for (i = 0; i <= 16; i = i + 1) begin
                            dp[i] <= new_dp[i];
                            new_dp[i] <= 8'd0;
                        end
                        curr_sum <= 5'd0;
                        residue_idx <= residue_idx + 4'd1;
                    end
                    next_state <= DP_ITER;
                end else begin
                    dp_iter_done <= 1'b1;
                end
                
                if (dp_iter_done) begin
                    max_profit <= dp[S];
                    next_state <= DONE_STATE;
                end else if (cycle_count >= MAX_CYCLES) begin
                    next_state <= IDLE;
                end else begin
                    next_state <= DP_ITER;
                end
            end
            
            DONE_STATE: begin
                result <= N - max_profit[4:0];
                done <= 1'b1;
                next_state <= IDLE;
            end
            
            default: next_state <= IDLE;
        endcase
    end
end

endmodule