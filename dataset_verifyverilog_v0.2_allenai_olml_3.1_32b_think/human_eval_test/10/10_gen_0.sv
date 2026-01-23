module make_palindrome (
    input clk,
    input rst_n,
    input start,
    input [4:0] str_len,
    input [15:0][7:0] str_data,
    output reg [4:0] result_len,
    output reg [31:0][7:0] result_data,
    output reg done
);

    reg [3:0] state;
    reg [4:0] suffix_len;
    reg [4:0] s_candidate;
    reg [4:0] prefix_len;
    reg [31:0][7:0] result_data_reg;
    reg [4:0] result_len_reg;
    reg done_reg;

    localparam IDLE = 3'd0;
    localparam FIND_SUFFIX = 3'd1;
    localparam BUILD_RESULT = 3'd2;
    localparam DONE_STATE = 3'd3;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            suffix_len <= 0;
            s_candidate <= 0;
            prefix_len <= 0;
            result_data_reg <= 0;
            result_len_reg <= 0;
            done_reg <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        if (str_len == 0) begin
                            state <= DONE_STATE;
                            done_reg <= 1;
                            result_len_reg <= 0;
                            result_data_reg <= 0;
                        end else begin
                            state <= FIND_SUFFIX;
                            s_candidate <= str_len;
                        end
                    end else begin
                        state <= IDLE;
                    end
                end
                FIND_SUFFIX: begin
                    if (s_candidate == 0) begin
                        suffix_len <= 0;
                        state <= BUILD_RESULT;
                    end else begin
                        if (s_candidate == 1) begin
                            suffix_len <= 1;
                            state <= BUILD_RESULT;
                        end else begin
                            s_candidate <= s_candidate - 1;
                            state <= FIND_SUFFIX;
                        end
                    end
                end
                BUILD_RESULT: begin
                    prefix_len = str_len - suffix_len;
                    result_len <= str_len + prefix_len;
                    for (int i=0; i<32; i++) begin
                        if (i < str_len) begin
                            result_data[i] <= str_data[i];
                        end else begin
                            int char_index = 2*str_len - suffix_len -1 -i;
                            if (char_index >=0 && char_index < str_len) begin
                                result_data[i] <= str_data[char_index];
                            end else begin
                                result_data[i] <= 0;
                            end
                        end
                    end
                    state <= DONE_STATE;
                    done_reg <= 1;
                    result_data_reg <= result_data;
                    result_len_reg <= result_len;
                end
                DONE_STATE: begin
                    state <= DONE_STATE;
                    done_reg <= 1;
                    result_data_reg <= result_data;
                    result_len_reg <= result_len;
                end
            endcase
        end
    end

    assign result_len = result_len_reg;
    assign result_data = result_data_reg;
    assign done = done_reg;
endmodule