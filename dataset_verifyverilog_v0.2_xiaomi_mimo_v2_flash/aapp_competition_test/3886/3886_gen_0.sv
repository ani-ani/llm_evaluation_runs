module nephren_solver(
    input clk,
    input rst_n,
    input start,
    input [19:0] n_in,
    input [59:0] k_in,
    output reg [7:0] char_out,
    output reg done
);

    // States
    typedef enum logic [1:0] {
        IDLE,
        PROCESSING,
        DONE
    } state_t;

    reg [1:0] state, next_state;

    // Input registers
    reg [19:0] n_reg;
    reg [59:0] k_reg;

    // Constant lengths
    localparam integer LEN_BASE = 75;
    localparam integer LEN_PREFIX = 34;
    localparam integer LEN_MID = 32;
    localparam integer LEN_SUFFIX = 2;
    localparam logic [59:0] INF_LEN = 60'h0FFFFFFFFFFFFF; // Cap at ~10^18, effectively infinite for n > 55

    // Combinational logic for f_len[n-1]
    // Using a function to calculate length deterministically for synthesis
    // Precomputing is difficult in generic Verilog without arrays, so we calculate per step
    // Since n decreases, we can calculate current f_len based on current n
    function automatic logic [59:0] get_f_len(input [19:0] level);
        integer i;
        logic [59:0] len;
        begin
            if (level > 55) begin
                get_f_len = INF_LEN;
            end else begin
                len = LEN_BASE;
                for (i = 1; i <= level; i++) begin
                    // f_len[i] = 2 * f_len[i-1] + 68
                    // Check for overflow before multiplication
                    if (len > INF_LEN) begin
                        len = INF_LEN;
                    end else begin
                        len = (len << 1) + 68;
                        if (len > INF_LEN) len = INF_LEN;
                    end
                end
                get_f_len = len;
            end
        end
    endfunction

    // ROMs for strings
    // f_0: "What are you doing at the end of the world? Are you busy? Will you save us?"
    // We will use a case statement or a lookup block for cleaner code
    reg [7:0] char_prefix, char_mid, char_suffix, char_base;
    
    // Helper logic to get characters from fixed strings
    // f_0: 75 chars. Indices 0 to 74.
    always @(*) begin
        case (k_reg[6:0]) // k_reg is up to 10^18, but we only care for n=0 where k<=75
            // 0-13: "What are you doing"
            0: char_base = "W"; 1: char_base = "h"; 2: char_base = "a"; 3: char_base = "t";
            4: char_base = " "; 5: char_base = "a"; 6: char_base = "r"; 7: char_base = "e";
            8: char_base = " "; 9: char_base = "y"; 10: char_base = "o"; 11: char_base = "u";
            12: char_base = " "; 13: char_base = "d"; 14: char_base = "o"; 15: char_base = "i";
            16: char_base = "n"; 17: char_base = "g";
            // 18-22: " at "
            18: char_base = " "; 19: char_base = "a"; 20: char_base = "t"; 21: char_base = " ";
            // 23-33: "the world?"
            22: char_base = "t"; 23: char_base = "h"; 24: char_base = "e"; 25: char_base = " ";
            26: char_base = "w"; 27: char_base = "o"; 28: char_base = "r"; 29: char_base = "l";
            30: char_base = "d"; 31: char_base = "?";
            // 32-36: " Are"
            32: char_base = " "; 33: char_base = "A"; 34: char_base = "r"; 35: char_base = "e";
            // 37-46: " you busy?"
            36: char_base = " "; 37: char_base = "y"; 38: char_base = "o"; 39: char_base = "u";
            40: char_base = " "; 41: char_base = "b"; 42: char_base = "u"; 43: char_base = "s";
            44: char_base = "y"; 45: char_base = "?";
            // 46-51: " Will"
            46: char_base = " "; 47: char_base = "W"; 48: char_base = "i"; 49: char_base = "l";
            50: char_base = "l";
            // 52-62: " you save us?"
            51: char_base = " "; 52: char_base = "y"; 53: char_base = "o"; 54: char_base = "u";
            55: char_base = " "; 56: char_base = "s"; 57: char_base = "a"; 58: char_base = "v";
            59: char_base = "e"; 60: char_base = " "; 61: char_base = "u"; 62: char_base = "s";
            63: char_base = "?";
            64: char_base = " "; // Pad just in case, though length is 75 exactly
            default: char_base = "."; // Should not reach inside 75
        endcase
    end

    // prefix: "What are you doing while sending \""
    // Length 34. Indices 0-33
    always @(*) begin
        case (k_reg[5:0]) // Max 34
            0: char_prefix = "W"; 1: char_prefix = "h"; 2: char_prefix = "a"; 3: char_prefix = "t";
            4: char_prefix = " "; 5: char_prefix = "a"; 6: char_prefix = "r"; 7: char_prefix = "e";
            8: char_prefix = " "; 9: char_prefix = "y"; 10: char_prefix = "o"; 11: char_prefix = "u";
            12: char_prefix = " "; 13: char_prefix = "d"; 14: char_prefix = "o"; 15: char_prefix = "i";
            16: char_prefix = "n"; 17: char_prefix = "g"; 18: char_prefix = " "; 19: char_prefix = "w";
            20: char_prefix = "h"; 21: char_prefix = "i"; 22: char_prefix = "l"; 23: char_prefix = "e";
            24: char_prefix = " "; 25: char_prefix = "s"; 26: char_prefix = "e"; 27: char_prefix = "n";
            28: char_prefix = "d"; 29: char_prefix = "i"; 30: char_prefix = "n"; 31: char_prefix = "g";
            32: char_prefix = " "; 33: char_prefix = "\"";
            default: char_prefix = ".";
        endcase
    end

    // mid: "\"? Are you busy? Will you send \""
    // Length 32. Indices 0-31
    always @(*) begin
        case (k_reg[4:0]) // Max 32
            0: char_mid = "\""; 1: char_mid = "?"; 2: char_mid = " "; 3: char_mid = "A";
            4: char_mid = "r"; 5: char_mid = "e"; 6: char_mid = " "; 7: char_mid = "y";
            8: char_mid = "o"; 9: char_mid = "u"; 10: char_mid = " "; 11: char_mid = "b";
            12: char_mid = "u"; 13: char_mid = "s"; 14: char_mid = "y"; 15: char_mid = "?";
            16: char_mid = " "; 17: char_mid = "W"; 18: char_mid = "i"; 19: char_mid = "l";
            20: char_mid = "l"; 21: char_mid = " "; 22: char_mid = "y"; 23: char_mid = "o";
            24: char_mid = "u"; 25: char_mid = " "; 26: char_mid = "s"; 27: char_mid = "e";
            28: char_mid = "n"; 29: char_mid = "d"; 30: char_mid = " "; 31: char_mid = "\"";
            default: char_mid = ".";
        endcase
    end

    // suffix: "\"?"
    always @(*) begin
        char_suffix = (k_reg[0] == 0) ? "\"" : "?";
    end

    // Internal registers for iteration
    reg [19:0] curr_n;
    reg [59:0] curr_k;
    logic [59:0] len_prev;
    logic [59:0] len_total;
    
    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            char_out <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PROCESSING;
                        curr_n <= n_in;
                        curr_k <= k_in;
                        done <= 0;
                        char_out <= 0;
                    end
                end
                
                PROCESSING: begin
                    // Logic for one level of iteration
                    // If we are at n=0, we are done or found char
                    if (curr_n == 0) begin
                        if (curr_k <= LEN_BASE) begin
                            char_out <= char_base;
                        end else begin
                            char_out <= "\""; // Return dot as per "0 if dot '.'" (Assuming dot represents error or dot char, ASCII 46 is '.'. Wait, instruction says "0 if dot '.'" which is ambiguous. Usually "0" means null. But let's return dot '.' ASCII 46 if out of bounds? Or maybe 0 is instruction? It says "The ASCII character found (0 if dot '.')". I will return 0 if out of bounds. But wait, "0 if dot '.'" is weird phrasing. Maybe it means output '.' if invalid? Let's output '.' for error as per typical string logic. Wait, "Output reg [7:0] char_out // The ASCII character found (0 if dot '.')". I will interpret this as: output the char, or if the instruction meant to output '.' for out of bounds? Actually, the example problem usually outputs '.' for out of bounds. But the description says "0 if dot '.'". Let's stick to the strict instruction: Output 0 (ASCII 0) if out of bounds, which represents the 'dot' placeholder in the logic description? Or output '.'? I will output '.' which is ASCII 46, as per standard "nephren" problem. Re-reading: "The ASCII character found (0 if dot '.')". This might be a typo in the prompt. I will assume output '.' for out of bounds, which is standard. HOWEVER, "0 if dot '.'" might mean return 0 character if the answer is the dot character. I will return '.' (ASCII 46) for out of bounds. If the user specifically meant 0, they should have clarified. I'll stick to standard behavior which is '.' for invalid. Wait, "0 if dot '.'". Maybe it means output 0 for out of bounds. Let's output 0 for out of bounds to be safe with "0" in the description.
                            char_out <= 8'h00;
                        end
                        state <= DONE;
                    end else begin
                        // n > 0
                        if (curr_k <= LEN_PREFIX) begin
                            // In prefix
                            char_out <= char_prefix;
                            state <= DONE;
                        end else begin
                            // Check mid
                            if (curr_k <= LEN_PREFIX + len_prev) begin
                                // Recurse into f_{n-1}
                                curr_k <= curr_k - LEN_PREFIX;
                                curr_n <= curr_n - 1;
                                // state stays PROCESSING
                            end else if (curr_k <= LEN_PREFIX + len_prev + LEN_MID) begin
                                // In mid
                                char_out <= char_mid;
                                state <= DONE;
                            end else if (curr_k <= LEN_PREFIX + len_prev + LEN_MID + len_prev) begin
                                // Recurse into f_{n-1}
                                curr_k <= curr_k - LEN_PREFIX - len_prev - LEN_MID;
                                curr_n <= curr_n - 1;
                                // state stays PROCESSING
                            end else if (curr_k <= LEN_PREFIX + len_prev + LEN_MID + len_prev + LEN_SUFFIX) begin
                                // In suffix
                                char_out <= char_suffix;
                                state <= DONE;
                            end else begin
                                // Out of bounds
                                char_out <= 8'h00;
                                state <= DONE;
                            end
                        end
                    end
                end

                DONE: begin
                    if (!start) begin // Wait for start to go low to reset or accept new
                        done <= 0;
                        state <= IDLE;
                    end else begin
                        done <= 1; // Keep done high until start goes low
                    end
                end
            endcase
        end
    end

    // Combinational calculation of len_prev (length of f_{n-1})
    always @(*) begin
        if (curr_n == 0) begin
            len_prev = 0;
        end else begin
            len_prev = get_f_len(curr_n - 1);
        end
    end

endmodule