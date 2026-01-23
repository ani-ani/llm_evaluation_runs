module lps(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] str_0, str_1, str_2, str_3, str_4, str_5, str_6, str_7,
    input wire [3:0] str_len,
    output reg [3:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT_DIAG = 3'd1;
    localparam [2:0] CL_LOOP = 3'd2;
    localparam [2:0] I_LOOP = 3'd3;
    localparam [2:0] CHECK_CHARS = 3'd4;
    localparam [2:0] COMPLETE = 3'd5;

    // Internal registers
    reg [2:0] state;
    reg [3:0] i, j, cl;
    reg [7:0] L [0:7][0:7];  // 8x8 matrix for DP table
    reg [3:0] len_reg;
    reg [7:0] char_i, char_j;

    // Character lookup
    always @(*) begin
        case (i)
            4'd0: char_i = str_0;
            4'd1: char_i = str_1;
            4'd2: char_i = str_2;
            4'd3: char_i = str_3;
            4'd4: char_i = str_4;
            4'd5: char_i = str_5;
            4'd6: char_i = str_6;
            4'd7: char_i = str_7;
            default: char_i = 8'd0;
        endcase

        case (j)
            4'd0: char_j = str_0;
            4'd1: char_j = str_1;
            4'd2: char_j = str_2;
            4'd3: char_j = str_3;
            4'd4: char_j = str_4;
            4'd5: char_j = str_5;
            4'd6: char_j = str_6;
            4'd7: char_j = str_7;
            default: char_j = 8'd0;
        endcase
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            cl <= 4'd0;
            len_reg <= 4'd0;
            // Initialize matrix
            integer r, c;
            for (r = 0; r < 8; r = r + 1) begin
                for (c = 0; c < 8; c = c + 1) begin
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
                    if (i < len_reg) begin
                        L[i][i] <= 8'd1;
                        i <= i + 1;
                    end else begin
                        i <= 4'd0;
                        cl <= 4'd2;
                        state <= CL_LOOP;
                    end
                end

                CL_LOOP: begin
                    if (cl <= len_reg) begin
                        i <= 4'd0;
                        state <= I_LOOP;
                    end else begin
                        if (len_reg >= 1) begin
                            result <= L[0][len_reg-1][3:0];
                        end else begin
                            result <= 4'd0;
                        end
                        state <= COMPLETE;
                    end
                end

                I_LOOP: begin
                    if (i <= (len_reg - cl)) begin
                        j <= i + cl - 1;
                        state <= CHECK_CHARS;
                    end else begin
                        cl <= cl + 1;
                        state <= CL_LOOP;
                    end
                end

                CHECK_CHARS: begin
                    if (char_i == char_j) begin
                        if (cl == 2) begin
                            L[i][j] <= 8'd2;
                        end else begin
                            L[i][j] <= L[i+1][j-1] + 8'd2;
                        end
                    end else begin
                        if (L[i][j-1] >= L[i+1][j]) begin
                            L[i][j] <= L[i][j-1];
                        end else begin
                            L[i][j] <= L[i+1][j];
                        end
                    end
                    i <= i + 1;
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