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

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] READ    = 3'd1;
    localparam [2:0] COMPUTE_K = 3'd2;
    localparam [2:0] BUILD    = 3'd3;
    localparam [2:0] OUTPUT   = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state, next_state;
    reg [3:0] idx;
    reg [3:0] ctr [0:3];
    reg [3:0] odd_count;
    reg [7:0] temp_palindrome [0:15];
    reg [3:0] temp_idx;
    reg [1:0] char_idx;
    reg [3:0] loop_i;
    reg [3:0] loop_j;
    reg [3:0] build_idx;
    reg [3:0] output_idx;
    reg [7:0] temp_char;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            k <= 4'd0;
            idx <= 4'd0;
            odd_count <= 4'd0;
            temp_idx <= 4'd0;
            loop_i <= 4'd0;
            loop_j <= 4'd0;
            build_idx <= 4'd0;
            output_idx <= 4'd0;
            char_idx <= 2'd0;
            temp_char <= 8'd0;
            for (loop_i = 0; loop_i < 4; loop_i = loop_i + 1) begin
                ctr[loop_i] <= 4'd0;
            end
            for (loop_i = 0; loop_i < 16; loop_i = loop_i + 1) begin
                palindrome_len[loop_i] <= 4'd0;
                for (loop_j = 0; loop_j < 16; loop_j = loop_j + 1) begin
                    palindrome_mem[loop_i][loop_j] <= 8'd0;
                end
            end
            for (loop_i = 0; loop_i < 16; loop_i = loop_i + 1) begin
                temp_palindrome[loop_i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= READ;
                        idx <= 4'd0;
                        for (loop_i = 0; loop_i < 4; loop_i = loop_i + 1) begin
                            ctr[loop_i] <= 4'd0;
                        end
                    end
                end

                READ: begin
                    if (idx < len) begin
                        case (char_in)
                            8'h61: char_idx <= 2'd0;
                            8'h62: char_idx <= 2'd1;
                            8'h63: char_idx <= 2'd2;
                            8'h64: char_idx <= 2'd3;
                            default: char_idx <= 2'd0;
                        endcase
                        state <= COMPUTE_K;
                    end else begin
                        state <= COMPUTE_K;
                        idx <= 4'd0;
                    end
                end

                COMPUTE_K: begin
                    if (idx < len) begin
                        ctr[char_idx] <= ctr[char_idx] + 4'd1;
                        idx <= idx + 4'd1;
                        state <= READ;
                    end else begin
                        odd_count <= 4'd0;
                        for (loop_i = 0; loop_i < 4; loop_i = loop_i + 1) begin
                            if (ctr[loop_i][0]) begin
                                odd_count <= odd_count + 4'd1;
                            end
                        end
                        if (odd_count <= 4'd1) begin
                            k <= 4'd1;
                        end else begin
                            k <= len;
                        end
                        build_idx <= 4'd0;
                        temp_idx <= 4'd0;
                        output_idx <= 4'd0;
                        for (loop_i = 0; loop_i < 16; loop_i = loop_i + 1) begin
                            palindrome_len[loop_i] <= 4'd0;
                        end
                        state <= BUILD;
                    end
                end

                BUILD: begin
                    if (k == 4'd1) begin
                        if (build_idx < 4'd4) begin
                            if (ctr[build_idx] > 4'd0) begin
                                if (ctr[build_idx][0]) begin
                                    for (loop_j = 4'd0; loop_j < ((ctr[build_idx] - 4'd1) >> 1); loop_j = loop_j + 4'd1) begin
                                        if (temp_idx < 4'd16) begin
                                            case (build_idx)
                                                4'd0: temp_palindrome[temp_idx] <= 8'h61;
                                                4'd1: temp_palindrome[temp_idx] <= 8'h62;
                                                4'd2: temp_palindrome[temp_idx] <= 8'h63;
                                                4'd3: temp_palindrome[temp_idx] <= 8'h64;
                                                default: temp_palindrome[temp_idx] <= 8'h20;
                                            endcase
                                            temp_idx <= temp_idx + 4'd1;
                                        end
                                    end
                                end else begin
                                    for (loop_j = 4'd0; loop_j < (ctr[build_idx] >> 1); loop_j = loop_j + 4'd1) begin
                                        if (temp_idx < 4'd16) begin
                                            case (build_idx)
                                                4'd0: temp_palindrome[temp_idx] <= 8'h61;
                                                4'd1: temp_palindrome[temp_idx] <= 8'h62;
                                                4'd2: temp_palindrome[temp_idx] <= 8'h63;
                                                4'd3: temp_palindrome[temp_idx] <= 8'h64;
                                                default: temp_palindrome[temp_idx] <= 8'h20;
                                            endcase
                                            temp_idx <= temp_idx + 4'd1;
                                        end
                                    end
                                end
                            end
                            build_idx <= build_idx + 4'd1;
                        end else if (build_idx == 4'd4) begin
                            for (loop_i = 4'd0; loop_i < 4'd4; loop_i = loop_i + 4'd1) begin
                                if (ctr[loop_i][0]) begin
                                    if (temp_idx < 4'd16) begin
                                        case (loop_i)
                                            4'd0: temp_palindrome[temp_idx] <= 8'h61;
                                            4'd1: temp_palindrome[temp_idx] <= 8'h62;
                                            4'd2: temp_palindrome[temp_idx] <= 8'h63;
                                            4'd3: temp_palindrome[temp_idx] <= 8'h64;
                                            default: temp_palindrome[temp_idx] <= 8'h20;
                                        endcase
                                        temp_idx <= temp_idx + 4'd1;
                                    end
                                end
                            end
                            build_idx <= build_idx + 4'd1;
                        end else begin
                            if (temp_idx > 4'd0) begin
                                temp_idx <= temp_idx - 4'd1;
                                if (temp_idx > 4'd0) begin
                                    palindrome_mem[0][(temp_idx - 4'd1)] <= temp_palindrome[temp_idx - 4'd1];
                                end
                                build_idx <= build_idx + 4'd1;
                            end else begin
                                palindrome_len[0] <= 4'd16;
                                state <= OUTPUT;
                            end
                        end
                    end else begin
                        if (build_idx < len) begin
                            case (char_in)
                                8'h61: temp_char <= 8'h61;
                                8'h62: temp_char <= 8'h62;
                                8'h63: temp_char <= 8'h63;
                                8'h64: temp_char <= 8'h64;
                                default: temp_char <= 8'h20;
                            endcase
                            state <= OUTPUT;
                        end else begin
                            state <= OUTPUT;
                        end
                    end
                end

                OUTPUT: begin
                    if (k == 4'd1) begin
                        if (output_idx < 4'd16) begin
                            palindrome_mem[0][output_idx] <= temp_palindrome[output_idx];
                            output_idx <= output_idx + 4'd1;
                        end else begin
                            state <= DONE_STATE;
                        end
                    end else begin
                        if (build_idx < len) begin
                            if (output_idx < 4'd16) begin
                                palindrome_mem[build_idx][0] <= temp_char;
                                palindrome_len[build_idx] <= 4'd1;
                            end
                            build_idx <= build_idx + 4'd1;
                            output_idx <= output_idx + 4'd1;
                        end else begin
                            state <= DONE_STATE;
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule