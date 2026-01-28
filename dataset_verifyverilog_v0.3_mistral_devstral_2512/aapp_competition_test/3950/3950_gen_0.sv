module ArrayValidator(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] q,
    input [3:0] a_0,
    input [3:0] a_1,
    input [3:0] a_2,
    input [3:0] a_3,
    input [3:0] a_4,
    input [3:0] a_5,
    input [3:0] a_6,
    input [3:0] a_7,
    input [3:0] a_8,
    input [3:0] a_9,
    input [3:0] a_10,
    input [3:0] a_11,
    input [3:0] a_12,
    input [3:0] a_13,
    input [3:0] a_14,
    input [3:0] a_15,
    output reg done,
    output reg valid,
    output reg [3:0] result_0,
    output reg [3:0] result_1,
    output reg [3:0] result_2,
    output reg [3:0] result_3,
    output reg [3:0] result_4,
    output reg [3:0] result_5,
    output reg [3:0] result_6,
    output reg [3:0] result_7,
    output reg [3:0] result_8,
    output reg [3:0] result_9,
    output reg [3:0] result_10,
    output reg [3:0] result_11,
    output reg [3:0] result_12,
    output reg [3:0] result_13,
    output reg [3:0] result_14,
    output reg [3:0] result_15
);

    localparam [3:0] INIT = 4'd0;
    localparam [3:0] BACKWARD_PASS = 4'd1;
    localparam [3:0] INIT_FORWARD = 4'd2;
    localparam [3:0] FORWARD = 4'd3;
    localparam [3:0] AFTER_FORWARD = 4'd4;
    localparam [3:0] FIND_ZERO = 4'd5;
    localparam [3:0] OUTPUT_VALID = 4'd6;
    localparam [3:0] OUTPUT_INVALID = 4'd7;

    reg [3:0] state;
    reg [3:0] index;
    reg [3:0] last_occurrence [0:15];
    reg [3:0] stack [0:15];
    reg [3:0] stack_ptr;
    reg [3:0] current_max;
    reg [3:0] temp_result [0:15];
    reg [3:0] zero_index;
    reg found_zero;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= INIT;
            index <= 4'd0;
            stack_ptr <= 4'd0;
            current_max <= 4'd0;
            zero_index <= 4'd0;
            found_zero <= 1'b0;
            cycle_count <= 8'd0;
            done <= 1'b0;
            valid <= 1'b0;

            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                last_occurrence[i] <= 4'd0;
                stack[i] <= 4'd0;
                temp_result[i] <= 4'd0;
            end

            result_0 <= 4'd0;
            result_1 <= 4'd0;
            result_2 <= 4'd0;
            result_3 <= 4'd0;
            result_4 <= 4'd0;
            result_5 <= 4'd0;
            result_6 <= 4'd0;
            result_7 <= 4'd0;
            result_8 <= 4'd0;
            result_9 <= 4'd0;
            result_10 <= 4'd0;
            result_11 <= 4'd0;
            result_12 <= 4'd0;
            result_13 <= 4'd0;
            result_14 <= 4'd0;
            result_15 <= 4'd0;
        end else begin
            case (state)
                INIT: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                    index <= 4'd0;
                    stack_ptr <= 4'd0;
                    current_max <= 4'd0;
                    zero_index <= 4'd0;
                    found_zero <= 1'b0;

                    integer i;
                    for (i = 0; i < 16; i = i + 1) begin
                        last_occurrence[i] <= 4'd0;
                        stack[i] <= 4'd0;
                        temp_result[i] <= 4'd0;
                    end

                    if (start) begin
                        state <= BACKWARD_PASS;
                    end
                end

                BACKWARD_PASS: begin
                    cycle_count <= cycle_count + 8'd1;

                    integer i;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < n) begin
                            case (i)
                                4'd0: last_occurrence[a_0] <= 4'd0;
                                4'd1: last_occurrence[a_1] <= 4'd1;
                                4'd2: last_occurrence[a_2] <= 4'd2;
                                4'd3: last_occurrence[a_3] <= 4'd3;
                                4'd4: last_occurrence[a_4] <= 4'd4;
                                4'd5: last_occurrence[a_5] <= 4'd5;
                                4'd6: last_occurrence[a_6] <= 4'd6;
                                4'd7: last_occurrence[a_7] <= 4'd7;
                                4'd8: last_occurrence[a_8] <= 4'd8;
                                4'd9: last_occurrence[a_9] <= 4'd9;
                                4'd10: last_occurrence[a_10] <= 4'd10;
                                4'd11: last_occurrence[a_11] <= 4'd11;
                                4'd12: last_occurrence[a_12] <= 4'd12;
                                4'd13: last_occurrence[a_13] <= 4'd13;
                                4'd14: last_occurrence[a_14] <= 4'd14;
                                4'd15: last_occurrence[a_15] <= 4'd15;
                            endcase
                        end
                    end

                    state <= INIT_FORWARD;
                end

                INIT_FORWARD: begin
                    cycle_count <= cycle_count + 8'd1;
                    index <= 4'd0;
                    stack_ptr <= 4'd0;
                    current_max <= 4'd0;
                    state <= FORWARD;
                end

                FORWARD: begin
                    cycle_count <= cycle_count + 8'd1;

                    if (index < n) begin
                        case (index)
                            4'd0: begin
                                if (a_0 == 4'd0) begin
                                    temp_result[0] <= (current_max == 4'd0) ? 4'd1 : current_max;
                                end else begin
                                    if (a_0 > current_max && last_occurrence[a_0] != index) begin
                                        stack[stack_ptr] <= current_max;
                                        stack_ptr <= stack_ptr + 4'd1;
                                        current_max <= a_0;
                                    end else if (last_occurrence[current_max] == index) begin
                                        if (stack_ptr > 4'd0) begin
                                            stack_ptr <= stack_ptr - 4'd1;
                                            current_max <= stack[stack_ptr];
                                        end else begin
                                            current_max <= 4'd0;
                                        end
                                    end else if (a_0 < current_max) begin
                                        valid <= 1'b0;
                                    end
                                    temp_result[0] <= a_0;
                                end
                            end
                            4'd1: begin
                                if (a_1 == 4'd0) begin
                                    temp_result[1] <= (current_max == 4'd0) ? 4'd1 : current_max;
                                end else begin
                                    if (a_1 > current_max && last_occurrence[a_1] != index) begin
                                        stack[stack_ptr] <= current_max;
                                        stack_ptr <= stack_ptr + 4'd1;
                                        current_max <= a_1;
                                    end else if (last_occurrence[current_max] == index) begin
                                        if (stack_ptr > 4'd0) begin
                                            stack_ptr <= stack_ptr - 4'd1;
                                            current_max <= stack[stack_ptr];
                                        end else begin
                                            current_max <= 4'd0;
                                        end
                                    end else if (a_1 < current_max) begin
                                        valid <= 1'b0;
                                    end
                                    temp_result[1] <= a_1;
                                end
                            end
                            4'd2: begin
                                if (a_2 == 4'd0) begin
                                    temp_result[2] <= (current_max == 4'd0) ? 4'd1 : current_max;
                                end else begin
                                    if (a_2 > current_max && last_occurrence[a_2] != index) begin
                                        stack[stack_ptr] <= current_max;
                                        stack_ptr <= stack_ptr + 4'd1;
                                        current_max <= a_2;
                                    end else if (last_occurrence[current_max] == index) begin
                                        if (stack_ptr > 4'd0) begin
                                            stack_ptr <= stack_ptr - 4'd1;
                                            current_max <= stack[stack_ptr];
                                        end else begin
                                            current_max <= 4'd0;
                                        end
                                    end else if (a_2 < current_max) begin
                                        valid <= 1'b0;
                                    end
                                    temp_result[2] <= a_2;
                                end
                            end
                            4'd3: begin
                                if (a_3 == 4'd0) begin
                                    temp_result[3] <= (current_max == 4'd0) ? 4'd1 : current_max;
                                end else begin
                                    if (a_3 > current_max && last_occurrence[a_3] != index) begin
                                        stack[stack_ptr] <= current_max;
                                        stack_ptr <= stack_ptr + 4'd1;
                                        current_max <= a_3;
                                    end else if (last_occurrence[current_max] == index) begin
                                        if (stack_ptr > 4'd0) begin
                                            stack_ptr <= stack_ptr - 4'd1;
                                            current_max <= stack[stack_ptr];
                                        end else begin
                                            current_max <= 4'd0;
                                        end
                                    end else if (a_3 < current_max) begin
                                        valid <= 1'b0;
                                    end
                                    temp_result[3] <= a_3;
                                end
                            end
                            4'd4: begin
                                if (a_4 == 4'd0) begin
                                    temp_result[4] <= (current_max == 4'd0) ? 4'd1 : current_max;
                                end else begin
                                    if (a_4 > current_max && last_occurrence[a_4] != index) begin
                                        stack[stack_ptr] <= current_max;
                                        stack_ptr <= stack_ptr + 4'd1;
                                        current_max <= a_4;
                                    end else if (last_occurrence[current_max] == index) begin
                                        if (stack_ptr > 4'd0) begin
                                            stack_ptr <= stack_ptr - 4'd1;
                                            current_max <= stack[stack_ptr];
                                        end else begin
                                            current_max <= 4'd0;
                                        end
                                    end else if (a_4 < current_max) begin
                                        valid <= 1'b0;
                                    end
                                    temp_result[4] <= a_4;
                                end
                            end
                            4'd5: begin
                                if (a_5 == 4'd0) begin
                                    temp_result[5] <= (current_max == 4'd0) ? 4'd1 : current_max;
                                end else begin
                                    if (a_5 > current_max && last_occurrence[a_5] != index) begin
                                        stack[stack_ptr] <= current_max;
                                        stack_ptr <= stack_ptr + 4'd1;
                                        current_max <= a_5;
                                    end else if (last_occurrence[current_max] == index) begin
                                        if (stack_ptr > 4'd0) begin
                                            stack_ptr <= stack_ptr - 4'd1;
                                            current_max <= stack[stack_ptr];
                                        end else begin
                                            current_max <= 4'd0;
                                        end
                                    end else if (a_5 < current_max) begin
                                        valid <= 1'b0;
                                    end
                                    temp_result[5] <= a_5;
                                end
                            end
                            4'd6: begin
                                if (a_6 == 4'd0) begin
                                    temp_result[6] <= (current_max == 4'd0) ? 4'd1 : current_max;
                                end else begin
                                    if (a_6 > current_max && last_occurrence[a_6] != index) begin
                                        stack[stack_ptr] <= current_max;
                                        stack_ptr <= stack_ptr + 4'd1;
                                        current_max <= a_6;
                                    end else if (last_occurrence[current_max] == index) begin
                                        if (stack_ptr > 4'd0) begin
                                            stack_ptr <= stack_ptr - 4'd1;
                                            current_max <= stack[stack_ptr];
                                        end else begin
                                            current_max <= 4'd0;
                                        end
                                    end else if (a_6 < current_max) begin
                                        valid <= 1'b0;
                                    end
                                    temp_result[6] <= a_6;
                                end
                            end
                            4'd7: begin
                                if (a_7 == 4'd0) begin
                                    temp_result[7] <= (current_max == 4'd0) ? 4'd1 : current_max;
                                end else begin
                                    if (a_7 > current_max && last_occurrence[a_7] != index) begin
                                        stack[stack_ptr] <= current_max;
                                        stack_ptr <= stack_ptr + 4'd1;
                                        current_max <= a_7;
                                    end else if (last_occurrence[current_max] == index) begin
                                        if (stack_ptr > 4'd0) begin
                                            stack_ptr <= stack_ptr - 4'd1;
                                            current_max <= stack[stack_ptr];
                                        end else begin
                                            current_max <= 4'd0;
                                        end
                                    end else if (a_7 < current_max) begin
                                        valid <= 1'b0;
                                    end
                                    temp_result[7] <= a_7;
                                end
                            end
                            4'd8: begin
                                if (a_8 == 4'd0) begin
                                    temp_result[8] <= (current_max == 4'd0) ? 4'd1 : current_max;
                                end else begin
                                    if (a_8 > current_max && last_occurrence[a_8] != index) begin
                                        stack[stack_ptr] <= current_max;
                                        stack_ptr <= stack_ptr + 4'd1;
                                        current_max <= a_8;
                                    end else if (last_occurrence[current_max] == index) begin
                                        if (stack_ptr > 4'd0) begin
                                            stack_ptr <= stack_ptr - 4'd1;
                                            current_max <= stack[stack_ptr];
                                        end else begin
                                            current_max <= 4'd0;
                                        end
                                    end else if (a_8 < current_max) begin
                                        valid <= 1'b0;
                                    end
                                    temp_result[8] <= a_8;
                                end
                            end
                            4'd9: begin
                                if (a_9 == 4'd0) begin
                                    temp_result[9] <= (current_max == 4'd0) ? 4'd1 : current_max;
                                end else begin
                                    if (a_9 > current_max && last_occurrence[a_9] != index) begin
                                        stack[stack_ptr] <= current_max;
                                        stack_ptr <= stack_ptr + 4'd1;
                                        current_max <= a_9;
                                    end else if (last_occurrence[current_max] == index) begin
                                        if (stack_ptr > 4'd0) begin
                                            stack_ptr <= stack_ptr - 4'd1;
                                            current_max <= stack[stack_ptr];
                                        end else begin
                                            current_max <= 4'd0;
                                        end
                                    end else if (a_9 < current_max) begin
                                        valid <= 1'b0;
                                    end
                                    temp_result[9] <= a_9;
                                end
                            end
                            4'd10: begin
                                if (a_10 == 4'd0) begin
                                    temp_result[10] <= (current_max == 4'd0) ? 4'd1 : current_max;
                                end else begin
                                    if (a_10 > current_max && last_occurrence[a_10] != index) begin
                                        stack[stack_ptr] <= current_max;
                                        stack_ptr <= stack_ptr + 4'd1;
                                        current_max <= a_10;
                                    end else if (last_occurrence[current_max] == index) begin
                                        if (stack_ptr > 4'd0) begin
                                            stack_ptr <= stack_ptr - 4'd1;
                                            current_max <= stack[stack_ptr];
                                        end else begin
                                            current_max <= 4'd0;
                                        end
                                    end else if (a_10 < current_max) begin
                                        valid <= 1'b0;
                                    end
                                    temp_result[10] <= a_10;
                                end
                            end
                            4'd11: begin
                                if (a_11 == 4'd0) begin
                                    temp_result[11] <= (current_max == 4'd0) ? 4'd1 : current_max;
                                end else begin
                                    if (a_11 > current_max && last_occurrence[a_11] != index) begin
                                        stack[stack_ptr] <= current_max;
                                        stack_ptr <= stack_ptr + 4'd1;
                                        current_max <= a_11;
                                    end else if (last_occurrence[current_max] == index) begin
                                        if (stack_ptr > 4'd0) begin
                                            stack_ptr <= stack_ptr - 4'd1;
                                            current_max <= stack[stack_ptr];
                                        end else begin
                                            current_max <= 4'd0;
                                        end
                                    end else if (a_11 < current_max) begin
                                        valid <= 1'b0;
                                    end
                                    temp_result[11] <= a_11;
                                end
                            end
                            4'd12: begin
                                if (a_12 == 4'd0) begin
                                    temp_result[12] <= (current_max == 4'd0) ? 4'd1 : current_max;
                                end else begin
                                    if (a_12 > current_max && last_occurrence[a_12] != index) begin
                                        stack[stack_ptr] <= current_max;
                                        stack_ptr <= stack_ptr + 4'd1;
                                        current_max <= a_12;
                                    end else if (last_occurrence[current_max] == index) begin
                                        if (stack_ptr > 4'd0) begin
                                            stack_ptr <= stack_ptr - 4'd1;
                                            current_max <= stack[stack_ptr];
                                        end else begin
                                            current_max <= 4'd0;
                                        end
                                    end else if (a_12 < current_max) begin
                                        valid <= 1'b0;
                                    end
                                    temp_result[12] <= a_12;
                                end
                            end
                            4'd13: begin
                                if (a_13 == 4'd0) begin
                                    temp_result[13] <= (current_max == 4'd0) ? 4'd1 : current_max;
                                end else begin
                                    if (a_13 > current_max && last_occurrence[a_13] != index) begin
                                        stack[stack_ptr] <= current_max;
                                        stack_ptr <= stack_ptr + 4'd1;
                                        current_max <= a_13;
                                    end else if (last_occurrence[current_max] == index) begin
                                        if (stack_ptr > 4'd0) begin
                                            stack_ptr <= stack_ptr - 4'd1;
                                            current_max <= stack[stack_ptr];
                                        end else begin
                                            current_max <= 4'd0;
                                        end
                                    end else if (a_13 < current_max) begin
                                        valid <= 1'b0;
                                    end
                                    temp_result[13] <= a_13;
                                end
                            end
                            4'd14: begin
                                if (a_14 == 4'd0) begin
                                    temp_result[14] <= (current_max == 4'd0) ? 4'd1 : current_max;
                                end else begin
                                    if (a_14 > current_max && last_occurrence[a_14] != index) begin
                                        stack[stack_ptr] <= current_max;
                                        stack_ptr <= stack_ptr + 4'd1;
                                        current_max <= a_14;
                                    end else if (last_occurrence[current_max] == index) begin
                                        if (stack_ptr > 4'd0) begin
                                            stack_ptr <= stack_ptr - 4'd1;
                                            current_max <= stack[stack_ptr];
                                        end else begin
                                            current_max <= 4'd0;
                                        end
                                    end else if (a_14 < current_max) begin
                                        valid <= 1'b0;
                                    end
                                    temp_result[14] <= a_14;
                                end
                            end
                            4'd15: begin
                                if (a_15 == 4'd0) begin
                                    temp_result[15] <= (current_max == 4'd0) ? 4'd1 : current_max;
                                end else begin
                                    if (a_15 > current_max && last_occurrence[a_15] != index) begin
                                        stack[stack_ptr] <= current_max;
                                        stack_ptr <= stack_ptr + 4'd1;
                                        current_max <= a_15;
                                    end else if (last_occurrence[current_max] == index) begin
                                        if (stack_ptr > 4'd0) begin
                                            stack_ptr <= stack_ptr - 4'd1;
                                            current_max <= stack[stack_ptr];
                                        end else begin
                                            current_max <= 4'd0;
                                        end
                                    end else if (a_15 < current_max) begin
                                        valid <= 1'b0;
                                    end
                                    temp_result[15] <= a_15;
                                end
                            end
                        endcase

                        index <= index + 4'd1;

                        if (index == n) begin
                            state <= AFTER_FORWARD;
                        end
                    end else begin
                        state <= AFTER_FORWARD;
                    end
                end

                AFTER_FORWARD: begin
                    cycle_count <= cycle_count + 8'd1;

                    if (current_max != q) begin
                        state <= FIND_ZERO;
                        zero_index <= 4'd0;
                        found_zero <= 1'b0;
                    end else begin
                        if (valid) begin
                            state <= OUTPUT_VALID;
                        end else begin
                            state <= OUTPUT_INVALID;
                        end
                    end
                end

                FIND_ZERO: begin
                    cycle_count <= cycle_count + 8'd1;

                    if (zero_index < n && !found_zero) begin
                        case (zero_index)
                            4'd0: begin
                                if (a_0 == 4'd0) begin
                                    temp_result[0] <= q;
                                    found_zero <= 1'b1;
                                end
                            end
                            4'd1: begin
                                if (a_1 == 4'd0) begin
                                    temp_result[1] <= q;
                                    found_zero <= 1'b1;
                                end
                            end
                            4'd2: begin
                                if (a_2 == 4'd0) begin
                                    temp_result[2] <= q;
                                    found_zero <= 1'b1;
                                end
                            end
                            4'd3: begin
                                if (a_3 == 4'd0) begin
                                    temp_result[3] <= q;
                                    found_zero <= 1'b1;
                                end
                            end
                            4'd4: begin
                                if (a_4 == 4'd0) begin
                                    temp_result[4] <= q;
                                    found_zero <= 1'b1;
                                end
                            end
                            4'd5: begin
                                if (a_5 == 4'd0) begin
                                    temp_result[5] <= q;
                                    found_zero <= 1'b1;
                                end
                            end
                            4'd6: begin
                                if (a_6 == 4'd0) begin
                                    temp_result[6] <= q;
                                    found_zero <= 1'b1;
                                end
                            end
                            4'd7: begin
                                if (a_7 == 4'd0) begin
                                    temp_result[7] <= q;
                                    found_zero <= 1'b1;
                                end
                            end
                            4'd8: begin
                                if (a_8 == 4'd0) begin
                                    temp_result[8] <= q;
                                    found_zero <= 1'b1;
                                end
                            end
                            4'd9: begin
                                if (a_9 == 4'd0) begin
                                    temp_result[9] <= q;
                                    found_zero <= 1'b1;
                                end
                            end
                            4'd10: begin
                                if (a_10 == 4'd0) begin
                                    temp_result[10] <= q;
                                    found_zero <= 1'b1;
                                end
                            end
                            4'd11: begin
                                if (a_11 == 4'd0) begin
                                    temp_result[11] <= q;
                                    found_zero <= 1'b1;
                                end
                            end
                            4'd12: begin
                                if (a_12 == 4'd0) begin
                                    temp_result[12] <= q;
                                    found_zero <= 1'b1;
                                end
                            end
                            4'd13: begin
                                if (a_13 == 4'd0) begin
                                    temp_result[13] <= q;
                                    found_zero <= 1'b1;
                                end
                            end
                            4'd14: begin
                                if (a_14 == 4'd0) begin
                                    temp_result[14] <= q;
                                    found_zero <= 1'b1;
                                end
                            end
                            4'd15: begin
                                if (a_15 == 4'd0) begin
                                    temp_result[15] <= q;
                                    found_zero <= 1'b1;
                                end
                            end
                        endcase

                        zero_index <= zero_index + 4'd1;

                        if (zero_index == n || found_zero) begin
                            if (found_zero) begin
                                state <= OUTPUT_VALID;
                            end else begin
                                state <= OUTPUT_INVALID;
                            end
                        end
                    end else begin
                        if (found_zero) begin
                            state <= OUTPUT_VALID;
                        end else begin
                            state <= OUTPUT_INVALID;
                        end
                    end
                end

                OUTPUT_VALID: begin
                    cycle_count <= cycle_count + 8'd1;
                    done <= 1'b1;
                    valid <= 1'b1;

                    result_0 <= temp_result[0];
                    result_1 <= temp_result[1];
                    result_2 <= temp_result[2];
                    result_3 <= temp_result[3];
                    result_4 <= temp_result[4];
                    result_5 <= temp_result[5];
                    result_6 <= temp_result[6];
                    result_7 <= temp_result[7];
                    result_8 <= temp_result[8];
                    result_9 <= temp_result[9];
                    result_10 <= temp_result[10];
                    result_11 <= temp_result[11];
                    result_12 <= temp_result[12];
                    result_13 <= temp_result[13];
                    result_14 <= temp_result[14];
                    result_15 <= temp_result[15];

                    state <= INIT;
                end

                OUTPUT_INVALID: begin
                    cycle_count <= cycle_count + 8'd1;
                    done <= 1'b1;
                    valid <= 1'b0;

                    integer i;
                    for (i = 0; i < 16; i = i + 1) begin
                        temp_result[i] <= 4'd0;
                    end

                    result_0 <= 4'd0;
                    result_1 <= 4'd0;
                    result_2 <= 4'd0;
                    result_3 <= 4'd0;
                    result_4 <= 4'd0;
                    result_5 <= 4'd0;
                    result_6 <= 4'd0;
                    result_7 <= 4'd0;
                    result_8 <= 4'd0;
                    result_9 <= 4'd0;
                    result_10 <= 4'd0;
                    result_11 <= 4'd0;
                    result_12 <= 4'd0;
                    result_13 <= 4'd0;
                    result_14 <= 4'd0;
                    result_15 <= 4'd0;

                    state <= INIT;
                end

                default: state <= INIT;
            endcase
        end
    end
endmodule