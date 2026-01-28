module interleaving_checker (
    input clk,
    input rst_n,
    input start,
    input [127:0] s1,
    input [127:0] s2,
    input [127:0] s,
    input [4:0] len_s1,
    input [4:0] len_s2,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE    = 2'd2;
    
    reg [1:0] state;
    reg [4:0] i, j;
    reg [4:0] i_next, j_next;
    
    // DP array: 17x17 bits
    reg dp [0:16][0:16];
    
    // Next state logic registers
    reg dp_next;
    
    // Cycle counter to prevent infinite loops
    reg [8:0] cycle_count;
    localparam [8:0] MAX_CYCLES = 9'd400;
    
    // Helper combinational logic
    wire [7:0] s1_char;
    wire [7:0] s2_char;
    wire [7:0] s_char;
    
    assign s1_char = s1[i_next*8 +: 8];
    assign s2_char = s2[j_next*8 +: 8];
    assign s_char  = s[(i_next + j_next - 1)*8 +: 8];
    
    // Helper to get dp values
    wire dp_im1_j;
    wire dp_i_jm1;
    assign dp_im1_j = (i_next > 0) ? dp[i_next-1][j_next] : 1'b0;
    assign dp_i_jm1 = (j_next > 0) ? dp[i_next][j_next-1] : 1'b0;
    
    // Next DP value computation
    wire cond1;
    wire cond2;
    assign cond1 = (i_next > 0) && dp_im1_j && (s1_char == s_char);
    assign cond2 = (j_next > 0) && dp_i_jm1 && (s2_char == s_char);
    
    always @(*) begin
        if (i_next == 0 && j_next == 0) begin
            dp_next = 1'b1;
        end else begin
            dp_next = cond1 || cond2;
        end
    end
    
    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            i <= 5'd0;
            j <= 5'd0;
            i_next <= 5'd0;
            j_next <= 5'd0;
            cycle_count <= 9'd0;
            // Initialize dp array
            for (integer ii = 0; ii <= 16; ii = ii + 1) begin
                for (integer jj = 0; jj <= 16; jj = jj + 1) begin
                    dp[ii][jj] <= 1'b0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 9'd0;
                    
                    if (start) begin
                        // Initialize dp[0][0]
                        dp[0][0] <= 1'b1;
                        i <= 5'd0;
                        j <= 5'd0;
                        i_next <= 5'd0;
                        j_next <= 5'd0;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 9'd1;
                    
                    // Calculate next indices for current computation
                    if (j < len_s2) begin
                        j_next <= j + 5'd1;
                        i_next <= i;
                    end else begin
                        j_next <= 5'd0;
                        if (i < len_s1) begin
                            i_next <= i + 5'd1;
                        end else begin
                            i_next <= i;
                            j_next <= j;
                        end
                    end
                    
                    // Store current cell result before moving
                    if (i <= len_s1 && j <= len_s2) begin
                        dp[i][j] <= dp_next;
                    end
                    
                    // Move to next cell or finish
                    if (j < len_s2) begin
                        j <= j + 5'd1;
                    end else begin
                        j <= 5'd0;
                        if (i < len_s1) begin
                            i <= i + 5'd1;
                        end else begin
                            // Done with all cells
                            result <= dp[len_s1][len_s2];
                            state <= DONE;
                        end
                    end
                    
                    // Safety timeout
                    if (cycle_count >= MAX_CYCLES) begin
                        result <= 1'b0;
                        state <= DONE;
                    end
                end
                
                DONE: begin
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