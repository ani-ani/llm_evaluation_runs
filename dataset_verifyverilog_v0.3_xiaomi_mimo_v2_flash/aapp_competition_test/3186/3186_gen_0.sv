module combinatorial(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [3:0] M,
    input wire [3:0] K,
    output reg [31:0] result,
    output reg done
);

    // States
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] SETUP    = 3'd1;
    localparam [2:0] COMPUTE  = 3'd2;
    localparam [2:0] SWAP     = 3'd3;
    localparam [2:0] FINISH   = 3'd4;

    // Modulo constant
    localparam [31:0] MOD = 32'd1000007;

    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] i;                // Current type index (1 to N)
    reg [3:0] j;                // Current items count (0 to K)
    reg [3:0] c;                // Copies count (0 to min(M, j))
    reg [31:0] sum;             // Accumulator for DP sum
    reg [31:0] temp_val;        // Temporary value for reading/writing

    // DP Arrays: Size 9 (0 to 8)
    // We cannot use arrays directly in always blocks in Icarus Verilog for initialization/slice assignment.
    // Instead, we instantiate 9 separate registers for each array.
    reg [31:0] dp_prev_0, dp_prev_1, dp_prev_2, dp_prev_3, dp_prev_4, dp_prev_5, dp_prev_6, dp_prev_7, dp_prev_8;
    reg [31:0] dp_curr_0, dp_curr_1, dp_curr_2, dp_curr_3, dp_curr_4, dp_curr_5, dp_curr_6, dp_curr_7, dp_curr_8;

    // Combinational logic for state transition
    always @(*) begin
        case (state)
            IDLE:       next_state = start ? SETUP : IDLE;
            SETUP:      next_state = COMPUTE;
            COMPUTE:    next_state = (j == K) ? SWAP : COMPUTE;
            SWAP:       next_state = (i == N) ? FINISH : COMPUTE;
            FINISH:     next_state = IDLE;
            default:    next_state = IDLE;
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            c <= 4'd0;
            sum <= 32'd0;
            temp_val <= 32'd0;
            
            // Reset DP arrays
            dp_prev_0 <= 32'd0; dp_prev_1 <= 32'd0; dp_prev_2 <= 32'd0; dp_prev_3 <= 32'd0;
            dp_prev_4 <= 32'd0; dp_prev_5 <= 32'd0; dp_prev_6 <= 32'd0; dp_prev_7 <= 32'd0;
            dp_prev_8 <= 32'd0;
            
            dp_curr_0 <= 32'd0; dp_curr_1 <= 32'd0; dp_curr_2 <= 32'd0; dp_curr_3 <= 32'd0;
            dp_curr_4 <= 32'd0; dp_curr_5 <= 32'd0; dp_curr_6 <= 32'd0; dp_curr_7 <= 32'd0;
            dp_curr_8 <= 32'd0;
        end else begin
            done <= 1'b0; // Default done to 0
            
            case (state)
                IDLE: begin
                    if (start) begin
                        // Initialize for start
                        i <= 4'd1; // Start with first type
                        j <= 4'd0;
                        c <= 4'd0;
                        sum <= 32'd0;
                        done <= 1'b0;
                    end
                end

                SETUP: begin
                    // Initialize dp_prev: dp_prev[0] = 1, others 0
                    dp_prev_0 <= 32'd1;
                    dp_prev_1 <= 32'd0;
                    dp_prev_2 <= 32'd0;
                    dp_prev_3 <= 32'd0;
                    dp_prev_4 <= 32'd0;
                    dp_prev_5 <= 32'd0;
                    dp_prev_6 <= 32'd0;
                    dp_prev_7 <= 32'd0;
                    dp_prev_8 <= 32'd0;
                    
                    // Reset current row
                    dp_curr_0 <= 32'd0;
                    dp_curr_1 <= 32'd0;
                    dp_curr_2 <= 32'd0;
                    dp_curr_3 <= 32'd0;
                    dp_curr_4 <= 32'd0;
                    dp_curr_5 <= 32'd0;
                    dp_curr_6 <= 32'd0;
                    dp_curr_7 <= 32'd0;
                    dp_curr_8 <= 32'd0;
                    
                    // Reset counters for inner loops
                    j <= 4'd0;
                    c <= 4'd0;
                    sum <= 32'd0;
                end

                COMPUTE: begin
                    // Logic for dp_curr[j] = sum_{c=0}^{min(M, j)} dp_prev[j-c]
                    // We handle this sequentially:
                    // 1. Reset sum at start of j loop (handled by j change)
                    // 2. Accumulate for c loop
                    
                    // We need to read dp_prev[j-c]
                    // Since we can't use arrays, we use a MUX based on j and c
                    // Target index for dp_prev is (j - c)
                    
                    // We need a combinational read of dp_prev based on (j - c)
                    // But inside always block, we do sequential update.
                    // Let's perform the accumulation logic.
                    
                    // If j changed (start of new j iteration), reset sum
                    // However, detecting j change vs c loop continuation is tricky in single block.
                    // Let's structure: c iterates 0 to min(M, j).
                    // When c==0, we reset sum.
                    
                    if (c == 4'd0) begin
                        sum <= 32'd0;
                    end
                    
                    // Read dp_prev[j - c]
                    case (j - c)
                        4'd0: temp_val <= dp_prev_0;
                        4'd1: temp_val <= dp_prev_1;
                        4'd2: temp_val <= dp_prev_2;
                        4'd3: temp_val <= dp_prev_3;
                        4'd4: temp_val <= dp_prev_4;
                        4'd5: temp_val <= dp_prev_5;
                        4'd6: temp_val <= dp_prev_6;
                        4'd7: temp_val <= dp_prev_7;
                        4'd8: temp_val <= dp_prev_8;
                        default: temp_val <= 32'd0;
                    endcase
                    
                    // Accumulate (updated in next cycle to use valid temp_val)
                    sum <= (sum + temp_val) % MOD;
                    
                    // Increment c
                    if (c < M && c < j) begin
                        c <= c + 4'd1;
                    end else begin
                        // Done with this j, write result to dp_curr[j]
                        case (j)
                            4'd0: dp_curr_0 <= sum;
                            4'd1: dp_curr_1 <= sum;
                            4'd2: dp_curr_2 <= sum;
                            4'd3: dp_curr_3 <= sum;
                            4'd4: dp_curr_4 <= sum;
                            4'd5: dp_curr_5 <= sum;
                            4'd6: dp_curr_6 <= sum;
                            4'd7: dp_curr_7 <= sum;
                            4'd8: dp_curr_8 <= sum;
                        endcase
                        
                        // Move to next j
                        j <= j + 4'd1;
                        c <= 4'd0; // Reset c for next j
                    end
                end

                SWAP: begin
                    // Swap pointers: dp_prev = dp_curr
                    // Copy dp_curr to dp_prev
                    dp_prev_0 <= dp_curr_0;
                    dp_prev_1 <= dp_curr_1;
                    dp_prev_2 <= dp_curr_2;
                    dp_prev_3 <= dp_curr_3;
                    dp_prev_4 <= dp_curr_4;
                    dp_prev_5 <= dp_curr_5;
                    dp_prev_6 <= dp_curr_6;
                    dp_prev_7 <= dp_curr_7;
                    dp_prev_8 <= dp_curr_8;
                    
                    // Reset dp_curr for next iteration (safety)
                    // Not strictly necessary but clean
                    // We actually clear it to 0 for next i
                    dp_curr_0 <= 32'd0;
                    dp_curr_1 <= 32'd0;
                    dp_curr_2 <= 32'd0;
                    dp_curr_3 <= 32'd0;
                    dp_curr_4 <= 32'd0;
                    dp_curr_5 <= 32'd0;
                    dp_curr_6 <= 32'd0;
                    dp_curr_7 <= 32'd0;
                    dp_curr_8 <= 32'd0;
                    
                    // Increment i (type count)
                    i <= i + 4'd1;
                    
                    // Reset j and c for next outer iteration
                    j <= 4'd0;
                    c <= 4'd0;
                end

                FINISH: begin
                    // Extract result dp_prev[K]
                    case (K)
                        4'd0: result <= dp_prev_0;
                        4'd1: result <= dp_prev_1;
                        4'd2: result <= dp_prev_2;
                        4'd3: result <= dp_prev_3;
                        4'd4: result <= dp_prev_4;
                        4'd5: result <= dp_prev_5;
                        4'd6: result <= dp_prev_6;
                        4'd7: result <= dp_prev_7;
                        4'd8: result <= dp_prev_8;
                        default: result <= 32'd0;
                    endcase
                    done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Update state
            state <= next_state;
        end
    end

endmodule