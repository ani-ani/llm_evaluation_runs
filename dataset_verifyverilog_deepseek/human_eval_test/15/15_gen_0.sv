module number_sequence (
    input clk,
    input rst_n,
    input start,
    output reg done,
    input [3:0] n,
    output reg [7:0] char_out,
    output reg valid
);

    // State definitions
    typedef enum {IDLE, OUTPUT_NUM, OUTPUT_SPACE} state_t;
    state_t current_state, next_state;

    reg [3:0] current_num, next_num;
    reg [3:0] n_reg, n_reg_next;
    reg digit_sel, next_digit_sel;
    reg done_next;

    // Sequential logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            current_num <= 4'd0;
            n_reg <= 4'd0;
            digit_sel <= 1'b0;
            done <= 1'b0;
            valid <= 1'b0;
        end else begin
            current_state <= next_state;
            current_num <= next_num;
            n_reg <= n_reg_next;
            digit_sel <= next_digit_sel;
            done <= done_next;
            valid <= (next_state == OUTPUT_NUM) | (next_state == OUTPUT_SPACE);
        end
    end

    // Combinational logic
    always_comb begin
        next_state = current_state;
        next_num = current_num;
        n_reg_next = n_reg;
        next_digit_sel = digit_sel;
        done_next = 1'b0;
        char_out = 8'd0;

        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = OUTPUT_NUM;
                    next_num = 4'd0;
                    n_reg_next = n;
                    next_digit_sel = 1'b0;
                end
            end

            OUTPUT_NUM: begin
                if (current_num < 10) begin
                    char_out = current_num + 8'd48;
                    if (current_num < n_reg) begin
                        next_state = OUTPUT_SPACE;
                    end else begin
                        next_state = IDLE;
                        done_next = 1'b1;
                    end
                    next_digit_sel = 1'b0;
                end else begin
                    if (!digit_sel) begin
                        char_out = 8'd49; // '1'
                        next_digit_sel = 1'b1;
                        next_state = OUTPUT_NUM;
                    end else begin
                        char_out = (current_num - 10) + 8'd48;
                        next_digit_sel = 1'b0;
                        if (current_num < n_reg) begin
                            next_state = OUTPUT_SPACE;
                        end else begin
                            next_state = IDLE;
                            done_next = 1'b1;
                        end
                    end
                end
            end

            OUTPUT_SPACE: begin
                char_out = 8'd32; // space
                next_num = current_num + 1'b1;
                next_state = OUTPUT_NUM;
                next_digit_sel = 1'b0;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule