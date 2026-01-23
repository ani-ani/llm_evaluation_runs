module lcs_permutations(
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [3:0] k,
    input [31:0] strings_in,
    input [2:0] str_idx,
    output reg [3:0] result,
    output reg done,
    output reg ready_for_next
);

    localparam IDLE = 3'd0;
    localparam INPUT_STRINGS = 3'd1;
    localparam BUILD_ORDERING = 3'd2;
    localparam COMPUTE_LCS = 3'd3;
    localparam OUTPUT_RESULT = 3'd4;

    reg [2:0] state;
    reg [2:0] input_counter;
    reg [2:0] current_str;
    reg [3:0] i, j, idx;

    reg [31:0] strings [0:5];
    reg [3:0] pos [0:5][0:8];
    reg [0:8] can_precede [0:8];
    reg [3:0] dp [0:8];
    reg [3:0] max_lcs;

    reg [3:0] pos_i_current, pos_j_current;
    reg can_precede_ij;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            ready_for_next <= 0;
            input_counter <= 0;
            current_str <= 0;
            i <= 0;
            j <= 0;
            idx <= 0;
            max_lcs <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= INPUT_STRINGS;
                        input_counter <= 0;
                        ready_for_next <= 1;
                    end
                end

                INPUT_STRINGS: begin
                    ready_for_next <= 0;
                    if (input_counter < n) begin
                        strings[input_counter] <= strings_in;
                        for (idx = 0; idx < 8; idx = idx + 1) begin
                            if (idx < k) begin
                                pos[input_counter][strings_in[idx*4 +: 4]] <= idx + 1;
                            end
                        end
                        input_counter <= input_counter + 1;
                        ready_for_next <= 1;
                        if (input_counter + 1 >= n) begin
                            ready_for_next <= 0;
                            state <= BUILD_ORDERING;
                            current_str <= 0;
                            i <= 1;
                            j <= 1;
                        end
                    end
                end

                BUILD_ORDERING: begin
                    if (current_str < n) begin
                        if (i <= k && j <= k && i != j) begin
                            if (pos[current_str][i] < pos[current_str][j]) begin
                                can_precede[i][j] <= can_precede[i][j] && 1'b1;
                            end else begin
                                can_precede[i][j] <= 0;
                            end
                        end
                        if (j > k) begin
                            j <= 1;
                            if (i > k) begin
                                i <= 1;
                                current_str <= current_str + 1;
                            end else begin
                                i <= i + 1;
                            end
                        end else begin
                            j <= j + 1;
                        end
                    end else begin
                        state <= COMPUTE_LCS;
                        i <= 1;
                        j <= 1;
                        for (idx = 1; idx <= 8; idx = idx + 1) begin
                            dp[idx] <= 0;
                        end
                    end
                end

                COMPUTE_LCS: begin
                    if (i <= k) begin
                        if (j <= k) begin
                            if (can_precede[j][i] && (dp[j] + 1 > dp[i])) begin
                                dp[i] <= dp[j] + 1;
                            end
                            j <= j + 1;
                        end else begin
                            if (dp[i] == 0) dp[i] <= 1;
                            i <= i + 1;
                            j <= 1;
                        end
                    end else begin
                        max_lcs <= 0;
                        for (i = 1; i <= k; i = i + 1) begin
                            if (dp[i] > max_lcs) max_lcs <= dp[i];
                        end
                        state <= OUTPUT_RESULT;
                    end
                end

                OUTPUT_RESULT: begin
                    result <= max_lcs;
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule