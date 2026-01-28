module AnthonyCoraProbability(
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
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT_DP   = 3'd1;
    localparam [2:0] COMPUTE   = 3'd2;
    localparam [2:0] CALCULATE = 3'd3;
    localparam [2:0] FINISH    = 3'd4;
    localparam [2:0] WAIT      = 3'd5;
    
    reg [2:0] state;
    reg [4:0] cycle_count; // 0-256 for 256 cycles
    localparam [4:0] MAX_CYCLES = 5'd31; // 32 cycles for N+M up to 16
    
    // DP state variables
    reg [4:0] a_idx; // Anthony's points 0-16
    reg [4:0] m_idx; // Cora's points 0-16
    reg [4:0] i_val; // Round number
    reg [15:0] dp_table [0:255]; // Lookup table for DP states
    // Index mapping: (a, m) -> index = a*17 + m (since N,M <= 16)
    
    // Temporary storage
    reg [7:0] p_val;
    reg [15:0] term1, term2;
    reg [15:0] dp_a_m_1, dp_a_1_m;
    
    // Computation state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 5'd0;
            a_idx <= 5'd0;
            m_idx <= 5'd0;
            i_val <= 5'd0;
            p_val <= 8'd0;
            dp_a_m_1 <= 16'd0;
            dp_a_1_m <= 16'd0;
            term1 <= 16'd0;
            term2 <= 16'd0;
            // Initialize dp_table to 0
            begin : init_table
                integer i;
                for (i = 0; i < 256; i = i + 1) begin
                    dp_table[i] <= 16'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 5'd0;
                    a_idx <= 5'd0;
                    m_idx <= 5'd0;
                    if (start) begin
                        state <= INIT_DP;
                    end
                end
                
                INIT_DP: begin
                    // Initialize base cases
                    if (a_idx <= N) begin
                        if (m_idx == 0) begin
                            // P(a, 0) = 1 for a > 0
                            if (a_idx > 5'd0) begin
                                dp_table[a_idx * 5'd17 + m_idx] <= 16'h0100; // Q8.8 for 1.0
                            end
                        end
                        if (m_idx < M) begin
                            m_idx <= m_idx + 5'd1;
                        end else begin
                            m_idx <= 5'd0;
                            if (a_idx < N) begin
                                a_idx <= a_idx + 5'd1;
                            end else begin
                                a_idx <= 5'd0;
                                state <= COMPUTE;
                            end
                        end
                    end else begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    // Start computing for a=0..N, m=0..M
                    if (a_idx <= N && m_idx <= M && !(a_idx == 0 && m_idx == 0)) begin
                        // Skip base cases already set
                        if ((a_idx > 0 && m_idx > 0) || (a_idx == 0 && m_idx > 0) || (a_idx > 0 && m_idx == 0)) begin
                            i_val <= (N - a_idx) + (M - m_idx);
                            state <= CALCULATE;
                        end else if (m_idx < M) begin
                            m_idx <= m_idx + 5'd1;
                        end else begin
                            m_idx <= 5'd0;
                            if (a_idx < N) begin
                                a_idx <= a_idx + 5'd1;
                            end else begin
                                state <= FINISH;
                            end
                        end
                    end else if (m_idx < M) begin
                        m_idx <= m_idx + 5'd1;
                    end else begin
                        m_idx <= 5'd0;
                        if (a_idx < N) begin
                            a_idx <= a_idx + 5'd1;
                        end else begin
                            state <= FINISH;
                        end
                    end
                end
                
                CALCULATE: begin
                    // Compute P(a, m) = p[i] * P(a, m-1) + (1-p[i]) * P(a-1, m)
                    p_val <= p[i_val];
                    
                    // Get P(a, m-1)
                    if (m_idx > 5'd0) begin
                        dp_a_m_1 <= dp_table[a_idx * 5'd17 + (m_idx - 5'd1)];
                    end else begin
                        dp_a_m_1 <= 16'd0;
                    end
                    
                    // Get P(a-1, m)
                    if (a_idx > 5'd0) begin
                        dp_a_1_m <= dp_table[(a_idx - 5'd1) * 5'd17 + m_idx];
                    end else begin
                        dp_a_1_m <= 16'd0;
                    end
                    
                    state <= WAIT;
                end
                
                WAIT: begin
                    // Calculate terms
                    // term1 = p[i] * P(a, m-1)
                    // p is Q8.8, dp is Q8.8, result is Q16.16, take middle 16 bits
                    term1 <= (p_val * dp_a_m_1) >> 8;
                    // term2 = (1-p[i]) * P(a-1, m)
                    term2 <= ((8'hFF - p_val) * dp_a_1_m) >> 8;
                    state <= COMPUTE;
                    
                    // Store result
                    dp_table[a_idx * 5'd17 + m_idx] <= (p_val * dp_a_m_1 + (8'hFF - p_val) * dp_a_1_m) >> 8;
                    
                    // Continue to next state
                    if (m_idx < M) begin
                        m_idx <= m_idx + 5'd1;
                    end else begin
                        m_idx <= 5'd0;
                        if (a_idx < N) begin
                            a_idx <= a_idx + 5'd1;
                        end else begin
                            state <= FINISH;
                        end
                    end
                end
                
                FINISH: begin
                    // Result is P(N, M) which should be at index N*17 + M
                    result <= dp_table[N * 5'd17 + M];
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule