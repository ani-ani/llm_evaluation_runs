module knight_arrangements(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] n,
    input wire [31:0] m,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE       = 4'd0;
    localparam [3:0] CHECK_M    = 4'd1;
    localparam [3:0] INIT_V0    = 4'd2;
    localparam [3:0] EXP_START  = 4'd3;
    localparam [3:0] MULT_V_T   = 4'd4;
    localparam [3:0] MULT_T_T   = 4'd5;
    localparam [3:0] UPDATE_EXP = 4'd6;
    localparam [3:0] SUM_VECTOR = 4'd7;
    localparam [3:0] DONE_STATE = 4'd8;

    // Parameters
    localparam [31:0] MOD = 32'd1000000009;
    localparam [7:0] MAX_STATE_SIZE = 8'd256;
    localparam [7:0] MAX_MATRIX_SIZE = 8'd255; // 255 x 255 = 65025 entries

    // State variables
    reg [3:0] state;
    reg [31:0] m_reg;
    reg [7:0] state_size;
    reg [31:0] exponent;
    reg [7:0] i, j, k;
    reg [31:0] sum_temp;
    reg [7:0] cycle_count;

    // Vector and matrix storage (unpacked arrays for compatibility)
    reg [31:0] V [0:255];      // Current state vector
    reg [31:0] T [0:65535];    // Transition matrix (flattened)
    reg [31:0] T_temp [0:65535]; // Temporary for squaring
    reg [31:0] V_temp [0:255];   // Temporary for vector multiplication

    // Precomputed initialization data for n=1,2,3,4
    // T maps [src_mask][dst_mask] = number of ways
    // For n=1: 2^(2*1) = 4 states
    reg [31:0] T_n1 [0:15];
    // For n=2: 2^(2*2) = 16 states
    reg [31:0] T_n2 [0:255];
    // For n=3: 2^(2*3) = 64 states
    reg [31:0] T_n3 [0:4095];
    // For n=4: 2^(2*4) = 256 states
    reg [31:0] T_n4 [0:65535];

    // V0 is always [1, 1, 1, 1] for n=1, extended for larger n
    reg [31:0] V0 [0:255];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            m_reg <= 32'd0;
            state_size <= 8'd0;
            exponent <= 32'd0;
            i <= 8'd0;
            j <= 8'd0;
            k <= 8'd0;
            sum_temp <= 32'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= CHECK_M;
                        m_reg <= m;
                        cycle_count <= 8'd0;
                        // Initialize state size based on n
                        case (n)
                            2'b00: state_size <= 8'd4;
                            2'b01: state_size <= 8'd16;
                            2'b10: state_size <= 8'd64;
                            2'b11: state_size <= 8'd256;
                            default: state_size <= 8'd4;
                        endcase
                    end
                end

                CHECK_M: begin
                    if (m_reg == 32'd1) begin
                        // For m=1, result = 2^n
                        case (n)
                            2'b00: result <= 32'd2;
                            2'b01: result <= 32'd4;
                            2'b10: result <= 32'd8;
                            2'b11: result <= 32'd16;
                        endcase
                        state <= DONE_STATE;
                    end else begin
                        state <= INIT_V0;
                        i <= 8'd0;
                    end
                end

                INIT_V0: begin
                    // Initialize V[i] = 1 for i < state_size, else 0
                    if (i < state_size) begin
                        V[i] <= 32'd1;
                        i <= i + 8'd1;
                    end else begin
                        // Load transition matrix for the given n
                        case (n)
                            2'b00: begin
                                // Load T_n1 into T
                                // Assuming T_n1 is precomputed externally
                                // For demo, we set T[0][0] = 1, T[0][1] = 2, etc.
                                // In real implementation, T_n1 would be pre-filled
                                state <= EXP_START;
                            end
                            2'b01: begin
                                // Load T_n2 into T
                                state <= EXP_START;
                            end
                            2'b10: begin
                                // Load T_n3 into T
                                state <= EXP_START;
                            end
                            2'b11: begin
                                // Load T_n4 into T
                                state <= EXP_START;
                            end
                            default: state <= EXP_START;
                        endcase
                    end
                end

                EXP_START: begin
                    // m >= 2, so exponent = m - 2
                    exponent <= m_reg - 32'd2;
                    if (m_reg == 32'd2) begin
                        state <= SUM_VECTOR;
                    end else begin
                        state <= MULT_V_T;
                        i <= 8'd0;
                    end
                end

                MULT_V_T: begin
                    // V_temp = V * T (vector-matrix multiplication)
                    // V_temp[j] = sum_i V[i] * T[i][j]
                    // We compute one element j per cycle
                    if (i < state_size) begin
                        reg [31:0] temp_sum;
                        temp_sum = 32'd0;
                        for (k = 0; k < state_size; k = k + 1) begin
                            // T[k][i] is at index k * state_size + i
                            temp_sum = (temp_sum + V[k] * T[k * 256 + i]) % MOD;
                        end
                        V_temp[i] <= temp_sum;
                        i <= i + 8'd1;
                    end else begin
                        // Copy V_temp back to V
                        if (j < state_size) begin
                            V[j] <= V_temp[j];
                            j <= j + 8'd1;
                        end else begin
                            j <= 8'd0;
                            state <= MULT_T_T;
                        end
                    end
                end

                MULT_T_T: begin
                    // T_temp = T * T (matrix multiplication)
                    // T_temp[i][j] = sum_k T[i][k] * T[k][j]
                    // Compute one row i per cycle
                    if (i < state_size) begin
                        reg [31:0] temp_sum;
                        temp_sum = 32'd0;
                        for (k = 0; k < state_size; k = k + 1) begin
                            // T[i][k] = T[i * 256 + k]
                            // T[k][j] = T[k * 256 + j]
                            // We compute T_temp[i][j] for all j in this i
                            // Actually, let's compute one element per cycle for simplicity
                        end
                        // To avoid complex loops, we'll do a simpler approach
                        // Compute T_temp[i * 256 + j] for all j when i is set
                        for (j = 0; j < state_size; j = j + 1) begin
                            reg [31:0] accum;
                            accum = 32'd0;
                            for (k = 0; k < state_size; k = k + 1) begin
                                accum = (accum + T[i * 256 + k] * T[k * 256 + j]) % MOD;
                            end
                            T_temp[i * 256 + j] <= accum;
                        end
                        i <= i + 8'd1;
                    end else begin
                        // Copy T_temp back to T
                        if (i < state_size * state_size) begin
                            T[i] <= T_temp[i];
                            i <= i + 8'd1;
                        end else begin
                            state <= UPDATE_EXP;
                        end
                    end
                end

                UPDATE_EXP: begin
                    exponent <= exponent >> 1;
                    if (exponent == 32'd0) begin
                        state <= SUM_VECTOR;
                    end else begin
                        state <= MULT_V_T;
                        i <= 8'd0;
                        j <= 8'd0;
                    end
                end

                SUM_VECTOR: begin
                    // result = sum(V[i]) mod MOD
                    if (i < state_size) begin
                        sum_temp <= (sum_temp + V[i]) % MOD;
                        i <= i + 8'd1;
                    end else begin
                        result <= sum_temp;
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Initialize precomputed data (must be done in synthesis-friendly way)
    initial begin
        // Initialize T_n1 (4x4 matrix)
        // State 0: (0,0) -> ways to (0,0), (0,1), (1,0), (1,1)
        T_n1[0] = 32'd1; T_n1[1] = 32'd2; T_n1[2] = 32'd2; T_n1[3] = 32'd1;
        // State 1: (0,1) -> ways to (0,0), (0,1), (1,0), (1,1)
        T_n1[4] = 32'd1; T_n1[5] = 32'd2; T_n1[6] = 32'd2; T_n1[7] = 32'd1;
        // State 2: (1,0) -> ways to (0,0), (0,1), (1,0), (1,1)
        T_n1[8] = 32'd1; T_n1[9] = 32'd2; T_n1[10] = 32'd2; T_n1[11] = 32'd1;
        // State 3: (1,1) -> ways to (0,0), (0,1), (1,0), (1,1)
        T_n1[12] = 32'd1; T_n1[13] = 32'd2; T_n1[14] = 32'd2; T_n1[15] = 32'd1;

        // For n=2,3,4, the matrices would be larger
        // In a real implementation, these would be precomputed
        // and initialized similarly
        // For brevity, we show the structure
    end

endmodule