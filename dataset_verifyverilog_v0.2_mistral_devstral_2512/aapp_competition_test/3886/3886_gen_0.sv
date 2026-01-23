module nephren_solver (
    input clk,
    input rst_n,
    input start,
    input [19:0] n_in,
    input [59:0] k_in,
    output reg [7:0] char_out,
    output reg done
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        PROCESSING,
        DONE
    } state_t;

    state_t state;
    reg [19:0] n_reg;
    reg [59:0] k_reg;
    reg [59:0] f_len_reg;
    reg [59:0] f_len_prev;

    // Precomputed string lengths
    localparam len_base = 75;
    localparam len_prefix = 34;
    localparam len_mid = 32;
    localparam len_suffix = 2;

    // ROM for strings
    reg [7:0] f0_rom [0:74];
    reg [7:0] prefix_rom [0:33];
    reg [7:0] mid_rom [0:31];
    reg [7:0] suffix_rom [0:1];

    // Initialize ROMs
    initial begin
        // f0_rom initialization
        f0_rom[0] = "W"; f0_rom[1] = "h"; f0_rom[2] = "a"; f0_rom[3] = "t"; f0_rom[4] = " ";
        f0_rom[5] = "a"; f0_rom[6] = "r"; f0_rom[7] = "e"; f0_rom[8] = " "; f0_rom[9] = "y";
        f0_rom[10] = "o"; f0_rom[11] = "u"; f0_rom[12] = " "; f0_rom[13] = "d"; f0_rom[14] = "o";
        f0_rom[15] = "i"; f0_rom[16] = "n"; f0_rom[17] = "g"; f0_rom[18] = " "; f0_rom[19] = "a";
        f0_rom[20] = "t"; f0_rom[21] = " "; f0_rom[22] = "t"; f0_rom[23] = "h"; f0_rom[24] = "e";
        f0_rom[25] = " "; f0_rom[26] = "e"; f0_rom[27] = "n"; f0_rom[28] = "d"; f0_rom[29] = " ";
        f0_rom[30] = "o"; f0_rom[31] = "f"; f0_rom[32] = " "; f0_rom[33] = "t"; f0_rom[34] = "h";
        f0_rom[35] = "e"; f0_rom[36] = " "; f0_rom[37] = "w"; f0_rom[38] = "o"; f0_rom[39] = "r";
        f0_rom[40] = "l"; f0_rom[41] = "d"; f0_rom[42] = "?"; f0_rom[43] = " "; f0_rom[44] = "A";
        f0_rom[45] = "r"; f0_rom[46] = "e"; f0_rom[47] = " "; f0_rom[48] = "y"; f0_rom[49] = "o";
        f0_rom[50] = "u"; f0_rom[51] = " "; f0_rom[52] = "b"; f0_rom[53] = "u"; f0_rom[54] = "s";
        f0_rom[55] = "y"; f0_rom[56] = "?"; f0_rom[57] = " "; f0_rom[58] = "W"; f0_rom[59] = "i";
        f0_rom[60] = "l"; f0_rom[61] = "l"; f0_rom[62] = " "; f0_rom[63] = "y"; f0_rom[64] = "o";
        f0_rom[65] = "u"; f0_rom[66] = " "; f0_rom[67] = "s"; f0_rom[68] = "a"; f0_rom[69] = "v";
        f0_rom[70] = "e"; f0_rom[71] = " "; f0_rom[72] = "u"; f0_rom[73] = "s"; f0_rom[74] = "?";

        // prefix_rom initialization
        prefix_rom[0] = "W"; prefix_rom[1] = "h"; prefix_rom[2] = "a"; prefix_rom[3] = "t"; prefix_rom[4] = " ";
        prefix_rom[5] = "a"; prefix_rom[6] = "r"; prefix_rom[7] = "e"; prefix_rom[8] = " "; prefix_rom[9] = "y";
        prefix_rom[10] = "o"; prefix_rom[11] = "u"; prefix_rom[12] = " "; prefix_rom[13] = "d"; prefix_rom[14] = "o";
        prefix_rom[15] = "i"; prefix_rom[16] = "n"; prefix_rom[17] = "g"; prefix_rom[18] = " "; prefix_rom[19] = "w";
        prefix_rom[20] = "h"; prefix_rom[21] = "i"; prefix_rom[22] = "l"; prefix_rom[23] = "e"; prefix_rom[24] = " ";
        prefix_rom[25] = "s"; prefix_rom[26] = "e"; prefix_rom[27] = "n"; prefix_rom[28] = "d"; prefix_rom[29] = "i";
        prefix_rom[30] = "n"; prefix_rom[31] = "g"; prefix_rom[32] = " "; prefix_rom[33] = "\"";

        // mid_rom initialization
        mid_rom[0] = "\""; mid_rom[1] = "?"; mid_rom[2] = " "; mid_rom[3] = "A"; mid_rom[4] = "r";
        mid_rom[5] = "e"; mid_rom[6] = " "; mid_rom[7] = "y"; mid_rom[8] = "o"; mid_rom[9] = "u";
        mid_rom[10] = " "; mid_rom[11] = "b"; mid_rom[12] = "u"; mid_rom[13] = "s"; mid_rom[14] = "y";
        mid_rom[15] = "?"; mid_rom[16] = " "; mid_rom[17] = "W"; mid_rom[18] = "i"; mid_rom[19] = "l";
        mid_rom[20] = "l"; mid_rom[21] = " "; mid_rom[22] = "y"; mid_rom[23] = "o"; mid_rom[24] = "u";
        mid_rom[25] = " "; mid_rom[26] = "s"; mid_rom[27] = "e"; mid_rom[28] = "n"; mid_rom[29] = "d";
        mid_rom[30] = " "; mid_rom[31] = "\"";

        // suffix_rom initialization
        suffix_rom[0] = "\""; suffix_rom[1] = "?";
    end

    // Compute f_len for given n
    function automatic [59:0] compute_f_len(input [19:0] n);
        reg [59:0] len;
        integer i;
        begin
            if (n == 0) begin
                len = len_base;
            end else if (n > 55) begin
                len = 60'hFFFFFFFFFFFFFFFFF; // Treat as infinite
            end else begin
                len = len_base;
                for (i = 1; i <= n; i = i + 1) begin
                    if (len > 60'hFFFFFFFFFFFFFFFFF - 68) begin
                        len = 60'hFFFFFFFFFFFFFFFFF;
                    end else begin
                        len = len * 2 + 68;
                    end
                end
            end
            return len;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            n_reg <= 0;
            k_reg <= 0;
            f_len_reg <= 0;
            f_len_prev <= 0;
            char_out <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PROCESSING;
                        n_reg <= n_in;
                        k_reg <= k_in;
                        f_len_reg <= compute_f_len(n_in);
                        f_len_prev <= compute_f_len(n_in - 1);
                    end
                end

                PROCESSING: begin
                    if (n_reg == 0) begin
                        if (k_reg <= len_base) begin
                            char_out <= f0_rom[k_reg - 1];
                        end else begin
                            char_out <= ".";
                        end
                        state <= DONE;
                        done <= 1;
                    end else begin
                        if (k_reg <= len_prefix) begin
                            char_out <= prefix_rom[k_reg - 1];
                            state <= DONE;
                            done <= 1;
                        end else begin
                            k_reg <= k_reg - len_prefix;
                            if (f_len_prev >= k_reg) begin
                                n_reg <= n_reg - 1;
                                f_len_reg <= f_len_prev;
                                f_len_prev <= compute_f_len(n_reg - 1);
                            end else begin
                                k_reg <= k_reg - f_len_prev;
                                if (k_reg <= len_mid) begin
                                    char_out <= mid_rom[k_reg - 1];
                                    state <= DONE;
                                    done <= 1;
                                end else begin
                                    k_reg <= k_reg - len_mid;
                                    if (f_len_prev >= k_reg) begin
                                        n_reg <= n_reg - 1;
                                        f_len_reg <= f_len_prev;
                                        f_len_prev <= compute_f_len(n_reg - 1);
                                    end else begin
                                        k_reg <= k_reg - f_len_prev;
                                        if (k_reg <= len_suffix) begin
                                            char_out <= suffix_rom[k_reg - 1];
                                            state <= DONE;
                                            done <= 1;
                                        end else begin
                                            char_out <= ".";
                                            state <= DONE;
                                            done <= 1;
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                DONE: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule