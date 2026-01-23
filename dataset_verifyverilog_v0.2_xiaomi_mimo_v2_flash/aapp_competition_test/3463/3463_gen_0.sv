module game_probability (
    input clk,
    input rst_n,
    input start,
    input valid,
    input [31:0] p_i,
    output reg [31:0] result,
    output reg done,
    output reg ready
);

    // Parameters
    localparam N = 3;
    localparam M = 2;
    localparam ROUNDS = N + M; // Max rounds 5, but probabilities needed for potential 4 rounds (index 0-3)
    localparam ONE = 32'h00010000;
    
    // States
    localparam S_IDLE = 3'b000;
    localparam S_INIT = 3'b001; // Init DP array
    localparam S_COLLECT = 3'b010;
    localparam S_COMPUTE = 3'b100;
    localparam S_DONE = 3'b101;
    
    reg [2:0] current_state, next_state;
    
    // Memory for DP table: dp[a][c]
    // Addresses 0..5 for a (Anthony points) and c (Cora points)
    // We flatten this into a single array for synthesis
    // dp[a][c] -> index = a * 6 + c
    reg [31:0] dp [35:0]; 
    
    // Storage for probabilities
    // Max rounds for N=3, M=2 is 4 (indices 0 to 3)
    reg [31:0] probs [3:0];
    
    // Counters
    reg [2:0] p_idx;       // Index for collecting probabilities (0-3)
    reg [5:0] step_count; // 0 to 23 for compute
    reg [2:0] init_count; // 0 to 5 for init
    
    // Internal signals
    wire [31:0] p_val;
    wire [31:0] one_minus_p;
    wire [31:0] dp_next_anthony;
    wire [31:0] dp_next_cora;
    wire [31:0] dp_curr;
    wire [31:0] term1; // p * dp[a][c-1][r+1]
    wire [31:0] term2; // (1-p) * dp[a-1][c][r+1]
    
    // Helper signals for addresses
    wire [5:0] addr_curr;
    wire [5:0] addr_a_c_minus_1;
    wire [5:0] addr_a_minus_1_c;
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= S_IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        case (current_state)
            S_IDLE: next_state = start ? S_INIT : S_IDLE;
            S_INIT: begin
                if (init_count == 5) next_state = S_COLLECT;
                else next_state = S_INIT;
            end
            S_COLLECT: begin
                if (p_idx == 3 && valid) next_state = S_COMPUTE;
                else next_state = S_COLLECT;
            end
            S_COMPUTE: begin
                if (step_count == 23) next_state = S_DONE;
                else next_state = S_COMPUTE;
            end
            S_DONE: begin
                if (start) next_state = S_IDLE;
                else next_state = S_DONE;
            end
            default: next_state = S_IDLE;
        endcase
    end
    
    // Control signals and Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            ready <= 1'b0;
            result <= 32'd0;
            p_idx <= 3'd0;
            step_count <= 6'd0;
            init_count <= 3'd0;
            // Memory reset omitted for efficiency, handled by init state.
        end else begin
            case (current_state)
                S_IDLE: begin
                    done <= 1'b0;
                    ready <= 1'b1;
                    p_idx <= 3'd0;
                    step_count <= 6'd0;
                    init_count <= 3'd0;
                    // result <= 32'd0; // Keep result visible until overwritten
                end
                
                S_INIT: begin
                    ready <= 1'b0;
                    // Write base cases
                    if (init_count < 3) begin
                        dp[(init_count + 1) * 6] <= ONE;
                    end else if (init_count < 5) begin
                        dp[init_count - 2] <= 32'd0;
                    end
                    
                    if (init_count < 5)
                        init_count <= init_count + 1;
                end
                
                S_COLLECT: begin
                    if (valid) begin
                        probs[p_idx] <= p_i;
                        if (p_idx < 3)
                            p_idx <= p_idx + 1;
                    end
                end
                
                S_COMPUTE: begin
                    if (step_count < 24) begin
                        dp[w_addr] <= new_val;
                    end
                    
                    if (step_count < 23) begin
                        step_count <= step_count + 1;
                    end
                end
                
                S_DONE: begin
                    result <= dp[20];
                    done <= 1'b1;
                    ready <= 1'b0;
                end
            endcase
        end
    end
    
    // Helper logic for Compute State
    // Indices derived from step_count
    wire [2:0] r_calc = 3 - (step_count / 6);
    wire [5:0] rem_calc = step_count % 6;
    wire [2:0] a_calc = 3 - (rem_calc / 2);
    wire [2:0] c_calc = 2 - (rem_calc % 2);
    
    // Address calculation
    wire [5:0] w_addr = a_calc * 6 + c_calc;
    wire [5:0] r1_addr = a_calc * 6 + (c_calc - 1);
    wire [5:0] r2_addr = (a_calc - 1) * 6 + c_calc;
    
    // Read data
    wire [31:0] dp_r1 = dp[r1_addr];
    wire [31:0] dp_r2 = dp[r2_addr];
    wire [31:0] p_r = probs[r_calc];
    
    // Math
    wire [63:0] m1 = p_r * dp_r1;
    wire [63:0] m2 = (ONE - p_r) * dp_r2;
    wire [31:0] new_val = m1[47:16] + m2[47:16];

endmodule
