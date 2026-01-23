module TreePlanner (
    input clk,
    input rst_n,
    input start,
    input [13:0] L,
    input [4:0] W,
    input [13:0] pos [0:7],
    output reg [31:0] result,
    output reg done
);

// State definitions
localparam [2:0] IDLE      = 3'd0;
localparam [2:0] COMPUTE_DP = 3'd1;
localparam [2:0] FINALIZE  = 3'd2;
localparam [2:0] DONE_STATE = 3'd3;

// Parameters
localparam MAX_N = 8;
localparam K = 3'd4; // MAX_N / 2

// FSM registers
reg [2:0] state, next_state;

// DP storage
reg [3:0] i, j;
reg [31:0] dp [0:4][0:4]; // [0..K][0..K]

// Computation signals
reg [31:0] current_pos;
reg [31:0] left_target;
reg [31:0] right_target;
reg [31:0] dist_left;
reg [31:0] dist_right;
reg [31:0] W_fp;

// Loop counters
integer idx, jdx;

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 32'd0;
        i <= 4'd0;
        j <= 4'd0;
        W_fp <= 32'd0;
        
        // Initialize DP array
        for (idx = 0; idx <= K; idx = idx + 1) begin
            for (jdx = 0; jdx <= K; jdx = jdx + 1) begin
                dp[idx][jdx] <= 32'h7FFFFFFF;
            end
        end
        dp[0][0] <= 32'd0;
    end
    else begin
        state <= next_state;
        W_fp <= {W, 16'b0}; // Convert to Q16.16

        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    next_state <= COMPUTE_DP;
                end
            end

            COMPUTE_DP: begin
                if (i < K) begin
                    i <= i + 4'd1;
                end
                else if (j < K) begin
                    i <= 4'd0;
                    j <= j + 4'd1;
                end
                else begin
                    next_state <= DONE_STATE;
                end
                
                if (i + j < MAX_N) begin
                    current_pos <= {pos[i+j], 16'b0};
                    left_target <= (K > 1) ? (i * {L, 16'b0}) / (K-1) : 32'd0;
                    right_target <= (K > 1) ? (j * {L, 16'b0}) / (K-1) : 32'd0;
                    next_state <= FINALIZE;
                end
            end

            FINALIZE: begin
                // Calculate dist_left
                if (current_pos >= left_target) begin
                    dist_left <= current_pos - left_target;
                end
                else begin
                    dist_left <= left_target - current_pos;
                end

                // Calculate dist_right
                if (current_pos >= right_target) begin
                    dist_right <= (current_pos - right_target) + W_fp;
                end
                else begin
                    dist_right <= (right_target - current_pos) + W_fp;
                end

                // Update DP table
                if (i > 0 && dp[i-1][j] + dist_left < dp[i][j]) begin
                    dp[i][j] <= dp[i-1][j] + dist_left;
                end
                if (j > 0 && dp[i][j-1] + dist_right < dp[i][j]) begin
                    dp[i][j] <= dp[i][j-1] + dist_right;
                end

                next_state <= COMPUTE_DP;
            end

            DONE_STATE: begin
                result <= dp[K][K];
                done <= 1'b1;
                next_state <= IDLE;
            end

            default: next_state <= IDLE;
        endcase
    end
end

endmodule