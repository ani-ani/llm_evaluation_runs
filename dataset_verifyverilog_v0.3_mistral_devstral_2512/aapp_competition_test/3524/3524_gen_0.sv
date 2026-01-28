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
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;

    // DP array: 17x17 bits (indexed by i, j)
    reg dp [0:16][0:16];

    // Helper function to get character
    function [7:0] get_char;
        input [127:0] vec;
        input [4:0] idx;
        begin
            get_char = vec[idx*8 +: 8];
        end
    endfunction

    // Combinational next DP value
    wire next_dp = ((i > 0 && dp[i-1][j] && get_char(s1, i-1) == get_char(s, i+j-1)) ||
                    (j > 0 && dp[i][j-1] && get_char(s2, j-1) == get_char(s, i+j-1)));

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            i <= 5'd0;
            j <= 5'd0;
            cycle_count <= 8'd0;
            // Clear dp
            integer ii, jj;
            for (ii = 0; ii <= 16; ii = ii + 1) begin
                for (jj = 0; jj <= 16; jj = jj + 1) begin
                    dp[ii][jj] <= 1'b0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        dp[0][0] <= 1'b1;
                        i <= 5'd0;
                        j <= 5'd0;
                        cycle_count <= 8'd0;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute for current i, j if within bounds
                    if (i <= len_s1 && j <= len_s2) begin
                        if (i == 0 && j == 0) begin
                            // already set
                        end else begin
                            dp[i][j] <= next_dp;
                        end
                    end
                    
                    // Move to next cell
                    if (j < len_s2) begin
                        j <= j + 5'd1;
                    end else begin
                        j <= 5'd0;
                        if (i < len_s1) begin
                            i <= i + 5'd1;
                        end else begin
                            result <= dp[len_s1][len_s2];
                            state <= DONE;
                        end
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule