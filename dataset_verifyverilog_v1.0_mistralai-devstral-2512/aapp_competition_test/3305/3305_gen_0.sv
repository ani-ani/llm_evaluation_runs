module almost_palindrome_counter(
    input clk,
    input rst_n,
    input start,
    input [6:0] char_in,
    input [7:0] addr,
    input load_en,
    input [3:0] len,
    output reg [7:0] result,
    output reg done,
    output reg busy
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] LOAD      = 2'd1;
    localparam [1:0] CALCULATE = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Internal buffer for characters
    reg [6:0] buffer [0:15];
    reg [3:0] buffer_len;

    // Calculation variables
    reg [3:0] i_reg, j_reg, k_reg;
    reg [7:0] count_reg;
    reg [1:0] mismatch_count;
    reg [6:0] mismatch_pos1, mismatch_pos2;
    reg [6:0] char1, char2, char3, char4;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            busy <= 1'b0;
            cycle_count <= 8'd0;
            buffer_len <= 4'd0;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            k_reg <= 4'd0;
            count_reg <= 8'd0;
            mismatch_count <= 2'd0;
            mismatch_pos1 <= 7'd0;
            mismatch_pos2 <= 7'd0;
            char1 <= 7'd0;
            char2 <= 7'd0;
            char3 <= 7'd0;
            char4 <= 7'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        next_state <= LOAD;
                        busy <= 1'b1;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD: begin
                    if (load_en && addr < 16) begin
                        buffer[addr] <= char_in;
                    end
                    if (cycle_count >= 8'd1) begin
                        buffer_len <= len;
                        next_state <= CALCULATE;
                        i_reg <= 4'd0;
                        j_reg <= 4'd0;
                        count_reg <= 8'd0;
                    end
                end

                CALCULATE: begin
                    if (i_reg < buffer_len) begin
                        if (j_reg < buffer_len) begin
                            if (i_reg <= j_reg) begin
                                // Check substring from i_reg to j_reg
                                mismatch_count <= 2'd0;
                                mismatch_pos1 <= 7'd0;
                                mismatch_pos2 <= 7'd0;
                                k_reg <= 4'd0;

                                // Check for mismatches
                                while (k_reg <= (j_reg - i_reg) / 2) begin
                                    char1 <= buffer[i_reg + k_reg];
                                    char2 <= buffer[j_reg - k_reg];
                                    if (char1 != char2) begin
                                        if (mismatch_count == 2'd0) begin
                                            mismatch_pos1 <= i_reg + k_reg;
                                            mismatch_pos2 <= j_reg - k_reg;
                                        end else if (mismatch_count == 2'd1) begin
                                            mismatch_pos1 <= i_reg + k_reg;
                                            mismatch_pos2 <= j_reg - k_reg;
                                        end
                                        mismatch_count <= mismatch_count + 2'd1;
                                    end
                                    k_reg <= k_reg + 4'd1;
                                end

                                // Check if almost palindrome
                                if (mismatch_count == 2'd0) begin
                                    count_reg <= count_reg + 8'd1;
                                end else if (mismatch_count == 2'd2) begin
                                    // Check if swapping makes it a palindrome
                                    char1 <= buffer[mismatch_pos1];
                                    char2 <= buffer[mismatch_pos2];
                                    char3 <= buffer[mismatch_pos2];
                                    char4 <= buffer[mismatch_pos1];

                                    // Check if swapping positions makes it a palindrome
                                    if (char1 == char4 && char2 == char3) begin
                                        count_reg <= count_reg + 8'd1;
                                    end
                                end

                                j_reg <= j_reg + 4'd1;
                            end else begin
                                j_reg <= j_reg + 4'd1;
                            end
                        end else begin
                            i_reg <= i_reg + 4'd1;
                            j_reg <= i_reg;
                        end
                    end else begin
                        next_state <= DONE_STATE;
                        result <= count_reg;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    busy <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule