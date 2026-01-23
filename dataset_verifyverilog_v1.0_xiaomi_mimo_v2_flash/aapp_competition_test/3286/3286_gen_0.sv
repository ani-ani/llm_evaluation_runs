module robber_password_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7,
    input wire [7:0] arr_8, arr_9, arr_10, arr_11, arr_12, arr_13, arr_14, arr_15,
    input wire [3:0] length,
    output reg [19:0] result,
    output reg done
);

    // Maximum length and modulo
    parameter MAX_LEN = 16;
    parameter MOD = 20'd1000009;

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE = 2'd2;

    // Registers
    reg [1:0] state;
    reg [3:0] i_reg;           // current index (1 to length)
    reg [19:0] dp_im1, dp_im2, dp_im3;
    reg [7:0] prev_char, prev_prev_char;
    reg [7:0] char_array_0, char_array_1, char_array_2, char_array_3;
    reg [7:0] char_array_4, char_array_5, char_array_6, char_array_7;
    reg [7:0] char_array_8, char_array_9, char_array_10, char_array_11;
    reg [7:0] char_array_12, char_array_13, char_array_14, char_array_15;
    reg [3:0] len_reg;

    // Combinational next values
    reg [19:0] next_dp_im1, next_dp_im2, next_dp_im3;
    reg [7:0] next_prev_char, next_prev_prev_char;
    reg [3:0] next_i;
    reg next_done;
    reg [19:0] dp_i;
    reg [7:0] cur_char;
    reg vowel;
    reg transformed;

    // Combinational logic for next state and outputs
    always @(*) begin
        // Default: keep current values
        next_dp_im1 = dp_im1;
        next_dp_im2 = dp_im2;
        next_dp_im3 = dp_im3;
        next_prev_char = prev_char;
        next_prev_prev_char = prev_prev_char;
        next_i = i_reg;
        next_done = 1'b0;
        dp_i = 20'd0;
        cur_char = 8'd0;
        vowel = 1'b0;
        transformed = 1'b0;

        case (state)
            COMPUTE: begin
                if (i_reg > len_reg) begin
                    // All characters processed, go to DONE
                    next_done = 1'b1;
                end else begin
                    // Get current character
                    case (i_reg - 4'd1)
                        4'd0: cur_char = char_array_0;
                        4'd1: cur_char = char_array_1;
                        4'd2: cur_char = char_array_2;
                        4'd3: cur_char = char_array_3;
                        4'd4: cur_char = char_array_4;
                        4'd5: cur_char = char_array_5;
                        4'd6: cur_char = char_array_6;
                        4'd7: cur_char = char_array_7;
                        4'd8: cur_char = char_array_8;
                        4'd9: cur_char = char_array_9;
                        4'd10: cur_char = char_array_10;
                        4'd11: cur_char = char_array_11;
                        4'd12: cur_char = char_array_12;
                        4'd13: cur_char = char_array_13;
                        4'd14: cur_char = char_array_14;
                        4'd15: cur_char = char_array_15;
                        default: cur_char = 8'd0;
                    endcase

                    // Check if vowel
                    vowel = (cur_char == 8'h61) || (cur_char == 8'h65) || 
                            (cur_char == 8'h69) || (cur_char == 8'h6F) || (cur_char == 8'h75);

                    // Base case: vowel or consonant untransformed
                    dp_i = dp_im1;

                    // Check transformed case
                    if (!vowel && (i_reg >= 4'd3)) begin
                        if ((prev_char == 8'h6F) && (prev_prev_char == cur_char)) begin
                            transformed = 1'b1;
                            dp_i = dp_im1 + dp_im3;
                            if (dp_i >= MOD) begin
                                dp_i = dp_i - MOD;
                            end
                        end
                    end

                    // Update next registers
                    next_dp_im3 = dp_im2;
                    next_dp_im2 = dp_im1;
                    next_dp_im1 = dp_i;
                    next_prev_prev_char = prev_char;
                    next_prev_char = cur_char;
                    next_i = i_reg + 4'd1;
                end
            end
            default: begin
                // For IDLE and DONE, next values remain default
            end
        endcase
    end

    // Sequential updates
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 20'd0;
            i_reg <= 4'd0;
            dp_im1 <= 20'd0;
            dp_im2 <= 20'd0;
            dp_im3 <= 20'd0;
            prev_char <= 8'd0;
            prev_prev_char <= 8'd0;
            len_reg <= 4'd0;
            char_array_0 <= 8'd0;
            char_array_1 <= 8'd0;
            char_array_2 <= 8'd0;
            char_array_3 <= 8'd0;
            char_array_4 <= 8'd0;
            char_array_5 <= 8'd0;
            char_array_6 <= 8'd0;
            char_array_7 <= 8'd0;
            char_array_8 <= 8'd0;
            char_array_9 <= 8'd0;
            char_array_10 <= 8'd0;
            char_array_11 <= 8'd0;
            char_array_12 <= 8'd0;
            char_array_13 <= 8'd0;
            char_array_14 <= 8'd0;
            char_array_15 <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Load input array
                        char_array_0 <= arr_0;
                        char_array_1 <= arr_1;
                        char_array_2 <= arr_2;
                        char_array_3 <= arr_3;
                        char_array_4 <= arr_4;
                        char_array_5 <= arr_5;
                        char_array_6 <= arr_6;
                        char_array_7 <= arr_7;
                        char_array_8 <= arr_8;
                        char_array_9 <= arr_9;
                        char_array_10 <= arr_10;
                        char_array_11 <= arr_11;
                        char_array_12 <= arr_12;
                        char_array_13 <= arr_13;
                        char_array_14 <= arr_14;
                        char_array_15 <= arr_15;
                        len_reg <= length;
                        // Initialize DP
                        dp_im1 <= 20'd1; // dp[0]
                        dp_im2 <= 20'd0;
                        dp_im3 <= 20'd0;
                        prev_char <= 8'd0;
                        prev_prev_char <= 8'd0;
                        i_reg <= 4'd1;   // start with i=1
                        state <= COMPUTE;
                    end
                end
                COMPUTE: begin
                    // Update registers with next values
                    dp_im1 <= next_dp_im1;
                    dp_im2 <= next_dp_im2;
                    dp_im3 <= next_dp_im3;
                    prev_char <= next_prev_char;
                    prev_prev_char <= next_prev_prev_char;
                    i_reg <= next_i;
                    if (next_done) begin
                        state <= DONE;
                        result <= next_dp_im1; // dp_im1 now holds dp[length]
                        done <= 1'b1;
                    end
                end
                DONE: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
                default: state <= IDLE;
            endcase
        end
    end

endmodule