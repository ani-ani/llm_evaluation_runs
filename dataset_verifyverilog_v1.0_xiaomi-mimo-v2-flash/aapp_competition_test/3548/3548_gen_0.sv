module PartitionCounter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [255:0] adjacency_matrix,
    input wire [3:0] N,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [3:0] MAX_N = 4'd16;
    
    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT_DP   = 3'd1;
    localparam [2:0] RESET_SEG = 3'd2;
    localparam [2:0] CHECK_SEG = 3'd3;
    localparam [2:0] ADD_DP    = 3'd4;
    localparam [2:0] NEXT_J    = 3'd5;
    localparam [2:0] NEXT_I    = 3'd6;
    localparam [2:0] FINISH    = 3'd7;

    // Registers
    reg [2:0] state, next_state;
    reg [3:0] i_reg;           // Outer loop counter (1 to N)
    reg [3:0] j_reg;           // Inner loop counter (i-1 down to 0)
    reg [3:0] k_reg;           // Validity check loop counter
    reg [16:0] dp [0:16];      // dp array (17 entries, 0 to 16)
    reg [31:0] dp_sum;         // Accumulator for dp[i]
    reg seg_valid;             // Validity flag for current segment
    reg [31:0] temp_result;
    reg [1:0] cycle_count;     // Small cycle counter for operations
    
    // Wire for adjacency check
    wire bad_pair;
    assign bad_pair = adjacency_matrix[{j_reg, k_reg}] || adjacency_matrix[{k_reg, j_reg}];

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            k_reg <= 4'd0;
            seg_valid <= 1'b0;
            dp_sum <= 32'd0;
            temp_result <= 32'd0;
            cycle_count <= 2'd0;
            // Initialize dp array
            dp[0] <= 17'd1;
            dp[1] <= 17'd0; dp[2] <= 17'd0; dp[3] <= 17'd0; dp[4] <= 17'd0;
            dp[5] <= 17'd0; dp[6] <= 17'd0; dp[7] <= 17'd0; dp[8] <= 17'd0;
            dp[9] <= 17'd0; dp[10] <= 17'd0; dp[11] <= 17'd0; dp[12] <= 17'd0;
            dp[13] <= 17'd0; dp[14] <= 17'd0; dp[15] <= 17'd0; dp[16] <= 17'd0;
        end else begin
            state <= next_state;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        // Reset dp array
                        dp[0] <= 17'd1;
                        dp[1] <= 17'd0; dp[2] <= 17'd0; dp[3] <= 17'd0; dp[4] <= 17'd0;
                        dp[5] <= 17'd0; dp[6] <= 17'd0; dp[7] <= 17'd0; dp[8] <= 17'd0;
                        dp[9] <= 17'd0; dp[10] <= 17'd0; dp[11] <= 17'd0; dp[12] <= 17'd0;
                        dp[13] <= 17'd0; dp[14] <= 17'd0; dp[15] <= 17'd0; dp[16] <= 17'd0;
                        i_reg <= 4'd1;
                        j_reg <= 4'd0;
                        k_reg <= 4'd0;
                        dp_sum <= 32'd0;
                        cycle_count <= 2'd0;
                    end
                end
                
                INIT_DP: begin
                    // Initialize dp[i] to 0 before summing
                    dp[i_reg] <= 17'd0;
                    j_reg <= i_reg - 4'd1;
                end
                
                RESET_SEG: begin
                    // Start checking segment validity
                    seg_valid <= 1'b1;
                    k_reg <= j_reg + 4'd1;
                    cycle_count <= 2'd0;
                end
                
                CHECK_SEG: begin
                    // Check pairs (j, k) for k in (j, i-1]
                    if (cycle_count == 2'd0) begin
                        // Wait one cycle for bad_pair signal
                        cycle_count <= 2'd1;
                    end else if (cycle_count == 2'd1) begin
                        if (bad_pair) begin
                            seg_valid <= 1'b0;
                        end
                        // Move to next k or finish
                        if (k_reg < i_reg - 4'd1) begin
                            k_reg <= k_reg + 4'd1;
                            cycle_count <= 2'd0;
                        end else begin
                            // Done checking this segment
                            cycle_count <= 2'd0;
                        end
                    end
                end
                
                ADD_DP: begin
                    // If segment is valid, add dp[j] to dp[i]
                    if (seg_valid) begin
                        // Addition with modulo
                        dp_sum <= (dp_sum + {15'd0, dp[j_reg]}) % MOD;
                    end
                end
                
                NEXT_J: begin
                    // Update dp[i] with accumulated sum
                    dp[i_reg] <= dp_sum[16:0]; // dp values fit in 17 bits
                    // Move to next j or finish inner loop
                    if (j_reg > 4'd0) begin
                        j_reg <= j_reg - 4'd1;
                        dp_sum <= 32'd0; // Reset sum for next j
                    end
                end
                
                NEXT_I: begin
                    // Move to next i or finish
                    if (i_reg < N) begin
                        i_reg <= i_reg + 4'd1;
                    end
                end
                
                FINISH: begin
                    result <= {15'd0, dp[N]}; // Final result
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    if (N == 4'd0) begin
                        next_state = FINISH;
                    end else begin
                        next_state = INIT_DP;
                    end
                end
            end
            
            INIT_DP: begin
                next_state = RESET_SEG;
            end
            
            RESET_SEG: begin
                next_state = CHECK_SEG;
            end
            
            CHECK_SEG: begin
                if (cycle_count == 2'd1 && k_reg >= i_reg - 4'd1) begin
                    // Finished checking all pairs in segment
                    next_state = ADD_DP;
                end
            end
            
            ADD_DP: begin
                next_state = NEXT_J;
            end
            
            NEXT_J: begin
                if (j_reg > 4'd0) begin
                    next_state = RESET_SEG;
                end else begin
                    // Finished all j for current i
                    next_state = NEXT_I;
                end
            end
            
            NEXT_I: begin
                if (i_reg < N) begin
                    next_state = INIT_DP;
                end else begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule