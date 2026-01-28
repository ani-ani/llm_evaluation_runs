module FruitArrangementCounter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] A_in,
    input wire [4:0] C_in,
    input wire [4:0] M_in,
    output reg [31:0] result,
    output reg done,
    output reg error
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [4:0] MAX_COUNT = 5'd20;

    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] VALIDATE = 3'd1;
    localparam [2:0] INIT_DP = 3'd2;
    localparam [2:0] COMPUTE = 3'd3;
    localparam [2:0] SUM_RESULTS = 3'd4;
    localparam [2:0] OUTPUT = 3'd5;

    // State machine
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // DP table: dp[a][c][m][prev]
    reg [31:0] dp [0:20][0:20][0:20][0:2];

    // Loop counters
    reg [4:0] a, c, m, prev;
    reg [4:0] a_next, c_next, m_next;

    // Intermediate values
    reg [31:0] temp_sum;
    reg [31:0] temp_val;

    // Input validation
    reg valid_input;

    // Modulo addition function
    function [31:0] mod_add;
        input [31:0] a, b;
        begin
            mod_add = a + b;
            if (mod_add >= MOD) begin
                mod_add = mod_add - MOD;
            end
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            error <= 1'b0;
            cycle_count <= 8'd0;
            valid_input <= 1'b0;
            temp_sum <= 32'd0;
            a <= 5'd0;
            c <= 5'd0;
            m <= 5'd0;
            prev <= 2'd0;
            a_next <= 5'd0;
            c_next <= 5'd0;
            m_next <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= VALIDATE;
                    end
                end

                VALIDATE: begin
                    // Check if inputs are valid
                    if (A_in > MAX_COUNT || C_in > MAX_COUNT || M_in > MAX_COUNT || 
                        (A_in + C_in + M_in) > MAX_COUNT) begin
                        error <= 1'b1;
                        state <= IDLE;
                    end else begin
                        valid_input <= 1'b1;
                        state <= INIT_DP;
                    end
                end

                INIT_DP: begin
                    // Initialize DP table to 0
                    integer i, j, k, p;
                    for (i = 0; i <= 20; i = i + 1) begin
                        for (j = 0; j <= 20; j = j + 1) begin
                            for (k = 0; k <= 20; k = k + 1) begin
                                for (p = 0; p <= 2; p = p + 1) begin
                                    dp[i][j][k][p] <= 32'd0;
                                end
                            end
                        end
                    end

                    // Set base cases
                    if (A_in >= 1) begin
                        dp[1][0][0][0] <= 32'd1;
                    end
                    if (C_in >= 1) begin
                        dp[0][1][0][1] <= 32'd1;
                    end
                    if (M_in >= 1) begin
                        dp[0][0][1][2] <= 32'd1;
                    end

                    // Initialize loop counters
                    a <= 5'd0;
                    c <= 5'd0;
                    m <= 5'd0;
                    prev <= 2'd0;
                    state <= COMPUTE;
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute next state transitions
                    if (prev != 2'd0 && a < A_in) begin
                        a_next = a + 5'd1;
                        dp[a_next][c][m][0] <= mod_add(dp[a_next][c][m][0], dp[a][c][m][prev]);
                    end
                    if (prev != 2'd1 && c < C_in) begin
                        c_next = c + 5'd1;
                        dp[a][c_next][m][1] <= mod_add(dp[a][c_next][m][1], dp[a][c][m][prev]);
                    end
                    if (prev != 2'd2 && m < M_in) begin
                        m_next = m + 5'd1;
                        dp[a][c][m_next][2] <= mod_add(dp[a][c][m_next][2], dp[a][c][m][prev]);
                    end

                    // Update loop counters
                    if (prev == 2'd2) begin
                        if (m == M_in) begin
                            if (c == C_in) begin
                                if (a == A_in) begin
                                    state <= SUM_RESULTS;
                                end else begin
                                    a <= a + 5'd1;
                                    c <= 5'd0;
                                    m <= 5'd0;
                                    prev <= 2'd0;
                                end
                            end else begin
                                c <= c + 5'd1;
                                m <= 5'd0;
                                prev <= 2'd0;
                            end
                        end else begin
                            m <= m + 5'd1;
                            prev <= 2'd0;
                        end
                    end else begin
                        prev <= prev + 2'd1;
                    end

                    // Safety check for max cycles
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= IDLE;
                    end
                end

                SUM_RESULTS: begin
                    // Sum all final states
                    temp_sum <= 32'd0;
                    if (A_in > 0) begin
                        temp_sum <= mod_add(temp_sum, dp[A_in][C_in][M_in][0]);
                    end
                    if (C_in > 0) begin
                        temp_sum <= mod_add(temp_sum, dp[A_in][C_in][M_in][1]);
                    end
                    if (M_in > 0) begin
                        temp_sum <= mod_add(temp_sum, dp[A_in][C_in][M_in][2]);
                    end
                    result <= temp_sum;
                    state <= OUTPUT;
                end

                OUTPUT: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule