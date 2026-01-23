module LCS_Avoid_Virus (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] s1_char0,
    input wire [4:0] s1_char1,
    input wire [4:0] s1_char2,
    input wire [4:0] s1_char3,
    input wire [4:0] s2_char0,
    input wire [4:0] s2_char1,
    input wire [4:0] s2_char2,
    input wire [4:0] s2_char3,
    input wire [4:0] virus_char0,
    input wire [4:0] virus_char1,
    input wire [4:0] virus_char2,
    output reg [4:0] result_char0,
    output reg [4:0] result_char1,
    output reg [4:0] result_char2,
    output reg [4:0] result_char3,
    output reg [2:0] result_length,
    output reg done
);

// State definitions
localparam [2:0] IDLE = 3'd0;
localparam [2:0] INIT = 3'd1;
localparam [2:0] DP_ITER = 3'd2;
localparam [2:0] FIND_MAX = 3'd3;
localparam [2:0] BACKTRACK = 3'd4;
localparam [2:0] OUTPUT = 3'd5;

reg [2:0] state;

// Input registers
reg [4:0] s1_reg [0:3];
reg [4:0] s2_reg [0:3];
reg [4:0] virus_reg [0:2];

// KMP next array
reg [2:0] next0, next1, next2;

// DP table: [i][j][k]
reg [2:0] dp_len [0:4][0:4][0:3];
reg [2:0] dp_parent_i [0:4][0:4][0:3];
reg [2:0] dp_parent_j [0:4][0:4][0:3];
reg [2:0] dp_parent_k [0:4][0:4][0:3];
reg [4:0] dp_char [0:4][0:4][0:3];
reg dp_valid [0:4][0:4][0:3];

// Iteration counters
reg [2:0] i_ctr, j_ctr, k_ctr;
reg [2:0] max_len;
reg [2:0] max_i, max_j, max_k;

// Backtracking buffer
reg [4:0] temp_buffer [0:3];
reg [2:0] temp_idx;
reg [2:0] curr_i, curr_j, curr_k;

// KMP next computation helper
function automatic [2:0] kmp_next_state;
    input [2:0] current_k;
    input [4:0] char;
    begin
        kmp_next_state = 3'd0;
        case(current_k)
            3'd0: begin
                if(char == virus_reg[0]) kmp_next_state = 3'd1;
            end
            3'd1: begin
                if(char == virus_reg[1]) kmp_next_state = 3'd2;
                else if(char == virus_reg[0]) kmp_next_state = 3'd1;
                else kmp_next_state = 3'd0;
            end
            3'd2: begin
                if(char == virus_reg[2]) kmp_next_state = 3'd0;  // Full match - avoid
                else if(char == virus_reg[1]) kmp_next_state = 3'd2;
                else if(char == virus_reg[0]) kmp_next_state = 3'd1;
                else kmp_next_state = 3'd0;
            end
            default: kmp_next_state = 3'd0;
        endcase
    end
endfunction

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result_length <= 3'd0;
        result_char0 <= 5'd0;
        result_char1 <= 5'd0;
        result_char2 <= 5'd0;
        result_char3 <= 5'd0;
        i_ctr <= 3'd0;
        j_ctr <= 3'd0;
        k_ctr <= 3'd0;
        max_len <= 3'd0;
        max_i <= 3'd0;
        max_j <= 3'd0;
        max_k <= 3'd0;
        temp_idx <= 3'd0;
        curr_i <= 3'd0;
        curr_j <= 3'd0;
        curr_k <= 3'd0;
        next0 <= 3'd0;
        next1 <= 3'd0;
        next2 <= 3'd0;
    end else begin
        case(state)
            IDLE: begin
                done <= 1'b0;
                if(start) begin
                    state <= INIT;
                    s1_reg[0] <= s1_char0;
                    s1_reg[1] <= s1_char1;
                    s1_reg[2] <= s1_char2;
                    s1_reg[3] <= s1_char3;
                    s2_reg[0] <= s2_char0;
                    s2_reg[1] <= s2_char1;
                    s2_reg[2] <= s2_char2;
                    s2_reg[3] <= s2_char3;
                    virus_reg[0] <= virus_char0;
                    virus_reg[1] <= virus_char1;
                    virus_reg[2] <= virus_char2;
                end
            end

            INIT: begin
                // Initialize DP table and counters
                for(i_ctr = 3'd0; i_ctr < 5; i_ctr = i_ctr + 3'd1) begin
                    for(j_ctr = 3'd0; j_ctr < 5; j_ctr = j_ctr + 3'd1) begin
                        for(k_ctr = 3'd0; k_ctr < 4; k_ctr = k_ctr + 3'd1) begin
                            dp_valid[i_ctr][j_ctr][k_ctr] <= 1'b0;
                            dp_len[i_ctr][j_ctr][k_ctr] <= 3'd0;
                        end
                    end
                end
                dp_valid[0][0][0] <= 1'b1;
                dp_len[0][0][0] <= 3'd0;
                
                // Compute KMP next array
                next0 <= 3'd0;
                if(virus_reg[1] == virus_reg[0]) next1 <= 3'd1;
                else next1 <= 3'd0;
                
                if(virus_reg[2] == virus_reg[1]) next2 <= 3'd2;
                else if(virus_reg[2] == virus_reg[0]) next2 <= 3'd1;
                else next2 <= 3'd0;
                
                i_ctr <= 3'd0;
                j_ctr <= 3'd0;
                k_ctr <= 3'd0;
                state <= DP_ITER;
            end

            DP_ITER: begin
                if(i_ctr < 5 && j_ctr < 5 && k_ctr < 4) begin
                    if(dp_valid[i_ctr][j_ctr][k_ctr]) begin
                        // Skip s1[i]
                        if(i_ctr < 4) begin
                            if(!dp_valid[i_ctr+1][j_ctr][k_ctr] || 
                               dp_len[i_ctr][j_ctr][k_ctr] > dp_len[i_ctr+1][j_ctr][k_ctr]) begin
                                dp_len[i_ctr+1][j_ctr][k_ctr] <= dp_len[i_ctr][j_ctr][k_ctr];
                                dp_parent_i[i_ctr+1][j_ctr][k_ctr] <= i_ctr;
                                dp_parent_j[i_ctr+1][j_ctr][k_ctr] <= j_ctr;
                                dp_parent_k[i_ctr+1][j_ctr][k_ctr] <= k_ctr;
                                dp_char[i_ctr+1][j_ctr][k_ctr] <= 5'd0;
                                dp_valid[i_ctr+1][j_ctr][k_ctr] <= 1'b1;
                            end
                        end
                        
                        // Skip s2[j]
                        if(j_ctr < 4) begin
                            if(!dp_valid[i_ctr][j_ctr+1][k_ctr] || 
                               dp_len[i_ctr][j_ctr][k_ctr] > dp_len[i_ctr][j_ctr+1][k_ctr]) begin
                                dp_len[i_ctr][j_ctr+1][k_ctr] <= dp_len[i_ctr][j_ctr][k_ctr];
                                dp_parent_i[i_ctr][j_ctr+1][k_ctr] <= i_ctr;
                                dp_parent_j[i_ctr][j_ctr+1][k_ctr] <= j_ctr;
                                dp_parent_k[i_ctr][j_ctr+1][k_ctr] <= k_ctr;
                                dp_char[i_ctr][j_ctr+1][k_ctr] <= 5'd0;
                                dp_valid[i_ctr][j_ctr+1][k_ctr] <= 1'b1;
                            end
                        end
                        
                        // Match s1[i] and s2[j]
                        if(i_ctr < 4 && j_ctr < 4 && s1_reg[i_ctr] == s2_reg[j_ctr]) begin
                            reg [2:0] next_k;
                            next_k = kmp_next_state(k_ctr, s1_reg[i_ctr]);
                            
                            if(next_k < 3) begin
                                if(!dp_valid[i_ctr+1][j_ctr+1][next_k] || 
                                   dp_len[i_ctr][j_ctr][k_ctr] + 3'd1 > dp_len[i_ctr+1][j_ctr+1][next_k]) begin
                                    dp_len[i_ctr+1][j_ctr+1][next_k] <= dp_len[i_ctr][j_ctr][k_ctr] + 3'd1;
                                    dp_parent_i[i_ctr+1][j_ctr+1][next_k] <= i_ctr;
                                    dp_parent_j[i_ctr+1][j_ctr+1][next_k] <= j_ctr;
                                    dp_parent_k[i_ctr+1][j_ctr+1][next_k] <= k_ctr;
                                    dp_char[i_ctr+1][j_ctr+1][next_k] <= s1_reg[i_ctr];
                                    dp_valid[i_ctr+1][j_ctr+1][next_k] <= 1'b1;
                                end
                            end
                        end
                    end
                    
                    // Increment counters
                    if(k_ctr < 3) begin
                        k_ctr <= k_ctr + 3'd1;
                    end else begin
                        k_ctr <= 3'd0;
                        if(j_ctr < 4) begin
                            j_ctr <= j_ctr + 3'd1;
                        end else begin
                            j_ctr <= 3'd0;
                            i_ctr <= i_ctr + 3'd1;
                        end
                    end
                end else begin
                    state <= FIND_MAX;
                    max_len <= 3'd0;
                    max_i <= 3'd0;
                    max_j <= 3'd0;
                    max_k <= 3'd0;
                    i_ctr <= 3'd0;
                    j_ctr <= 3'd0;
                    k_ctr <= 3'd0;
                end
            end

            FIND_MAX: begin
                if(i_ctr < 5 && j_ctr < 5 && k_ctr < 4) begin
                    if(dp_valid[i_ctr][j_ctr][k_ctr] && dp_len[i_ctr][j_ctr][k_ctr] > max_len) begin
                        max_len <= dp_len[i_ctr][j_ctr][k_ctr];
                        max_i <= i_ctr;
                        max_j <= j_ctr;
                        max_k <= k_ctr;
                    end
                    
                    if(k_ctr < 3) begin
                        k_ctr <= k_ctr + 3'd1;
                    end else begin
                        k_ctr <= 3'd0;
                        if(j_ctr < 4) begin
                            j_ctr <= j_ctr + 3'd1;
                        end else begin
                            j_ctr <= 3'd0;
                            i_ctr <= i_ctr + 3'd1;
                        end
                    end
                end else begin
                    if(max_len == 3'd0) begin
                        state <= OUTPUT;
                        temp_idx <= 3'd0;
                    end else begin
                        state <= BACKTRACK;
                        curr_i <= max_i;
                        curr_j <= max_j;
                        curr_k <= max_k;
                        temp_idx <= 3'd0;
                    end
                end
            end

            BACKTRACK: begin
                if(temp_idx < 4 && !(curr_i == 3'd0 && curr_j == 3'd0 && curr_k == 3'd0)) begin
                    if(dp_char[curr_i][curr_j][curr_k] != 5'd0) begin
                        temp_buffer[temp_idx] <= dp_char[curr_i][curr_j][curr_k];
                        temp_idx <= temp_idx + 3'd1;
                    end
                    curr_i <= dp_parent_i[curr_i][curr_j][curr_k];
                    curr_j <= dp_parent_j[curr_i][curr_j][curr_k];
                    curr_k <= dp_parent_k[curr_i][curr_j][curr_k];
                end else begin
                    state <= OUTPUT;
                end
            end

            OUTPUT: begin
                result_length <= temp_idx;
                result_char0 <= (temp_idx > 3'd0) ? temp_buffer[0] : 5'd0;
                result_char1 <= (temp_idx > 3'd1) ? temp_buffer[1] : 5'd0;
                result_char2 <= (temp_idx > 3'd2) ? temp_buffer[2] : 5'd0;
                result_char3 <= (temp_idx > 3'd3) ? temp_buffer[3] : 5'd0;
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