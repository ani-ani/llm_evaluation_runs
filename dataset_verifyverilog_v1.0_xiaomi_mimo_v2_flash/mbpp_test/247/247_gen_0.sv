module lps(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] str_0, str_1, str_2, str_3, str_4, str_5, str_6, str_7,
    input wire [3:0] str_len,
    output reg [3:0] result,
    output reg done
);

// Longest Palindromic Subsequence - Sequential DP implementation
// Supports strings up to 8 characters (max length = 8)
// Uses 8x8 matrix stored in registers
// Computation completes in ~80 cycles (8x8 matrix fill)

// Internal state machine
reg [4:0] state;  // Need 5 bits for 18 states
reg [3:0] i, j, cl;
reg [7:0] L [0:7][0:7];  // 8x8 matrix for DP table
reg [3:0] len_reg;       // Store string length
reg [7:0] char_i, char_j;

// State definitions
localparam [4:0] IDLE = 5'd0;
localparam [4:0] INIT_DIAG = 5'd1;
localparam [4:0] CL_LOOP = 5'd2;
localparam [4:0] I_LOOP = 5'd3;
localparam [4:0] GET_J = 5'd4;
localparam [4:0] CHECK_CHARS = 5'd5;
localparam [4:0] UPDATE_MATCH = 5'd6;
localparam [4:0] UPDATE_DIFF = 5'd7;
localparam [4:0] COMPLETE = 5'd8;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset state
        state <= IDLE;
        done <= 1'b0;
        result <= 4'd0;
        i <= 4'd0;
        j <= 4'd0;
        cl <= 4'd0;
        len_reg <= 4'd0;
        char_i <= 8'd0;
        char_j <= 8'd0;
        // Clear matrix
        for (integer r = 0; r < 8; r = r + 1) begin
            for (integer c = 0; c < 8; c = c + 1) begin
                L[r][c] <= 8'd0;
            end
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    len_reg <= str_len;
                    state <= INIT_DIAG;
                    i <= 4'd0;
                end
            end
            
            INIT_DIAG: begin
                // Set L[i][i] = 1 for all i < len_reg
                if (i < len_reg) begin
                    L[i][i] <= 8'd1;
                    i <= i + 4'd1;
                end else begin
                    i <= 4'd0;
                    cl <= 4'd2;
                    state <= CL_LOOP;
                end
            end
            
            CL_LOOP: begin
                // for cl in range(2, n+1)
                if (cl <= len_reg) begin
                    i <= 4'd0;
                    state <= I_LOOP;
                end else begin
                    // Done with all loops, get final answer
                    if (len_reg >= 4'd1) begin
                        result <= L[0][len_reg-4'd1][3:0];
                    end else begin
                        result <= 4'd0;
                    end
                    state <= COMPLETE;
                end
            end
            
            I_LOOP: begin
                // for i in range(n-cl+1)
                if (i <= (len_reg - cl)) begin
                    j <= i + cl - 4'd1;
                    state <= GET_J;
                end else begin
                    cl <= cl + 4'd1;
                    state <= CL_LOOP;
                end
            end
            
            GET_J: begin
                // Get characters from input ports
                case (i)
                    4'd0: char_i <= str_0;
                    4'd1: char_i <= str_1;
                    4'd2: char_i <= str_2;
                    4'd3: char_i <= str_3;
                    4'd4: char_i <= str_4;
                    4'd5: char_i <= str_5;
                    4'd6: char_i <= str_6;
                    4'd7: char_i <= str_7;
                    default: char_i <= 8'd0;
                endcase
                case (j)
                    4'd0: char_j <= str_0;
                    4'd1: char_j <= str_1;
                    4'd2: char_j <= str_2;
                    4'd3: char_j <= str_3;
                    4'd4: char_j <= str_4;
                    4'd5: char_j <= str_5;
                    4'd6: char_j <= str_6;
                    4'd7: char_j <= str_7;
                    default: char_j <= 8'd0;
                endcase
                state <= CHECK_CHARS;
            end
            
            CHECK_CHARS: begin
                if (char_i == char_j) begin
                    state <= UPDATE_MATCH;
                end else begin
                    state <= UPDATE_DIFF;
                end
            end
            
            UPDATE_MATCH: begin
                // L[i][j] = 2 when cl == 2, else L[i+1][j-1] + 2
                if (cl == 4'd2) begin
                    L[i][j] <= 8'd2;
                end else begin
                    L[i][j] <= L[i+4'd1][j-4'd1] + 8'd2;
                end
                i <= i + 4'd1;
                state <= I_LOOP;
            end
            
            UPDATE_DIFF: begin
                // L[i][j] = max(L[i][j-1], L[i+1][j])
                if (L[i][j-4'd1] >= L[i+4'd1][j]) begin
                    L[i][j] <= L[i][j-4'd1];
                end else begin
                    L[i][j] <= L[i+4'd1][j];
                end
                i <= i + 4'd1;
                state <= I_LOOP;
            end
            
            COMPLETE: begin
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule