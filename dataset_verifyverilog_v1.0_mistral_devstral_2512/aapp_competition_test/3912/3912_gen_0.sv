module palindrome_cutter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire [3:0] len,
    output reg [3:0] k,
    output reg [7:0] palindrome_mem [0:15][0:15],
    output reg [3:0] palindrome_len [0:15],
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] READ = 3'd1;
    localparam [2:0] COMPUTE_K = 3'd2;
    localparam [2:0] BUILD = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;

    reg [2:0] state;
    reg [3:0] idx;
    reg [3:0] ctr [0:3];
    reg [3:0] odd_count;
    reg [7:0] temp_palindrome [0:15];
    reg [3:0] temp_idx;
    reg [1:0] char_idx;

    function [1:0] char_to_idx(input [7:0] c);
        case(c)
            8'h61: char_to_idx = 2'd0;
            8'h62: char_to_idx = 2'd1;
            8'h63: char_to_idx = 2'd2;
            8'h64: char_to_idx = 2'd3;
            default: char_to_idx = 2'd0;
        endcase
    endfunction

    function [7:0] idx_to_char(input [1:0] i);
        case(i)
            2'd0: idx_to_char = 8'h61;
            2'd1: idx_to_char = 8'h62;
            2'd2: idx_to_char = 8'h63;
            2'd3: idx_to_char = 8'h64;
            default: idx_to_char = 8'h20;
        endcase
    endfunction

    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            k <= 4'd0;
            for (i = 0; i < 4; i = i + 1) ctr[i] <= 4'd0;
            for (i = 0; i < 16; i = i + 1) palindrome_len[i] <= 4'd0;
            idx <= 4'd0;
            temp_idx <= 4'd0;
            odd_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= READ;
                        idx <= 4'd0;
                        for (i = 0; i < 4; i = i + 1) ctr[i] <= 4'd0;
                    end
                end

                READ: begin
                    if (idx < len) begin
                        char_idx <= char_to_idx(char_in);
                        ctr[char_to_idx(char_in)] <= ctr[char_to_idx(char_in)] + 4'd1;
                        idx <= idx + 4'd1;
                    end else begin
                        state <= COMPUTE_K;
                        idx <= 4'd0;
                    end
                end

                COMPUTE_K: begin
                    odd_count <= 4'd0;
                    for (i = 0; i < 4; i = i + 1) begin
                        if (ctr[i][0]) odd_count <= odd_count + 4'd1;
                    end
                    if (odd_count <= 4'd1) k <= 4'd1;
                    else k <= len;
                    state <= BUILD;
                    idx <= 4'd0;
                    temp_idx <= 4'd0;
                    for (i = 0; i < 16; i = i + 1) palindrome_len[i] <= 4'd0;
                end

                BUILD: begin
                    if (k == 4'd1) begin
                        if (idx < 4'd4) begin
                            if (ctr[idx] > 4'd0) begin
                                if (ctr[idx][0]) begin
                                    for (j = 0; j < (ctr[idx] - 4'd1) / 4'd2; j = j + 1) begin
                                        if (temp_idx < 4'd16) begin
                                            temp_palindrome[temp_idx] <= idx_to_char(idx);
                                            temp_idx <= temp_idx + 4'd1;
                                        end
                                    end
                                end else begin
                                    for (j = 0; j < ctr[idx] / 4'd2; j = j + 1) begin
                                        if (temp_idx < 4'd16) begin
                                            temp_palindrome[temp_idx] <= idx_to_char(idx);
                                            temp_idx <= temp_idx + 4'd1;
                                        end
                                    end
                                end
                            end
                            idx <= idx + 4'd1;
                        end else if (idx == 4'd4) begin
                            for (i = 0; i < 4; i = i + 1) begin
                                if (ctr[i][0]) begin
                                    if (temp_idx < 4'd16) begin
                                        temp_palindrome[temp_idx] <= idx_to_char(i);
                                        temp_idx <= temp_idx + 4'd1;
                                    end
                                end
                            end
                            idx <= idx + 4'd1;
                        end else begin
                            if (temp_idx > 4'd0) begin
                                temp_idx <= temp_idx - 4'd1;
                                if (temp_idx - 4'd1 >= 4'd0) begin
                                    palindrome_mem[0][16 - (idx - 5)] <= temp_palindrome[temp_idx - 4'd1];
                                end
                                idx <= idx + 4'd1;
                            end else begin
                                palindrome_len[0] <= 16 - (idx - 5);
                                state <= OUTPUT;
                            end
                        end
                    end else begin
                        if (idx < len) begin
                            palindrome_mem[idx][0] <= char_in;
                            palindrome_len[idx] <= 4'd1;
                            idx <= idx + 4'd1;
                        end else begin
                            state <= OUTPUT;
                        end
                    end
                end

                OUTPUT: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule