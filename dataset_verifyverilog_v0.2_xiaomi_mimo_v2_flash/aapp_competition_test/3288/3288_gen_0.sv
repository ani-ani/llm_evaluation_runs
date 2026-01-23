module k_incremental_double_free (
    input clk,
    input rst_n,
    input start,
    input [5:0] k_in,
    input [63:0] n_in,
    output reg [7:0] char_out,
    output reg char_valid,
    output reg done,
    output reg error
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam CHECK = 3'b001;
    localparam FIND_PAIR = 3'b010;
    localparam STREAM = 3'b011;
    localparam FINISHED = 3'b100;

    reg [2:0] state;
    reg [63:0] n_reg;
    reg [63:0] temp_rem;
    reg [7:0] char1_idx;
    reg [7:0] char2_idx;
    reg [7:0] stream_pos;
    reg str_type;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            char_valid <= 0;
            done <= 0;
            error <= 0;
            char_out <= 8'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    error <= 0;
                    char_valid <= 0;
                    if (start) begin
                        // Constraints for k=2: Total strings = 650
                        if (k_in != 2) begin
                            error <= 1;
                            state <= FINISHED;
                        end else if (n_in < 1 || n_in > 650) begin
                            error <= 1;
                            state <= FINISHED;
                        end else begin
                            n_reg <= n_in;
                            state <= CHECK;
                        end
                    end
                end

                CHECK: begin
                    // Initialize pair finding loop
                    // n_reg is 1-based. Pair index is 0-based.
                    temp_rem <= n_reg - 1;
                    char1_idx <= 0;
                    state <= FIND_PAIR;
                end

                FIND_PAIR: begin
                    // Loop to find character indices for the pair
                    // Valid pairs are (0,1), (0,2) ... (0,25), (1,2) ... (24,25)
                    // Total 325 pairs.
                    // For a given char1_idx 'x', there are (25 - x) pairs starting with it.
                    // If temp_rem >= (25 - char1_idx), we subtract and increment char1_idx.
                    // Else, char2_idx = char1_idx + 1 + temp_rem.
                    
                    if ((25 - char1_idx) <= temp_rem) begin
                        temp_rem <= temp_rem - (25 - char1_idx);
                        char1_idx <= char1_idx + 1;
                    end else begin
                        // Found char1_idx
                        char2_idx <= char1_idx + 1 + temp_rem;
                        // Determine string type: Even index (n-1) is type 0 (xyx), Odd is type 1 (yxy)
                        str_type <= (n_reg[0]);
                        stream_pos <= 0;
                        state <= STREAM;
                    end
                end

                STREAM: begin
                    // Stream the 3 characters of the constructed string
                    // Type 0 (xyx): x, y, x (output indices: 1, 2, 1)
                    // Type 1 (yxy): y, x, y (output indices: 2, 1, 2)
                    // Note: char1_idx maps to 'a' + idx, char2_idx maps to 'a' + idx
                    // We need to be careful with the mapping.
                    // Type 0 uses char1_idx (x) and char2_idx (y).
                    // Type 1 uses char2_idx (y) and char1_idx (x).
                    // Wait, the problem says "xyx" and "yxy" where x<y.
                    // So char1_idx is x, char2_idx is y.
                    
                    char_valid <= 1;
                    case (stream_pos)
                        0: begin
                            // First char
                            char_out <= 8'h61 + (str_type ? char2_idx : char1_idx);
                            stream_pos <= 1;
                        end
                        1: begin
                            // Middle char (always y -> char2_idx)
                            // Wait, check: "xyx" -> y in middle. "yxy" -> x in middle.
                            // So middle char is always the "other" one.
                            // If Type 0: Middle is y (char2). If Type 1: Middle is x (char1).
                            // Wait. "yxy". y, x, y. Middle is x.
                            // So: Type 0: char2. Type 1: char1.
                            // Correct.
                            char_out <= 8'h61 + (str_type ? char1_idx : char2_idx);
                            stream_pos <= 2;
                        end
                        2: begin
                            // Last char
                            char_out <= 8'h61 + (str_type ? char2_idx : char1_idx);
                            state <= FINISHED;
                        end
                    endcase
                end

                FINISHED: begin
                    char_valid <= 0;
                    done <= 1;
                end
            endcase
        end
    end
endmodule