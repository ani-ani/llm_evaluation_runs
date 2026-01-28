module AnthonyGameProbability(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [3:0] M,
    input wire [7:0] p [0:15],
    output reg [15:0] result,
    output reg done
);
    
    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;
    
    // DP table storage (16x16 states)
    reg [15:0] dp [0:15][0:15];
    
    // Current state indices
    reg [3:0] a_idx;
    reg [3:0] m_idx;
    
    // Round index
    reg [3:0] round_idx;
    
    // Temporary computation registers
    reg [15:0] temp_p;
    reg [15:0] term1;
    reg [15:0] term2;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize DP table
            integer i, j;
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    dp[i][j] <= 16'd0;
                end
            end
            
            a_idx <= 4'd0;
            m_idx <= 4'd0;
            round_idx <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    // Set base cases
                    integer i;
                    for (i = 1; i < 16; i = i + 1) begin
                        dp[i][0] <= 16'd256;  // Q8.8 representation of 1.0
                    end
                    
                    integer j;
                    for (j = 1; j < 16; j = j + 1) begin
                        dp[0][j] <= 16'd0;  // Q8.8 representation of 0.0
                    end
                    
                    // Initialize current state
                    a_idx <= N;
                    m_idx <= M;
                    round_idx <= (N + M - 1) - 1;  // Start from last round
                    state <= COMPUTE;
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute current state probability
                    if (a_idx > 0 && m_idx > 0) begin
                        // Get probability for current round
                        temp_p <= {8'd0, p[round_idx]};  // Convert to Q8.8
                        
                        // Compute terms
                        term1 <= temp_p * dp[a_idx][m_idx - 1];
                        term2 <= (16'd256 - temp_p) * dp[a_idx - 1][m_idx];
                        
                        // Store result (shift right by 8 for Q8.8 division)
                        dp[a_idx][m_idx] <= (term1 + term2) >>> 8;
                    end
                    
                    // Move to next state
                    if (a_idx > 0 && m_idx > 0) begin
                        if (m_idx > 1) begin
                            m_idx <= m_idx - 1;
                            round_idx <= round_idx - 1;
                        end else if (a_idx > 1) begin
                            a_idx <= a_idx - 1;
                            m_idx <= M;
                            round_idx <= round_idx - 1;
                        end else begin
                            state <= FINISH;
                        end
                    end else begin
                        state <= FINISH;
                    end
                    
                    // Safety check for max cycles
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    result <= dp[N][M];  // Final probability
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule