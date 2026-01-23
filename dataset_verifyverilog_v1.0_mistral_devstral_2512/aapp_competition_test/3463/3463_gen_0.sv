module AnthonyCoraGame(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [3:0] M,
    input wire [31:0] p_in,
    input wire p_valid,
    output reg [31:0] result,
    output reg done,
    output reg error
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] LOAD    = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] FINISH  = 2'd3;
    
    // DP table dimensions (max 16x16)
    localparam [3:0] MAX_N = 4'd16;
    localparam [3:0] MAX_M = 4'd16;
    localparam [4:0] MAX_ROUNDS = 5'd31;
    localparam [9:0] MAX_CYCLES = 10'd1000;

    // State machine
    reg [1:0] state, next_state;
    reg [9:0] cycle_count;
    reg [4:0] round_count;
    reg [3:0] i, j;
    reg [31:0] p;
    reg p_loaded;

    // DP table (16x16)
    reg signed [31:0] dp [0:15];
    integer k;

    // Check N and M range
    wire n_valid = (N >= 4'd1) && (N <= 4'd16);
    wire m_valid = (M >= 4'd1) && (M <= 4'd16);

    // State transitions
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    if (n_valid && m_valid && p_valid) begin
                        next_state = LOAD;
                    end else begin
                        next_state = FINISH;
                    end
                end else begin
                    next_state = IDLE;
                end
            end
            
            LOAD: begin
                if (p_loaded) begin
                    next_state = COMPUTE;
                end else begin
                    next_state = LOAD;
                end
            end
            
            COMPUTE: begin
                if (round_count >= (N + M - 1)) begin
                    next_state = FINISH;
                end else begin
                    next_state = COMPUTE;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 10'd0;
            round_count <= 5'd0;
            i <= 4'd0;
            j <= 4'd0;
            p <= 32'd0;
            p_loaded <= 1'b0;
            result <= 32'd0;
            done <= 1'b0;
            error <= 1'b0;
            
            // Initialize DP table
            for (k = 0; k < 16; k = k + 1) begin
                dp[k] <= 32'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    cycle_count <= 10'd0;
                    round_count <= 5'd0;
                    i <= 4'd0;
                    j <= 4'd0;
                end
                
                LOAD: begin
                    if (p_valid) begin
                        p <= p_in;
                        p_loaded <= 1'b1;
                        
                        // Initialize base cases
                        dp[0] <= 32'd0;  // dp[0][0]
                        for (k = 1; k < 16; k = k + 1) begin
                            dp[k] <= 32'd0;  // dp[0][j] = 0
                        end
                        
                        for (k = 1; k < 16; k = k + 1) begin
                            dp[k] <= 32'd65536;  // dp[i][0] = 1.0
                        end
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 10'd1;
                    
                    // Compute dp[i][j] = p*dp[i][j-1] + (1-p)*dp[i-1][j]
                    if (i > 4'd0 && j > 4'd0 && i <= N && j <= M) begin
                        // Fixed-point multiplication
                        reg signed [63:0] temp1, temp2;
                        temp1 = $signed(p) * $signed(dp[j-1]);
                        temp2 = $signed(32'd65536 - p) * $signed(dp[i-1]);
                        
                        // Sum and shift
                        dp[j] <= (temp1[47:16] + temp2[47:16]);
                        
                        // Move to next cell
                        if (j == M) begin
                            i <= i + 4'd1;
                            j <= 4'd1;
                            round_count <= round_count + 5'd1;
                        end else begin
                            j <= j + 4'd1;
                        end
                    end else if (i == 4'd0 && j == 4'd0) begin
                        i <= 4'd1;
                        j <= 4'd1;
                    end
                    
                    // Timeout check
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                        error <= 1'b1;
                    end
                end
                
                FINISH: begin
                    if (n_valid && m_valid) begin
                        result <= dp[M];
                        done <= 1'b1;
                    end else begin
                        error <= 1'b1;
                    end
                    
                    // Reset for next operation
                    p_loaded <= 1'b0;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    error <= 1'b0;
                end
            endcase
        end
    end
endmodule