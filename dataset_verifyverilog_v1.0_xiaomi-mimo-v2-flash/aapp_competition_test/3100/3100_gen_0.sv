module CountArrangements(
    input clk,
    input rst_n,
    input start,
    input [4:0] A_in,
    input [4:0] C_in,
    input [4:0] M_in,
    output reg [31:0] result,
    output reg done,
    output reg error
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [4:0] MAX_VAL = 5'd20;
    
    // State definitions
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] VALIDATE    = 4'd1;
    localparam [3:0] INIT_DP     = 4'd2;
    localparam [3:0] BASE_CASES  = 4'd3;
    localparam [3:0] DP_LOOP_A   = 4'd4;
    localparam [3:0] DP_LOOP_C   = 4'd5;
    localparam [3:0] DP_LOOP_M   = 4'd6;
    localparam [3:0] DP_LOOP_PREV= 4'd7;
    localparam [3:0] DP_TRANSITION= 4'd8;
    localparam [3:0] SUM_RESULT  = 4'd9;
    localparam [3:0] FINISH      = 4'd10;
    
    // Internal registers
    reg [3:0] state, next_state;
    reg [4:0] A_reg, C_reg, M_reg;
    reg [4:0] a_idx, c_idx, m_idx;
    reg [1:0] prev_idx;
    reg [31:0] dp_reg;
    reg [31:0] temp_sum;
    reg [31:0] cycle_count;
    localparam [31:0] MAX_CYCLES = 32'd1000;
    
    // DP Memory: dp[21][21][21][3] - packed as 21*21*21*3 = 27,783 entries
    // Address: {a_idx, c_idx, m_idx, prev_idx}
    // Each entry is 32-bit
    reg [31:0] dp_mem [0:27782];
    integer i;
    
    // Address calculation
    wire [14:0] addr;
    assign addr = m_idx * 1323 + c_idx * 63 + a_idx * 3 + prev_idx;
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = VALIDATE;
            end
            VALIDATE: begin
                if (error) next_state = FINISH;
                else next_state = INIT_DP;
            end
            INIT_DP: begin
                next_state = BASE_CASES;
            end
            BASE_CASES: begin
                next_state = DP_LOOP_A;
            end
            DP_LOOP_A: begin
                if (a_idx > A_reg) next_state = SUM_RESULT;
                else next_state = DP_LOOP_C;
            end
            DP_LOOP_C: begin
                if (c_idx > C_reg) next_state = DP_LOOP_A;
                else next_state = DP_LOOP_M;
            end
            DP_LOOP_M: begin
                if (m_idx > M_reg) next_state = DP_LOOP_C;
                else next_state = DP_LOOP_PREV;
            end
            DP_LOOP_PREV: begin
                if (prev_idx == 2'd2) next_state = DP_TRANSITION;
                else next_state = DP_LOOP_PREV;
            end
            DP_TRANSITION: begin
                next_state = DP_LOOP_M;
            end
            SUM_RESULT: begin
                next_state = FINISH;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            error <= 1'b0;
            A_reg <= 5'd0;
            C_reg <= 5'd0;
            M_reg <= 5'd0;
            a_idx <= 5'd0;
            c_idx <= 5'd0;
            m_idx <= 5'd0;
            prev_idx <= 2'd0;
            cycle_count <= 32'd0;
            // Initialize dp_mem to 0
            for (i = 0; i < 27783; i = i + 1) begin
                dp_mem[i] <= 32'd0;
            end
        end else begin
            state <= next_state;
            done <= 1'b0;
            cycle_count <= cycle_count + 32'd1;
            
            case (state)
                IDLE: begin
                    cycle_count <= 32'd0;
                    if (start) begin
                        A_reg <= A_in;
                        C_reg <= C_in;
                        M_reg <= M_in;
                    end
                end
                
                VALIDATE: begin
                    // Check if any input > 20 or total > 20
                    if (A_in > MAX_VAL || C_in > MAX_VAL || M_in > MAX_VAL || 
                        (A_in + C_in + M_in) > MAX_VAL) begin
                        error <= 1'b1;
                    end else begin
                        error <= 1'b0;
                    end
                end
                
                INIT_DP: begin
                    // Clear DP memory (already done in reset, re-clear for next use)
                    for (i = 0; i < 27783; i = i + 1) begin
                        dp_mem[i] <= 32'd0;
                    end
                end
                
                BASE_CASES: begin
                    // Set base cases
                    // dp[1][0][0][0] = 1
                    dp_mem[3] <= 32'd1;  // a=1, c=0, m=0, prev=0: addr = 0*1323 + 0*63 + 1*3 + 0 = 3
                    // dp[0][1][0][1] = 1
                    dp_mem[64] <= 32'd1; // a=0, c=1, m=0, prev=1: addr = 0*1323 + 1*63 + 0*3 + 1 = 64
                    // dp[0][0][1][2] = 1
                    dp_mem[125] <= 32'd1; // a=0, c=0, m=1, prev=2: addr = 1*1323 + 0*63 + 0*3 + 2 = 1325... wait
                    // m=1, c=0, a=0, prev=2: addr = 1*1323 + 0*63 + 0*3 + 2 = 1323 + 2 = 1325
                    // Actually: m*1323 + c*63 + a*3 + prev
                    // For m=1, c=0, a=0, prev=2: 1*1323 + 0*63 + 0*3 + 2 = 1323 + 2 = 1325
                    dp_mem[1325] <= 32'd1;
                    a_idx <= 5'd0;
                    c_idx <= 5'd0;
                    m_idx <= 5'd0;
                    prev_idx <= 2'd0;
                end
                
                DP_LOOP_A: begin
                    a_idx <= a_idx + 5'd1;
                    c_idx <= 5'd0;
                    m_idx <= 5'd0;
                    prev_idx <= 2'd0;
                end
                
                DP_LOOP_C: begin
                    c_idx <= c_idx + 5'd1;
                    m_idx <= 5'd0;
                    prev_idx <= 2'd0;
                end
                
                DP_LOOP_M: begin
                    m_idx <= m_idx + 5'd1;
                    prev_idx <= 2'd0;
                end
                
                DP_LOOP_PREV: begin
                    prev_idx <= prev_idx + 2'd1;
                    dp_reg <= dp_mem[addr];
                end
                
                DP_TRANSITION: begin
                    // Only process if current state has non-zero value
                    if (dp_reg != 32'd0) begin
                        // Try adding apple (prev != 0 and a_idx < A_reg)
                        if (prev_idx != 2'd0 && a_idx < A_reg) begin
                            // dp[a+1][c][m][0] += dp[a][c][m][prev]
                            dp_mem[(a_idx + 5'd1) * 3 + 2'd0 + m_idx * 1323 + c_idx * 63] <= 
                                (dp_mem[(a_idx + 5'd1) * 3 + 2'd0 + m_idx * 1323 + c_idx * 63] + dp_reg) % MOD;
                        end
                        // Try adding cherry (prev != 1 and c_idx < C_reg)
                        if (prev_idx != 2'd1 && c_idx < C_reg) begin
                            // dp[a][c+1][m][1] += dp[a][c][m][prev]
                            dp_mem[a_idx * 3 + 2'd1 + m_idx * 1323 + (c_idx + 5'd1) * 63] <= 
                                (dp_mem[a_idx * 3 + 2'd1 + m_idx * 1323 + (c_idx + 5'd1) * 63] + dp_reg) % MOD;
                        end
                        // Try adding mango (prev != 2 and m_idx < M_reg)
                        if (prev_idx != 2'd2 && m_idx < M_reg) begin
                            // dp[a][c][m+1][2] += dp[a][c][m][prev]
                            dp_mem[a_idx * 3 + 2'd2 + (m_idx + 5'd1) * 1323 + c_idx * 63] <= 
                                (dp_mem[a_idx * 3 + 2'd2 + (m_idx + 5'd1) * 1323 + c_idx * 63] + dp_reg) % MOD;
                        end
                    end
                end
                
                SUM_RESULT: begin
                    // Sum dp[A][C][M][0], dp[A][C][M][1], dp[A][C][M][2]
                    temp_sum <= dp_reg;
                    // Load next values
                    a_idx <= A_reg;
                    c_idx <= C_reg;
                    m_idx <= M_reg;
                    prev_idx <= 2'd1;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    result <= temp_sum;
                    a_idx <= 5'd0;
                    c_idx <= 5'd0;
                    m_idx <= 5'd0;
                    prev_idx <= 2'd0;
                end
            endcase
            
            // Handle overflow during DP transition (modulo)
            if (state == DP_LOOP_M && next_state == DP_TRANSITION) begin
                // Store current dp value for transition
                dp_reg <= dp_mem[addr];
            end
            
            // Continue summing in SUM_RESULT state
            if (state == SUM_RESULT) begin
                if (prev_idx == 2'd0) begin
                    temp_sum <= dp_reg;
                    prev_idx <= 2'd1;
                end else if (prev_idx == 2'd1) begin
                    temp_sum <= (temp_sum + dp_reg) % MOD;
                    prev_idx <= 2'd2;
                end else if (prev_idx == 2'd2) begin
                    temp_sum <= (temp_sum + dp_reg) % MOD;
                end
            end
        end
    end

endmodule