module challenge24(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] in0, in1, in2, in3,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE    = 4'd0;
    localparam [3:0] PERM    = 4'd1;
    localparam [3:0] OPS     = 4'd2;
    localparam [3:0] PAREN   = 4'd3;
    localparam [3:0] EVAL    = 4'd4;
    localparam [3:0] CHECK   = 4'd5;
    localparam [3:0] DONE    = 4'd6;

    // Permutation counter (0-23)
    reg [4:0] perm_counter;
    reg [7:0] perm [0:3];

    // Operator counter (0-63)
    reg [5:0] op_counter;
    reg [1:0] op1, op2, op3;

    // Parenthesization mode (0-4)
    reg [2:0] paren_mode;

    // Intermediate values
    reg signed [31:0] val0, val1, val2, val3;
    reg signed [31:0] temp1, temp2, temp3;
    reg signed [31:0] final_val;

    // Grade tracking
    reg [7:0] min_grade;
    reg [7:0] current_grade;
    reg found;

    // State machine
    reg [3:0] state, next_state;

    // Cycle counter for timeout
    reg [16:0] cycle_count;
    localparam [16:0] MAX_CYCLES = 17'd153600;

    // Permutation generation
    always @(*) begin
        case (perm_counter)
            5'd0:  begin perm[0] = in0; perm[1] = in1; perm[2] = in2; perm[3] = in3; end
            5'd1:  begin perm[0] = in0; perm[1] = in1; perm[2] = in3; perm[3] = in2; end
            5'd2:  begin perm[0] = in0; perm[1] = in2; perm[2] = in1; perm[3] = in3; end
            5'd3:  begin perm[0] = in0; perm[1] = in2; perm[2] = in3; perm[3] = in1; end
            5'd4:  begin perm[0] = in0; perm[1] = in3; perm[2] = in1; perm[3] = in2; end
            5'd5:  begin perm[0] = in0; perm[1] = in3; perm[2] = in2; perm[3] = in1; end
            5'd6:  begin perm[0] = in1; perm[1] = in0; perm[2] = in2; perm[3] = in3; end
            5'd7:  begin perm[0] = in1; perm[1] = in0; perm[2] = in3; perm[3] = in2; end
            5'd8:  begin perm[0] = in1; perm[1] = in2; perm[2] = in0; perm[3] = in3; end
            5'd9:  begin perm[0] = in1; perm[1] = in2; perm[2] = in3; perm[3] = in0; end
            5'd10: begin perm[0] = in1; perm[1] = in3; perm[2] = in0; perm[3] = in2; end
            5'd11: begin perm[0] = in1; perm[1] = in3; perm[2] = in2; perm[3] = in0; end
            5'd12: begin perm[0] = in2; perm[1] = in0; perm[2] = in1; perm[3] = in3; end
            5'd13: begin perm[0] = in2; perm[1] = in0; perm[2] = in3; perm[3] = in1; end
            5'd14: begin perm[0] = in2; perm[1] = in1; perm[2] = in0; perm[3] = in3; end
            5'd15: begin perm[0] = in2; perm[1] = in1; perm[2] = in3; perm[3] = in0; end
            5'd16: begin perm[0] = in2; perm[1] = in3; perm[2] = in0; perm[3] = in1; end
            5'd17: begin perm[0] = in2; perm[1] = in3; perm[2] = in1; perm[3] = in0; end
            5'd18: begin perm[0] = in3; perm[1] = in0; perm[2] = in1; perm[3] = in2; end
            5'd19: begin perm[0] = in3; perm[1] = in0; perm[2] = in2; perm[3] = in1; end
            5'd20: begin perm[0] = in3; perm[1] = in1; perm[2] = in0; perm[3] = in2; end
            5'd21: begin perm[0] = in3; perm[1] = in1; perm[2] = in2; perm[3] = in0; end
            5'd22: begin perm[0] = in3; perm[1] = in2; perm[2] = in0; perm[3] = in1; end
            5'd23: begin perm[0] = in3; perm[1] = in2; perm[2] = in1; perm[3] = in0; end
            default: begin perm[0] = in0; perm[1] = in1; perm[2] = in2; perm[3] = in3; end
        endcase
    end

    // Operator decoding
    always @(*) begin
        op1 = op_counter[1:0];
        op2 = op_counter[3:2];
        op3 = op_counter[5:4];
    end

    // Evaluation logic
    always @(*) begin
        val0 = perm[0];
        val1 = perm[1];
        val2 = perm[2];
        val3 = perm[3];

        case (paren_mode)
            3'd0: begin // A+B+C+D
                temp1 = (op1 == 2'b00) ? val0 * val1 :
                       (op1 == 2'b01) ? val0 + val1 :
                       (op1 == 2'b10) ? val0 - val1 :
                       (val1 != 0 && val0 % val1 == 0) ? val0 / val1 : 32'd0;
                temp2 = (op2 == 2'b00) ? temp1 * val2 :
                       (op2 == 2'b01) ? temp1 + val2 :
                       (op2 == 2'b10) ? temp1 - val2 :
                       (val2 != 0 && temp1 % val2 == 0) ? temp1 / val2 : 32'd0;
                final_val = (op3 == 2'b00) ? temp2 * val3 :
                          (op3 == 2'b01) ? temp2 + val3 :
                          (op3 == 2'b10) ? temp2 - val3 :
                          (val3 != 0 && temp2 % val3 == 0) ? temp2 / val3 : 32'd0;
            end
            3'd1: begin // A+(B+C)+D
                temp1 = (op2 == 2'b00) ? val1 * val2 :
                       (op2 == 2'b01) ? val1 + val2 :
                       (op2 == 2'b10) ? val1 - val2 :
                       (val2 != 0 && val1 % val2 == 0) ? val1 / val2 : 32'd0;
                temp2 = (op1 == 2'b00) ? val0 * temp1 :
                       (op1 == 2'b01) ? val0 + temp1 :
                       (op1 == 2'b10) ? val0 - temp1 :
                       (temp1 != 0 && val0 % temp1 == 0) ? val0 / temp1 : 32'd0;
                final_val = (op3 == 2'b00) ? temp2 * val3 :
                          (op3 == 2'b01) ? temp2 + val3 :
                          (op3 == 2'b10) ? temp2 - val3 :
                          (val3 != 0 && temp2 % val3 == 0) ? temp2 / val3 : 32'd0;
            end
            3'd2: begin // (A+B)+(C+D)
                temp1 = (op1 == 2'b00) ? val0 * val1 :
                       (op1 == 2'b01) ? val0 + val1 :
                       (op1 == 2'b10) ? val0 - val1 :
                       (val1 != 0 && val0 % val1 == 0) ? val0 / val1 : 32'd0;
                temp2 = (op3 == 2'b00) ? val2 * val3 :
                       (op3 == 2'b01) ? val2 + val3 :
                       (op3 == 2'b10) ? val2 - val3 :
                       (val3 != 0 && val2 % val3 == 0) ? val2 / val3 : 32'd0;
                final_val = (op2 == 2'b00) ? temp1 * temp2 :
                          (op2 == 2'b01) ? temp1 + temp2 :
                          (op2 == 2'b10) ? temp1 - temp2 :
                          (temp2 != 0 && temp1 % temp2 == 0) ? temp1 / temp2 : 32'd0;
            end
            3'd3: begin // (A+(B+C))+D
                temp1 = (op2 == 2'b00) ? val1 * val2 :
                       (op2 == 2'b01) ? val1 + val2 :
                       (op2 == 2'b10) ? val1 - val2 :
                       (val2 != 0 && val1 % val2 == 0) ? val1 / val2 : 32'd0;
                temp2 = (op1 == 2'b00) ? val0 * temp1 :
                       (op1 == 2'b01) ? val0 + temp1 :
                       (op1 == 2'b10) ? val0 - temp1 :
                       (temp1 != 0 && val0 % temp1 == 0) ? val0 / temp1 : 32'd0;
                final_val = (op3 == 2'b00) ? temp2 * val3 :
                          (op3 == 2'b01) ? temp2 + val3 :
                          (op3 == 2'b10) ? temp2 - val3 :
                          (val3 != 0 && temp2 % val3 == 0) ? temp2 / val3 : 32'd0;
            end
            3'd4: begin // A+((B+C)+D)
                temp1 = (op3 == 2'b00) ? val2 * val3 :
                       (op3 == 2'b01) ? val2 + val3 :
                       (op3 == 2'b10) ? val2 - val3 :
                       (val3 != 0 && val2 % val3 == 0) ? val2 / val3 : 32'd0;
                temp2 = (op2 == 2'b00) ? val1 * temp1 :
                       (op2 == 2'b01) ? val1 + temp1 :
                       (op2 == 2'b10) ? val1 - temp1 :
                       (temp1 != 0 && val1 % temp1 == 0) ? val1 / temp1 : 32'd0;
                final_val = (op1 == 2'b00) ? val0 * temp2 :
                          (op1 == 2'b01) ? val0 + temp2 :
                          (op1 == 2'b10) ? val0 - temp2 :
                          (temp2 != 0 && val0 % temp2 == 0) ? val0 / temp2 : 32'd0;
            end
            default: final_val = 32'd0;
        endcase
    end

    // Grade calculation
    always @(*) begin
        // Count inversions
        reg [1:0] inv_count = 2'd0;
        if (perm[0] > perm[1]) inv_count = inv_count + 2'd1;
        if (perm[0] > perm[2]) inv_count = inv_count + 2'd1;
        if (perm[0] > perm[3]) inv_count = inv_count + 2'd1;
        if (perm[1] > perm[2]) inv_count = inv_count + 2'd1;
        if (perm[1] > perm[3]) inv_count = inv_count + 2'd1;
        if (perm[2] > perm[3]) inv_count = inv_count + 2'd1;

        // Parentheses count
        reg [1:0] paren_count = 2'd0;
        case (paren_mode)
            3'd0: paren_count = 2'd0;
            3'd1: paren_count = 2'd2;
            3'd2: paren_count = 2'd2;
            3'd3: paren_count = 2'd2;
            3'd4: paren_count = 2'd2;
            default: paren_count = 2'd0;
        endcase

        current_grade = 2'd0 + (inv_count << 1) + (paren_count << 1);
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            found <= 1'b0;
            min_grade <= 8'd255;
            perm_counter <= 5'd0;
            op_counter <= 6'd0;
            paren_mode <= 3'd0;
            cycle_count <= 17'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= PERM;
                        found <= 1'b0;
                        min_grade <= 8'd255;
                        perm_counter <= 5'd0;
                        op_counter <= 6'd0;
                        paren_mode <= 3'd0;
                        cycle_count <= 17'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PERM: begin
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE;
                    end else begin
                        cycle_count <= cycle_count + 17'd1;
                        if (perm_counter == 5'd23) begin
                            next_state <= DONE;
                        end else begin
                            next_state <= OPS;
                            op_counter <= 6'd0;
                        end
                    end
                end

                OPS: begin
                    if (op_counter == 6'd63) begin
                        next_state <= PERM;
                        perm_counter <= perm_counter + 5'd1;
                    end else begin
                        next_state <= PAREN;
                        paren_mode <= 3'd0;
                    end
                end

                PAREN: begin
                    if (paren_mode == 3'd4) begin
                        next_state <= OPS;
                        op_counter <= op_counter + 6'd1;
                    end else begin
                        next_state <= EVAL;
                    end
                end

                EVAL: begin
                    next_state <= CHECK;
                end

                CHECK: begin
                    if (final_val == 32'd24 && !found) begin
                        found <= 1'b1;
                        min_grade <= current_grade;
                        if (min_grade == 8'd0) begin
                            next_state <= DONE;
                        end else begin
                            next_state <= PAREN;
                            paren_mode <= paren_mode + 3'd1;
                        end
                    end else if (final_val == 32'd24 && current_grade < min_grade) begin
                        min_grade <= current_grade;
                        if (min_grade == 8'd0) begin
                            next_state <= DONE;
                        end else begin
                            next_state <= PAREN;
                            paren_mode <= paren_mode + 3'd1;
                        end
                    end else begin
                        next_state <= PAREN;
                        paren_mode <= paren_mode + 3'd1;
                    end
                end

                DONE: begin
                    if (found) begin
                        result <= min_grade;
                    end else begin
                        result <= 8'd255;
                    end
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    result <= 8'd0;
                end
            endcase
        end
    end

endmodule