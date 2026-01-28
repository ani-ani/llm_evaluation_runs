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

    // State machine
    localparam [2:0] IDLE = 3'b000;
    localparam [2:0] COMPUTE_DP = 3'b001;
    localparam [2:0] FINALIZE = 3'b010;
    localparam [2:0] DONE_STATE = 3'b011;
    reg [2:0] state;

    // DP state tracking
    reg [3:0] i, j;
    reg [31:0] dp [0:4][0:4];

    // Computation registers
    reg [31:0] current_pos;
    reg [31:0] left_target;
    reg [31:0] right_target;
    reg [31:0] dist_left;
    reg [31:0] dist_right;
    reg [31:0] candidate1, candidate2;

    // Fixed-point constants
    wire [31:0] W_fp;
    assign W_fp = {W, 16'b0};

    // DP Initialization
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            i <= 0;
            j <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        // Initialize DP table
                        for (int idx = 0; idx <= 4; idx = idx + 1) begin
                            for (int jdx = 0; jdx <= 4; jdx = jdx + 1) begin
                                dp[idx][jdx] <= 32'h7FFFFFFF;
                            end
                        end
                        dp[0][0] <= 0;
                        i <= 0;
                        j <= 0;
                        state <= COMPUTE_DP;
                    end
                end
                
                COMPUTE_DP: begin
                    if (i <= 4 && j <= 4) begin
                        if (i + j < 8) begin
                            current_pos <= {18'b0, pos[i + j]};
                            left_target <= (4 > 1) ? ((i * L) / 3) << 16 : 0;
                            right_target <= (4 > 1) ? ((j * L) / 3) << 16 : 0;
                            
                            if (i > 0) begin
                                if (current_pos >= left_target)
                                    dist_left <= current_pos - left_target;
                                else
                                    dist_left <= left_target - current_pos;
                            end
                            
                            if (j > 0) begin
                                if (current_pos >= right_target)
                                    dist_right <= (current_pos - right_target) + W_fp;
                                else
                                    dist_right <= (right_target - current_pos) + W_fp;
                            end
                            
                            state <= FINALIZE;
                        end else begin
                            state <= DONE_STATE;
                        end
                    end else begin
                        if (i < 4) begin
                            i <= i + 1;
                            j <= j;
                        end else if (j < 4) begin
                            i <= 0;
                            j <= j + 1;
                        end else begin
                            state <= DONE_STATE;
                        end
                    end
                end
                
                FINALIZE: begin
                    if (i > 0) begin
                        candidate1 = dp[i - 1][j] + dist_left;
                        if (candidate1 < dp[i][j])
                            dp[i][j] <= candidate1;
                    end
                    if (j > 0) begin
                        candidate2 = dp[i][j - 1] + dist_right;
                        if (candidate2 < dp[i][j])
                            dp[i][j] <= candidate2;
                    end
                    
                    state <= COMPUTE_DP;
                    
                    if (i < 4) begin
                        i <= i + 1;
                    end else begin
                        i <= 0;
                        j <= j + 1;
                    end
                end
                
                DONE_STATE: begin
                    result <= dp[4][4];
                    done <= 1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule