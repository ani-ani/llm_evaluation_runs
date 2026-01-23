module handsome_finder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] len,
    input wire [3:0] digits [0:3],
    output reg [3:0] res1 [0:3],
    output reg [3:0] res2 [0:3],
    output reg [1:0] count,
    output reg done
);

    localparam [2:0] IDLE = 3'b000;
    localparam [2:0] PREV_DECREMENT = 3'b001;
    localparam [2:0] PREV_CHECK = 3'b010;
    localparam [2:0] NEXT_INCREMENT = 3'b011;
    localparam [2:0] NEXT_CHECK = 3'b100;
    localparam [2:0] COMPARE = 3'b101;
    localparam [2:0] DONE = 3'b110;

    reg [2:0] state, next_state;

    reg [3:0] orig_digits [0:3];
    reg [3:0] orig_len;
    reg [31:0] orig_value;
    reg [3:0] prev_digits [0:3];
    reg [3:0] prev_len;
    reg [31:0] prev_value;
    reg [3:0] next_digits [0:3];
    reg [3:0] next_len;
    reg [31:0] next_value;
    reg [31:0] dist_prev, dist_next;
    reg [31:0] iter_count;
    reg [31:0] MAX_ITER = 32'd1000;

    reg [3:0] temp_digits [0:3];
    reg [3:0] temp_len;
    reg [31:0] temp_value;
    reg is_handsome_flag;
    reg inc_carry, dec_borrow;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            orig_len <= 4'd0;
            orig_value <= 32'd0;
            prev_len <= 4'd0;
            prev_value <= 32'd0;
            next_len <= 4'd0;
            next_value <= 32'd0;
            dist_prev <= 32'd0;
            dist_next <= 32'd0;
            iter_count <= 32'd0;
            count <= 2'd0;
            done <= 1'b0;
            for (i = 0; i < 4; i = i + 1) begin
                orig_digits[i] <= 4'd0;
                prev_digits[i] <= 4'd0;
                next_digits[i] <= 4'd0;
                res1[i] <= 4'd0;
                res2[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = PREV_DECREMENT;
            PREV_DECREMENT: next_state = PREV_CHECK;
            PREV_CHECK: if (is_handsome_flag) next_state = NEXT_INCREMENT;
                        else if (iter_count >= MAX_ITER) next_state = NEXT_INCREMENT;
                        else next_state = PREV_DECREMENT;
            NEXT_INCREMENT: next_state = NEXT_CHECK;
            NEXT_CHECK: if (is_handsome_flag) next_state = COMPARE;
                        else if (iter_count >= MAX_ITER) next_state = COMPARE;
                        else next_state = NEXT_INCREMENT;
            COMPARE: next_state = DONE;
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            orig_len <= 4'd0;
            orig_value <= 32'd0;
            prev_len <= 4'd0;
            prev_value <= 32'd0;
            next_len <= 4'd0;
            next_value <= 32'd0;
            dist_prev <= 32'd0;
            dist_next <= 32'd0;
            iter_count <= 32'd0;
            count <= 2'd0;
            done <= 1'b0;
            for (i = 0; i < 4; i = i + 1) begin
                orig_digits[i] <= 4'd0;
                prev_digits[i] <= 4'd0;
                next_digits[i] <= 4'd0;
                res1[i] <= 4'd0;
                res2[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: if (start) begin
                    for (i = 0; i < 4; i = i + 1) begin
                        orig_digits[i] <= (i < len) ? digits[i] : 4'd0;
                    end
                    orig_len <= len;
                    orig_value <= 32'd0;
                    for (i = 0; i < 4; i = i + 1) begin
                        if (i < len)
                            orig_value <= orig_value * 32'd10 + digits[i];
                    end
                    for (i = 0; i < 4; i = i + 1) begin
                        prev_digits[i] <= orig_digits[i];
                        next_digits[i] <= orig_digits[i];
                    end
                    prev_len <= orig_len;
                    next_len <= orig_len;
                    iter_count <= 32'd0;
                end

                PREV_DECREMENT: begin
                    for (i = 0; i < 4; i = i + 1) begin
                        temp_digits[i] <= prev_digits[i];
                    end
                    temp_len <= prev_len;
                    dec_borrow <= 1'b1;
                    for (i = 3; i >= 0; i = i - 1) begin
                        if (i < temp_len) begin
                            if (dec_borrow) begin
                                if (temp_digits[i] == 4'd0) begin
                                    temp_digits[i] <= 4'd9;
                                    dec_borrow <= 1'b1;
                                end else begin
                                    temp_digits[i] <= temp_digits[i] - 4'd1;
                                    dec_borrow <= 1'b0;
                                end
                            end
                        end
                    end
                    for (i = 0; i < 4; i = i + 1) begin
                        prev_digits[i] <= temp_digits[i];
                    end
                    if (temp_len > 1 && temp_digits[0] == 4'd0) begin
                        if (temp_digits[1] != 4'd0) prev_len <= 3'd3;
                        else if (temp_digits[2] != 4'd0) prev_len <= 3'd2;
                        else if (temp_digits[3] != 4'd0) prev_len <= 3'd1;
                        else prev_len <= 3'd1;
                    end else begin
                        prev_len <= temp_len;
                    end
                    iter_count <= iter_count + 32'd1;
                end

                PREV_CHECK: begin
                    is_handsome_flag <= 1'b1;
                    if (prev_len == 4'd0) is_handsome_flag <= 1'b0;
                    else if (prev_len == 4'd1) is_handsome_flag <= 1'b1;
                    else begin
                        is_handsome_flag <= 1'b1;
                        for (i = 0; i < 3; i = i + 1) begin
                            if (i < prev_len - 1) begin
                                if ((prev_digits[i] % 4'd2) == (prev_digits[i+1] % 4'd2)) begin
                                    is_handsome_flag <= 1'b0;
                                end
                            end
                        end
                    end
                    if (is_handsome_flag) begin
                        prev_value <= 32'd0;
                        for (i = 0; i < 4; i = i + 1) begin
                            if (i < prev_len)
                                prev_value <= prev_value * 32'd10 + prev_digits[i];
                        end
                    end
                end

                NEXT_INCREMENT: begin
                    for (i = 0; i < 4; i = i + 1) begin
                        temp_digits[i] <= next_digits[i];
                    end
                    temp_len <= next_len;
                    inc_carry <= 1'b1;
                    for (i = 3; i >= 0; i = i - 1) begin
                        if (i < temp_len) begin
                            if (inc_carry) begin
                                if (temp_digits[i] == 4'd9) begin
                                    temp_digits[i] <= 4'd0;
                                    inc_carry <= 1'b1;
                                end else begin
                                    temp_digits[i] <= temp_digits[i] + 4'd1;
                                    inc_carry <= 1'b0;
                                end
                            end
                        end
                    end
                    if (inc_carry && temp_len < 4) begin
                        temp_len <= temp_len + 4'd1;
                        for (i = 3; i >= 0; i = i - 1) begin
                            if (i == 0) temp_digits[i] <= 4'd1;
                            else if (i < temp_len) temp_digits[i] <= 4'd0;
                        end
                    end
                    for (i = 0; i < 4; i = i + 1) begin
                        next_digits[i] <= temp_digits[i];
                    end
                    next_len <= temp_len;
                    iter_count <= iter_count + 32'd1;
                end

                NEXT_CHECK: begin
                    is_handsome_flag <= 1'b1;
                    if (next_len == 4'd0) is_handsome_flag <= 1'b0;
                    else if (next_len == 4'd1) is_handsome_flag <= 1'b1;
                    else begin
                        is_handsome_flag <= 1'b1;
                        for (i = 0; i < 3; i = i + 1) begin
                            if (i < next_len - 1) begin
                                if ((next_digits[i] % 4'd2) == (next_digits[i+1] % 4'd2)) begin
                                    is_handsome_flag <= 1'b0;
                                end
                            end
                        end
                    end
                    if (is_handsome_flag) begin
                        next_value <= 32'd0;
                        for (i = 0; i < 4; i = i + 1) begin
                            if (i < next_len)
                                next_value <= next_value * 32'd10 + next_digits[i];
                        end
                    end
                end

                COMPARE: begin
                    if (prev_len > 0 && is_handsome_flag) begin
                        dist_prev <= orig_value - prev_value;
                    end else begin
                        dist_prev <= 32'hFFFFFFFF;
                    end
                    if (next_len > 0 && is_handsome_flag) begin
                        dist_next <= next_value - orig_value;
                    end else begin
                        dist_next <= 32'hFFFFFFFF;
                    end
                    if (dist_prev < dist_next) begin
                        count <= 2'd1;
                        for (i = 0; i < 4; i = i + 1) begin
                            res1[i] <= (i < prev_len) ? prev_digits[i] : 4'd0;
                            res2[i] <= 4'd0;
                        end
                    end else if (dist_next < dist_prev) begin
                        count <= 2'd1;
                        for (i = 0; i < 4; i = i + 1) begin
                            res1[i] <= (i < next_len) ? next_digits[i] : 4'd0;
                            res2[i] <= 4'd0;
                        end
                    end else begin
                        count <= 2'd2;
                        for (i = 0; i < 4; i = i + 1) begin
                            res1[i] <= (i < prev_len) ? prev_digits[i] : 4'd0;
                            res2[i] <= (i < next_len) ? next_digits[i] : 4'd0;
                        end
                    end
                end

                DONE: begin
                    done <= 1'b1;
                end

                default: begin
                    count <= 2'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule