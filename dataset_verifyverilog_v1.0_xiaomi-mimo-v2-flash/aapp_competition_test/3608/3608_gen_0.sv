module task_counter #(
    parameter MOD = 1000000007,
    parameter MAX_N = 32
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] N,
    input wire [4:0] A_addr,
    input wire [31:0] A_data,
    input wire [4:0] B_addr,
    input wire [31:0] B_data,
    output reg [31:0] result,
    output reg done,
    output reg busy
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SETUP = 3'd1; // Read N, initialize
    localparam [2:0] FETCH_A = 3'd2; // Request A[i]
    localparam [2:0] FETCH_B = 3'd3; // Request B[i]
    localparam [2:0] COMPUTE = 3'd4; // Calculate new DP values
    localparam [2:0] DONE = 3'd5;
    localparam [2:0] LOAD_A = 3'd6; // Capture A[i] data
    localparam [2:0] LOAD_B = 3'd7; // Capture B[i] data

    reg [2:0] state, next_state;
    reg [4:0] i; // Current difficulty index (1 to N)
    reg [31:0] dp_prev_0, dp_prev_1; // dp[i-1][0], dp[i-1][1]
    reg [31:0] dp_curr_0, dp_curr_1; // dp[i][0], dp[i][1]
    reg [31:0] A_val, B_val; // Captured A[i], B[i]
    reg [5:0] cycle_count; // Timeout safety
    localparam [5:0] MAX_CYCLES = 6'd50;

    // Multiplication intermediate (64-bit for 32x32)
    reg [63:0] mult_temp;
    reg [31:0] mult_result;

    // Combinational logic for result update
    always @(*) begin
        // dp[i][0] = (dp[i-1][0] * (A[i] + B[i])) + (dp[i-1][1] * A[i])
        // dp[i][1] = dp[i-1][0] * B[i]
        
        // Intermediate sums
        reg [31:0] sum_ab;
        reg [31:0] term1, term2, term3;
        reg [63:0] prod1, prod2, prod3;
        
        sum_ab = (A_val + B_val) % MOD;
        
        // Term 1: dp_prev_0 * sum_ab
        prod1 = dp_prev_0 * sum_ab;
        term1 = prod1 % MOD;
        
        // Term 2: dp_prev_1 * A_val
        prod2 = dp_prev_1 * A_val;
        term2 = prod2 % MOD;
        
        // dp_curr_0 = term1 + term2
        dp_curr_0 = (term1 + term2) % MOD;
        
        // Term 3: dp_prev_0 * B_val
        prod3 = dp_prev_0 * B_val;
        dp_curr_1 = prod3 % MOD;
    end

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = SETUP;
                else next_state = IDLE;
            end
            SETUP: begin
                if (i > N) next_state = DONE; // Should handle N=0 case
                else if (N == 5'd0) next_state = DONE;
                else next_state = FETCH_A;
            end
            FETCH_A: next_state = LOAD_A;
            LOAD_A: next_state = FETCH_B;
            FETCH_B: next_state = LOAD_B;
            LOAD_B: next_state = COMPUTE;
            COMPUTE: begin
                if (i < N) next_state = FETCH_A;
                else next_state = DONE;
            end
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            busy <= 1'b0;
            i <= 5'd0;
            dp_prev_0 <= 32'd1; // Base case
            dp_prev_1 <= 32'd0;
            A_val <= 32'd0;
            B_val <= 32'd0;
            cycle_count <= 6'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                    cycle_count <= 6'd0;
                    // Keep dp_prev values for next run if desired, or reset them in SETUP
                end
                SETUP: begin
                    busy <= 1'b1;
                    i <= 5'd1; // Start from difficulty 1
                    dp_prev_0 <= 32'd1;
                    dp_prev_1 <= 32'd0;
                    cycle_count <= 6'd0;
                end
                FETCH_A: begin
                    // A_addr is i (1-based)
                    // External logic should present A_data for address i
                    cycle_count <= cycle_count + 6'd1;
                end
                LOAD_A: begin
                    A_val <= A_data;
                end
                FETCH_B: begin
                    // B_addr is i-1 (0-based index for B array)
                    // For i=N, B doesn't exist, B_data should be 0
                    cycle_count <= cycle_count + 6'd1;
                end
                LOAD_B: begin
                    B_val <= B_data;
                end
                COMPUTE: begin
                    // Update DP values using combinational logic
                    dp_prev_0 <= dp_curr_0;
                    dp_prev_1 <= dp_curr_1;
                    
                    // Increment difficulty index
                    i <= i + 5'd1;
                    
                    // Timeout check
                    if (cycle_count > MAX_CYCLES) begin
                        state <= DONE;
                        result <= 32'd0;
                    end
                end
                DONE: begin
                    // Final result is dp_prev_0 (which holds dp[N][0] after last iteration)
                    result <= dp_prev_0;
                    done <= 1'b1;
                    busy <= 1'b0;
                end
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // State update
            if (state != DONE) state <= next_state;
            else state <= next_state;
        end
    end

endmodule