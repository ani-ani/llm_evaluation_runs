module bracket_validator(
    input clk,
    input rst_n,
    input start,
    input [7:0] brackets,
    input [2:0] length,
    output reg possible,
    output reg done
);

    // State encoding
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] CHECK_ORIG = 4'd1;
    localparam [3:0] SETUP_SEG = 4'd2;
    localparam [3:0] CHECK_SEG = 4'd3;
    localparam [3:0] LOOP_I = 4'd4;
    localparam [3:0] NEXT_I = 4'd5;
    localparam [3:0] ORIG_DONE = 4'd6;
    localparam [3:0] SEGMENT_DONE = 4'd7;
    localparam [3:0] NEXT_R = 4'd8;
    localparam [3:0] NEXT_L = 4'd9;
    localparam [3:0] DONE = 4'd10;

    // Internal registers
    reg [7:0] brackets_reg;
    reg [2:0] length_reg;
    reg [2:0] l, r, i;
    reg signed [4:0] cnt;
    reg invalid;
    reg found;
    reg invert_enable;
    reg check_orig;
    reg [3:0] state;

    // Combinational logic for current bracket
    wire [2:0] i_val = i;
    wire current_bracket_raw = (i_val < length_reg) ? brackets_reg[i_val] : 0;
    wire invert_flag = invert_enable && (i_val >= l) && (i_val <= r);
    wire current_bracket = invert_flag ? ~current_bracket_raw : current_bracket_raw;

    // Next cnt and invalid
    wire signed [4:0] next_cnt = current_bracket ? cnt + 1 : cnt - 1;
    wire next_invalid = invalid || (next_cnt < 0);

    // State machine and datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset
            state <= IDLE;
            possible <= 0;
            done <= 0;
            brackets_reg <= 8'b0;
            length_reg <= 3'b0;
            l <= 3'b0;
            r <= 3'b0;
            i <= 3'b0;
            cnt <= 5'sd0;
            invalid <= 0;
            found <= 0;
            invert_enable <= 0;
            check_orig <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        brackets_reg <= brackets;
                        length_reg <= length;
                        found <= 0;
                        state <= CHECK_ORIG;
                    end
                end

                CHECK_ORIG: begin
                    invert_enable <= 0;
                    check_orig <= 1;
                    i <= 3'b0;
                    cnt <= 5'sd0;
                    invalid <= 0;
                    state <= LOOP_I;
                end

                SETUP_SEG: begin
                    check_orig <= 0;
                    l <= 3'b0;
                    r <= 3'b0;
                    state <= CHECK_SEG;
                end

                CHECK_SEG: begin
                    invert_enable <= 1;
                    i <= 3'b0;
                    cnt <= 5'sd0;
                    invalid <= 0;
                    state <= LOOP_I;
                end

                LOOP_I: begin
                    // Update cnt and invalid based on current_bracket
                    cnt <= next_cnt;
                    invalid <= next_invalid;
                    state <= NEXT_I;
                end

                NEXT_I: begin
                    i <= i + 1;
                    if (i + 1 < length_reg) begin
                        state <= LOOP_I;
                    end else begin
                        // Finished loop for all indices
                        if (check_orig) begin
                            state <= ORIG_DONE;
                        end else begin
                            state <= SEGMENT_DONE;
                        end
                    end
                end

                ORIG_DONE: begin
                    if (!invalid && (cnt == 0)) begin
                        found <= 1;
                        state <= DONE;
                    end else begin
                        state <= SETUP_SEG;
                    end
                end

                SEGMENT_DONE: begin
                    if (!invalid && (cnt == 0)) begin
                        found <= 1;
                        state <= DONE;
                    end else begin
                        state <= NEXT_R;
                    end
                end

                NEXT_R: begin
                    if (r + 1 < length_reg) begin
                        r <= r + 1;
                        state <= CHECK_SEG;
                    end else begin
                        state <= NEXT_L;
                    end
                end

                NEXT_L: begin
                    if (l + 1 < length_reg) begin
                        l <= l + 1;
                        r <= l + 1;
                        state <= CHECK_SEG;
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    possible <= found;
                    done <= 1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule