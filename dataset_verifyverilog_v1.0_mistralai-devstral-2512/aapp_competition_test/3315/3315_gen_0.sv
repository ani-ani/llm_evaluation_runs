module MaxSubsequenceLength(
    input clk,
    input rst_n,
    input start,
    input [4:0] strings_in [0:15][0:15],
    input [15:0] valid_inputs,
    output reg [5:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Internal registers
    reg [15:0] dp [0:15];
    reg [15:0] adj_matrix [0:15];
    reg [3:0] i_reg, j_reg, k_reg;
    reg [3:0] N_reg;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 6'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize dp and adj_matrix
            for (i_reg = 0; i_reg < 16; i_reg = i_reg + 1) begin
                dp[i_reg] <= 16'd0;
                for (j_reg = 0; j_reg < 16; j_reg = j_reg + 1) begin
                    adj_matrix[i_reg][j_reg] <= 1'b0;
                end
            end
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            k_reg <= 4'd0;
            N_reg <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        // Count number of valid strings
                        N_reg <= 4'd0;
                        for (i_reg = 0; i_reg < 16; i_reg = i_reg + 1) begin
                            if (valid_inputs[i_reg]) begin
                                N_reg <= N_reg + 4'd1;
                            end
                        end
                        i_reg <= 4'd0;
                        j_reg <= 4'd0;
                        k_reg <= 4'd0;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Build adjacency matrix
                    if (i_reg < N_reg) begin
                        if (j_reg < N_reg) begin
                            if (i_reg != j_reg && valid_inputs[i_reg] && valid_inputs[j_reg]) begin
                                // Check if string j starts with string i and ends with string i
                                reg [4:0] str_i_first = strings_in[i_reg][0];
                                reg [4:0] str_i_last = strings_in[i_reg][0];
                                reg [4:0] str_j_first = strings_in[j_reg][0];
                                reg [4:0] str_j_last = strings_in[j_reg][0];
                                
                                // Find last non-zero character in string i
                                reg [3:0] len_i = 4'd0;
                                for (k_reg = 0; k_reg < 16; k_reg = k_reg + 1) begin
                                    if (strings_in[i_reg][k_reg] != 5'd0) begin
                                        len_i = k_reg + 4'd1;
                                    end
                                end
                                
                                // Find first non-zero character in string j
                                reg [3:0] len_j = 4'd0;
                                for (k_reg = 0; k_reg < 16; k_reg = k_reg + 1) begin
                                    if (strings_in[j_reg][k_reg] != 5'd0) begin
                                        len_j = k_reg + 4'd1;
                                    end
                                end
                                
                                // Check prefix and suffix
                                reg prefix_match = 1'b1;
                                reg suffix_match = 1'b1;
                                
                                // Check prefix: string j starts with string i
                                for (k_reg = 0; k_reg < len_i; k_reg = k_reg + 1) begin
                                    if (strings_in[j_reg][k_reg] != strings_in[i_reg][k_reg]) begin
                                        prefix_match = 1'b0;
                                    end
                                end
                                
                                // Check suffix: string j ends with string i
                                for (k_reg = 0; k_reg < len_i; k_reg = k_reg + 1) begin
                                    if (strings_in[j_reg][len_j - 1 - k_reg] != strings_in[i_reg][len_i - 1 - k_reg]) begin
                                        suffix_match = 1'b0;
                                    end
                                end
                                
                                if (prefix_match && suffix_match) begin
                                    adj_matrix[i_reg][j_reg] <= 1'b1;
                                end else begin
                                    adj_matrix[i_reg][j_reg] <= 1'b0;
                                end
                            end
                            j_reg <= j_reg + 4'd1;
                        end else begin
                            j_reg <= 4'd0;
                            i_reg <= i_reg + 4'd1;
                        end
                    end else if (i_reg == N_reg && j_reg == 4'd0) begin
                        // Compute longest path using DP
                        for (i_reg = 0; i_reg < N_reg; i_reg = i_reg + 1) begin
                            dp[i_reg] <= 16'd1; // Each node has at least length 1
                        end
                        
                        for (i_reg = 0; i_reg < N_reg; i_reg = i_reg + 1) begin
                            for (j_reg = 0; j_reg < N_reg; j_reg = j_reg + 1) begin
                                if (adj_matrix[i_reg][j_reg]) begin
                                    if (dp[j_reg] < dp[i_reg] + 16'd1) begin
                                        dp[j_reg] <= dp[i_reg] + 16'd1;
                                    end
                                end
                            end
                        end
                        
                        // Find maximum value in dp
                        result <= 6'd0;
                        for (i_reg = 0; i_reg < N_reg; i_reg = i_reg + 1) begin
                            if (dp[i_reg] > result) begin
                                result <= dp[i_reg];
                            end
                        end
                        
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule