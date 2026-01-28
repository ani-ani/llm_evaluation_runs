module StringPatternMatcher(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input char_valid,
    input str_end,
    output reg match,
    output reg done
);

    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] SEARCH_A  = 3'd1;
    localparam [2:0] SEARCH_B  = 3'd2;
    localparam [2:0] MATCH     = 3'd3;
    localparam [2:0] NO_MATCH  = 3'd4;

    localparam [7:0] CHAR_A = 8'd97;  // ASCII 'a'
    localparam [7:0] CHAR_B = 8'd98;  // ASCII 'b'

    reg [2:0] state, next_state;
    reg [7:0] char_reg;
    reg char_valid_reg;
    reg str_end_reg;
    reg found_a;
    reg [3:0] char_count;
    localparam [3:0] MAX_LEN = 4'd16;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            match <= 1'b0;
            done <= 1'b0;
            char_reg <= 8'd0;
            char_valid_reg <= 1'b0;
            str_end_reg <= 1'b0;
            found_a <= 1'b0;
            char_count <= 4'd0;
        end else begin
            // Register inputs
            char_reg <= char_in;
            char_valid_reg <= char_valid;
            str_end_reg <= str_end;

            // State transition
            state <= next_state;

            // Clear done after one cycle
            if (done) begin
                done <= 1'b0;
            end

            // Character counter
            if (char_valid_reg) begin
                char_count <= char_count + 4'd1;
            end

            // State machine logic
            case (state)
                IDLE: begin
                    match <= 1'b0;
                    done <= 1'b0;
                    found_a <= 1'b0;
                    char_count <= 4'd0;
                    if (start) begin
                        next_state <= SEARCH_A;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                SEARCH_A: begin
                    if (char_valid_reg) begin
                        if (char_reg == CHAR_A) begin
                            found_a <= 1'b1;
                            next_state <= SEARCH_B;
                        end else if (str_end_reg) begin
                            next_state <= NO_MATCH;
                        end else begin
                            next_state <= SEARCH_A;
                        end
                    end else begin
                        next_state <= SEARCH_A;
                    end
                end

                SEARCH_B: begin
                    if (char_valid_reg) begin
                        if (str_end_reg) begin
                            if (char_reg == CHAR_B && found_a) begin
                                next_state <= MATCH;
                            end else begin
                                next_state <= NO_MATCH;
                            end
                        end else begin
                            next_state <= SEARCH_B;
                        end
                    end else begin
                        next_state <= SEARCH_B;
                    end
                end

                MATCH: begin
                    match <= 1'b1;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                NO_MATCH: begin
                    match <= 1'b0;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    match <= 1'b0;
                    done <= 1'b0;
                    found_a <= 1'b0;
                    char_count <= 4'd0;
                end
            endcase
        end
    end

endmodule