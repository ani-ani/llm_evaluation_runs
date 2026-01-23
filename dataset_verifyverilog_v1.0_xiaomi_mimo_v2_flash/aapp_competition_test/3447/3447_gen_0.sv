module t9_keypress #(
    parameter DICT_SIZE = 8,
    parameter MAX_WORD_LEN = 8,
    parameter MAX_QUERY_LEN = 16
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] dict_words [0:DICT_SIZE-1][0:MAX_WORD_LEN-1],
    input wire [3:0] dict_lengths [0:DICT_SIZE-1],
    input wire [7:0] query_word [0:MAX_QUERY_LEN-1],
    input wire [4:0] query_length,
    output reg [7:0] key_sequence [0:255],
    output reg [7:0] key_count,
    output reg done
);

    // T9 mapping lookup function
    function automatic [3:0] char_to_digit(input [7:0] c);
        case (c)
            8'h61, 8'h62, 8'h63: char_to_digit = 4'd2;  // a, b, c -> 2
            8'h64, 8'h65, 8'h66: char_to_digit = 4'd3;  // d, e, f -> 3
            8'h67, 8'h68, 8'h69: char_to_digit = 4'd4;  // g, h, i -> 4
            8'h6a, 8'h6b, 8'h6c: char_to_digit = 4'd5;  // j, k, l -> 5
            8'h6d, 8'h6e, 8'h6f: char_to_digit = 4'd6;  // m, n, o -> 6
            8'h70, 8'h71, 8'h72, 8'h73: char_to_digit = 4'd7;  // p, q, r, s -> 7
            8'h74, 8'h75, 8'h76: char_to_digit = 4'd8;  // t, u, v -> 8
            8'h77, 8'h78, 8'h79, 8'h7a: char_to_digit = 4'd9;  // w, x, y, z -> 9
            default: char_to_digit = 4'd0;
        endcase
    endfunction

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_COSTS = 3'd1;
    localparam [2:0] DP_COMPUTE = 3'd2;
    localparam [2:0] BACKTRACK = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Internal registers
    reg [2:0] state;
    reg [4:0] i_idx, j_idx, k_idx;
    reg [7:0] out_buf [0:255];
    reg [7:0] out_len;
    reg [7:0] output_idx;
    reg [31:0] word_costs [0:DICT_SIZE-1];
    reg [3:0] word_digit_seqs [0:DICT_SIZE-1][0:MAX_WORD_LEN-1];
    reg [31:0] dp [0:MAX_QUERY_LEN];
    reg [31:0] dp_prev [0:MAX_QUERY_LEN];
    reg [31:0] dp_word_idx [0:MAX_QUERY_LEN];
    reg [31:0] backtrack_idx;
    reg [31:0] current_cost;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            key_count <= 8'd0;
            out_len <= 8'd0;
            i_idx <= 5'd0;
            j_idx <= 5'd0;
            k_idx <= 5'd0;
            output_idx <= 8'd0;
            backtrack_idx <= 32'd0;
            current_cost <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE_COSTS;
                        i_idx <= 5'd0;
                        j_idx <= 5'd0;
                        out_len <= 8'd0;
                    end
                end

                COMPUTE_COSTS: begin
                    if (i_idx < DICT_SIZE) begin
                        if (j_idx < dict_lengths[i_idx]) begin
                            word_digit_seqs[i_idx][j_idx] <= char_to_digit(dict_words[i_idx][j_idx]);
                            j_idx <= j_idx + 5'd1;
                        end else begin
                            word_costs[i_idx] <= dict_lengths[i_idx];
                            i_idx <= i_idx + 5'd1;
                            j_idx <= 5'd0;
                        end
                    end else begin
                        state <= DP_COMPUTE;
                        i_idx <= 5'd0;
                        j_idx <= 5'd0;
                    end
                end

                DP_COMPUTE: begin
                    if (i_idx <= query_length) begin
                        if (j_idx < DICT_SIZE) begin
                            if (i_idx + dict_lengths[j_idx] <= query_length) begin
                                current_cost <= dp[i_idx] + word_costs[j_idx] + ((i_idx > 0) ? 32'd1 : 32'd0);
                                if (dp[i_idx] + word_costs[j_idx] + ((i_idx > 0) ? 32'd1 : 32'd0) < dp[i_idx + dict_lengths[j_idx]] || dp[i_idx + dict_lengths[j_idx]] == 32'd0) begin
                                    dp[i_idx + dict_lengths[j_idx]] <= dp[i_idx] + word_costs[j_idx] + ((i_idx > 0) ? 32'd1 : 32'd0);
                                    dp_prev[i_idx + dict_lengths[j_idx]] <= i_idx;
                                    dp_word_idx[i_idx + dict_lengths[j_idx]] <= j_idx;
                                end
                            end
                            j_idx <= j_idx + 5'd1;
                        end else begin
                            j_idx <= 5'd0;
                            i_idx <= i_idx + 5'd1;
                        end
                    end else begin
                        state <= BACKTRACK;
                        backtrack_idx <= query_length;
                        out_len <= 8'd0;
                    end
                end

                BACKTRACK: begin
                    if (backtrack_idx > 0) begin
                        if (out_len < 8'd250) begin
                            if (k_idx < dict_lengths[dp_word_idx[backtrack_idx]]) begin
                                out_buf[out_len] <= word_digit_seqs[dp_word_idx[backtrack_idx]][k_idx] + 8'h30;
                                out_len <= out_len + 8'd1;
                                k_idx <= k_idx + 5'd1;
                            end else begin
                                k_idx <= 5'd0;
                                if (dp_prev[backtrack_idx] > 0) begin
                                    out_buf[out_len] <= 8'h52;  // 'R'
                                    out_len <= out_len + 8'd1;
                                end
                                backtrack_idx <= dp_prev[backtrack_idx];
                            end
                        end else begin
                            state <= OUTPUT;
                            output_idx <= 8'd0;
                        end
                    end else begin
                        state <= OUTPUT;
                        output_idx <= 8'd0;
                    end
                end

                OUTPUT: begin
                    if (output_idx < out_len) begin
                        key_sequence[output_idx] <= out_buf[output_idx];
                        output_idx <= output_idx + 8'd1;
                    end else begin
                        key_count <= out_len;
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
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