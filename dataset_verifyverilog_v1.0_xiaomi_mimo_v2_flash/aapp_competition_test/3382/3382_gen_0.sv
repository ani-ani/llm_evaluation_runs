module challenge24 (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] a, b, c, d,
    output reg [7:0] grade,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] PERMUTE   = 3'd1;
    localparam [2:0] OPS       = 3'd2;
    localparam [2:0] TREE      = 3'd3;
    localparam [2:0] EVAL      = 3'd4;
    localparam [2:0] FINISH    = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] min_grade, min_grade_next;
    reg [7:0] nums [0:3];        // Permutation of input numbers
    reg [7:0] nums_next [0:3];
    reg [2:0] perm_idx;          // 0-23 for 24 permutations
    reg [2:0] perm_idx_next;
    reg [5:0] op_combo;          // 0-63 for 64 operator combinations
    reg [5:0] op_combo_next;
    reg [2:0] tree_idx;          // 0-4 for 5 expression trees
    reg [2:0] tree_idx_next;
    reg [15:0] operand1, operand2, result_reg;
    reg [15:0] operand1_next, operand2_next, result_reg_next;
    reg [7:0] grade_current, grade_current_next;
    reg [2:0] eval_step, eval_step_next;
    reg [2:0] temp_idx;          // Temporary index for evaluation
    reg [2:0] temp_idx_next;
    reg [15:0] temp_val1, temp_val2;
    reg [15:0] temp_val1_next, temp_val2_next;
    reg [7:0] grade_temp, grade_temp_next;
    reg [15:0] nums_16 [0:3];    // 16-bit versions
    reg [15:0] nums_16_next [0:3];
    reg [2:0] i;
    reg [2:0] j;
    reg [2:0] i_next, j_next;

    // Operator decoding: 0=+, 1=-, 2=*, 3=/
    // op_combo[1:0] = op0, op_combo[3:2] = op1, op_combo[5:4] = op2
    wire [1:0] op0, op1, op2;
    assign op0 = op_combo[1:0];
    assign op1 = op_combo[3:2];
    assign op2 = op_combo[5:4];

    // Permutation generator (simple counter to 24)
    // Permutation map: 0 -> a,b,c,d; 1 -> a,b,d,c; etc.
    // We'll use a systematic approach to generate permutations
    reg [7:0] p0, p1, p2, p3;
    always @(*) begin
        case(perm_idx)
            3'd0: begin p0 = a; p1 = b; p2 = c; p3 = d; end
            3'd1: begin p0 = a; p1 = b; p2 = d; p3 = c; end
            3'd2: begin p0 = a; p1 = c; p2 = b; p3 = d; end
            3'd3: begin p0 = a; p1 = c; p2 = d; p3 = b; end
            3'd4: begin p0 = a; p1 = d; p2 = b; p3 = c; end
            3'd5: begin p0 = a; p1 = d; p2 = c; p3 = b; end
            3'd6: begin p0 = b; p1 = a; p2 = c; p3 = d; end
            3'd7: begin p0 = b; p1 = a; p2 = d; p3 = c; end
            3'd8: begin p0 = b; p1 = c; p2 = a; p3 = d; end
            3'd9: begin p0 = b; p1 = c; p2 = d; p3 = a; end
            3'd10: begin p0 = b; p1 = d; p2 = a; p3 = c; end
            3'd11: begin p0 = b; p1 = d; p2 = c; p3 = a; end
            3'd12: begin p0 = c; p1 = a; p2 = b; p3 = d; end
            3'd13: begin p0 = c; p1 = a; p2 = d; p3 = b; end
            3'd14: begin p0 = c; p1 = b; p2 = a; p3 = d; end
            3'd15: begin p0 = c; p1 = b; p2 = d; p3 = a; end
            3'd16: begin p0 = c; p1 = d; p2 = a; p3 = b; end
            3'd17: begin p0 = c; p1 = d; p2 = b; p3 = a; end
            3'd18: begin p0 = d; p1 = a; p2 = b; p3 = c; end
            3'd19: begin p0 = d; p1 = a; p2 = c; p3 = b; end
            3'd20: begin p0 = d; p1 = b; p2 = a; p3 = c; end
            3'd21: begin p0 = d; p1 = b; p2 = c; p3 = a; end
            3'd22: begin p0 = d; p1 = c; p2 = a; p3 = b; end
            3'd23: begin p0 = d; p1 = c; p2 = b; p3 = a; end
            default: begin p0 = a; p1 = b; p2 = c; p3 = d; end
        endcase
    end

    // State transition and next state logic
    always @(*) begin
        // Default values
        next_state = state;
        perm_idx_next = perm_idx;
        op_combo_next = op_combo;
        tree_idx_next = tree_idx;
        eval_step_next = eval_step;
        i_next = i;
        j_next = j;
        temp_idx_next = temp_idx;
        temp_val1_next = temp_val1;
        temp_val2_next = temp_val2;
        grade_temp_next = grade_temp;
        grade_current_next = grade_current;
        min_grade_next = min_grade;
        operand1_next = operand1;
        operand2_next = operand2;
        result_reg_next = result_reg;
        
        // Default array assignments
        for (j = 0; j < 4; j = j + 1) begin
            nums_next[j] = nums[j];
            nums_16_next[j] = nums_16[j];
        end

        case (state)
            IDLE: begin
                if (start) begin
                    // Initialize everything
                    perm_idx_next = 6'd0;
                    op_combo_next = 6'd0;
                    tree_idx_next = 3'd0;
                    min_grade_next = 8'hFF;
                    for (i_next = 0; i_next < 4; i_next = i_next + 1) begin
                        case(i_next)
                            0: begin nums_next[0] = a; nums_16_next[0] = {8'd0, a}; end
                            1: begin nums_next[1] = b; nums_16_next[1] = {8'd0, b}; end
                            2: begin nums_next[2] = c; nums_16_next[2] = {8'd0, c}; end
                            3: begin nums_next[3] = d; nums_16_next[3] = {8'd0, d}; end
                        endcase
                    end
                    next_state = PERMUTE;
                end
            end

            PERMUTE: begin
                // Update current permutation
                nums_next[0] = p0;
                nums_next[1] = p1;
                nums_next[2] = p2;
                nums_next[3] = p3;
                nums_16_next[0] = {8'd0, p0};
                nums_16_next[1] = {8'd0, p1};
                nums_16_next[2] = {8'd0, p2};
                nums_16_next[3] = {8'd0, p3};
                op_combo_next = 6'd0;
                tree_idx_next = 3'd0;
                next_state = OPS;
            end

            OPS: begin
                // Reset evaluation for current operator combo
                eval_step_next = 3'd0;
                grade_current_next = 8'd0;
                // Count operators: grade = 3 * ops (base for operations)
                // Actually, grade calculation: parentheses + 2*inversions
                // We'll compute grade during evaluation
                grade_current_next = 8'd0; // Will add parentheses
                next_state = TREE;
            end

            TREE: begin
                // Setup for evaluation of current tree
                eval_step_next = 3'd0;
                i_next = 3'd0;
                j_next = 3'd0;
                temp_idx_next = 3'd0;
                // Initialize temporary registers
                temp_val1_next = nums_16[0];
                temp_val2_next = nums_16[1];
                grade_temp_next = grade_current; // Start with base grade
                next_state = EVAL;
            end

            EVAL: begin
                // Evaluate the expression tree based on tree_idx
                // Each tree has specific evaluation steps
                case (tree_idx)
                    3'd0: // (a op0 b) op1 (c op2 d)
                        case (eval_step)
                            3'd0: begin // eval a op0 b
                                case (op0)
                                    2'd0: begin // +
                                        operand1_next = nums_16[0] + nums_16[1];
                                        grade_temp_next = grade_temp_next + 8'd1; // 1 pair parens
                                    end
                                    2'd1: begin // -
                                        operand1_next = nums_16[0] - nums_16[1];
                                        grade_temp_next = grade_temp_next + 8'd1; // 1 pair parens
                                    end
                                    2'd2: begin // *
                                        operand1_next = nums_16[0] * nums_16[1];
                                        grade_temp_next = grade_temp_next + 8'd1; // 1 pair parens
                                    end
                                    2'd3: begin // /
                                        if (nums_16[1] != 16'd0 && (nums_16[0] % nums_16[1]) == 16'd0) begin
                                            operand1_next = nums_16[0] / nums_16[1];
                                            grade_temp_next = grade_temp_next + 8'd1; // 1 pair parens
                                        end else begin
                                            // Invalid division, skip this evaluation
                                            eval_step_next = 3'd7; // Go to done state
                                        end
                                    end
                                endcase
                                eval_step_next = 3'd1;
                            end
                            3'd1: begin // eval c op2 d
                                case (op2)
                                    2'd0: begin // +
                                        operand2_next = nums_16[2] + nums_16[3];
                                        grade_temp_next = grade_temp_next + 8'd1; // 1 pair parens
                                    end
                                    2'd1: begin // -
                                        operand2_next = nums_16[2] - nums_16[3];
                                        grade_temp_next = grade_temp_next + 8'd1; // 1 pair parens
                                    end
                                    2'd2: begin // *
                                        operand2_next = nums_16[2] * nums_16[3];
                                        grade_temp_next = grade_temp_next + 8'd1; // 1 pair parens
                                    end
                                    2'd3: begin // /
                                        if (nums_16[3] != 16'd0 && (nums_16[2] % nums_16[3]) == 16'd0) begin
                                            operand2_next = nums_16[2] / nums_16[3];
                                            grade_temp_next = grade_temp_next + 8'd1; // 1 pair parens
                                        end else begin
                                            eval_step_next = 3'd7;
                                        end
                                    end
                                endcase
                                eval_step_next = 3'd2;
                            end
                            3'd2: begin // eval operand1 op1 operand2
                                case (op1)
                                    2'd0: begin // +
                                        result_reg_next = operand1 + operand2;
                                        grade_temp_next = grade_temp_next + 8'd1; // outer parens
                                    end
                                    2'd1: begin // -
                                        result_reg_next = operand1 - operand2;
                                        grade_temp_next = grade_temp_next + 8'd1; // outer parens
                                    end
                                    2'd2: begin // *
                                        result_reg_next = operand1 * operand2;
                                        grade_temp_next = grade_temp_next + 8'd1; // outer parens
                                    end
                                    2'd3: begin // /
                                        if (operand2 != 16'd0 && (operand1 % operand2) == 16'd0) begin
                                            result_reg_next = operand1 / operand2;
                                            grade_temp_next = grade_temp_next + 8'd1; // outer parens
                                        end else begin
                                            eval_step_next = 3'd7;
                                        end
                                    end
                                endcase
                                eval_step_next = 3'd3;
                            end
                            3'd3: begin // Check result
                                if (result_reg_next == 16'd24) begin
                                    if (grade_temp_next < min_grade_next) begin
                                        min_grade_next = grade_temp_next;
                                    end
                                end
                                eval_step_next = 3'd7;
                            end
                            default: eval_step_next = 3'd7;
                        endcase

                    3'd1: // ((a op0 b) op1 c) op2 d
                        case (eval_step)
                            3'd0: begin // eval a op0 b
                                case (op0)
                                    2'd0: begin operand1_next = nums_16[0] + nums_16[1]; grade_temp_next = grade_temp_next + 8'd1; end
                                    2'd1: begin operand1_next = nums_16[0] - nums_16[1]; grade_temp_next = grade_temp_next + 8'd1; end
                                    2'd2: begin operand1_next = nums_16[0] * nums_16[1]; grade_temp_next = grade_temp_next + 8'd1; end
                                    2'd3: begin if (nums_16[1] != 16'd0 && (nums_16[0] % nums_16[1]) == 16'd0) begin operand1_next = nums_16[0] / nums_16[1]; grade_temp_next = grade_temp_next + 8'd1; end else eval_step_next = 3'd7; end
                                endcase
                                eval_step_next = 3'd1;
                            end
                            3'd1: begin // eval (a op0 b) op1 c
                                case (op1)
                                    2'd0: begin result_reg_next = operand1 + nums_16[2]; grade_temp_next = grade_temp_next + 8'd1; end
                                    2'd1: begin result_reg_next = operand1 - nums_16[2]; grade_temp_next = grade_temp_next + 8'd1; end
                                    2'd2: begin result_reg_next = operand1 * nums_16[2]; grade_temp_next = grade_temp_next + 8'd1; end
                                    2'd3: begin if (nums_16[2] != 16'd0 && (operand1 % nums_16[2]) == 16'd0) begin result_reg_next = operand1 / nums_16[2]; grade_temp_next = grade_temp_next + 8'd1; end else eval_step_next = 3'd7; end
                                endcase
                                eval_step_next = 3'd2;
                            end
                            3'd2: begin // eval result op2 d
                                case (op2)
                                    2'd0: begin result_reg_next = result_reg + nums_16[3]; end
                                    2'd1: begin result_reg_next = result_reg - nums_16[3]; end
                                    2'd2: begin result_reg_next = result_reg * nums_16[3]; end
                                    2'd3: begin if (nums_16[3] != 16'd0 && (result_reg % nums_16[3]) == 16'd0) begin result_reg_next = result_reg / nums_16[3]; end else eval_step_next = 3'd7; end
                                endcase
                                eval_step_next = 3'd3;
                            end
                            3'd3: begin // Check result
                                if (result_reg_next == 16'd24) begin
                                    if (grade_temp_next < min_grade_next) begin
                                        min_grade_next = grade_temp_next;
                                    end
                                end
                                eval_step_next = 3'd7;
                            end
                            default: eval_step_next = 3'd7;
                        endcase

                    3'd2: // (a op0 (b op1 c)) op2 d
                        case (eval_step)
                            3'd0: begin // eval b op1 c
                                case (op1)
                                    2'd0: begin operand1_next = nums_16[1] + nums_16[2]; grade_temp_next = grade_temp_next + 8'd1; end
                                    2'd1: begin operand1_next = nums_16[1] - nums_16[2]; grade_temp_next = grade_temp_next + 8'd1; end
                                    2'd2: begin operand1_next = nums_16[1] * nums_16[2]; grade_temp_next = grade_temp_next + 8'd1; end
                                    2'd3: begin if (nums_16[2] != 16'd0 && (nums_16[1] % nums_16[2]) == 16'd0) begin operand1_next = nums_16[1] / nums_16[2]; grade_temp_next = grade_temp_next + 8'd1; end else eval_step_next = 3'd7; end
                                endcase
                                eval_step_next = 3'd1;
                            end
                            3'd1: begin // eval a op0 (b op1 c)
                                case (op0)
                                    2'd0: begin result_reg_next = nums_16[0] + operand1; grade_temp_next = grade_temp_next + 8'd1; end
                                    2'd1: begin result_reg_next = nums_16[0] - operand1; grade_temp_next = grade_temp_next + 8'd1; end
                                    2'd2: begin result_reg_next = nums_16[0] * operand1; grade_temp_next = grade_temp_next + 8'd1; end
                                    2'd3: begin if (operand1 != 16'd0 && (nums_16[0] % operand1) == 16'd0) begin result_reg_next = nums_16[0] / operand1; grade_temp_next = grade_temp_next + 8'd1; end else eval_step_next = 3'd7; end
                                endcase
                                eval_step_next = 3'd2;
                            end
                            3'd2: begin // eval result op2 d
                                case (op2)
                                    2'd0: begin result_reg_next = result_reg + nums_16[3]; end
                                    2'd1: begin result_reg_next = result_reg - nums_16[3]; end
                                    2'd2: begin result_reg_next = result_reg * nums_16[3]; end
                                    2'd3: begin if (nums_16[3] != 16'd0 && (result_reg % nums_16[3]) == 16'd0) begin result_reg_next = result_reg / nums_16[3]; end else eval_step_next = 3'd7; end
                                endcase
                                eval_step_next = 3'd3;
                            end
                            3'd3: begin // Check result
                                if (result_reg_next == 16'd24) begin
                                    if (grade_temp_next < min_grade_next) begin
                                        min_grade_next = grade_temp_next;
                                    end
                                end
                                eval_step_next = 3'd7;
                            end
                            default: eval_step_next = 3'd7;
                        endcase

                    3'd3: // a op0 ((b op1 c) op2 d)
                        case (eval_step)
                            3'd0: begin // eval b op1 c
                                case (op1)
                                    2'd0: begin operand1_next = nums_16[1] + nums_16[2]; grade_temp_next = grade_temp_next + 8'd1; end
                                    2'd1: begin operand1_next = nums_16[1] - nums_16[2]; grade_temp_next = grade_temp_next + 8'd1; end
                                    2'd2: begin operand1_next = nums_16[1] * nums_16[2]; grade_temp_next = grade_temp_next + 8'd1; end
                                    2'd3: begin if (nums_16[2] != 16'd0 && (nums_16[1] % nums_16[2]) == 16'd0) begin operand1_next = nums_16[1] / nums_16[2]; grade_temp_next = grade_temp_next + 8'd1; end else eval_step_next = 3'd7; end
                                endcase
                                eval_step_next = 3'd1;
                            end
                            3'd1: begin // eval (b op1 c) op2 d
                                case (op2)
                                    2'd0: begin operand2_next = operand1 + nums_16[3]; grade_temp_next = grade_temp_next + 8'd1; end
                                    2'd1: begin operand2_next = operand1 - nums_16[3]; grade_temp_next = grade_temp_next + 8'd1; end
                                    2'd2: begin operand2_next = operand1 * nums_16[3]; grade_temp_next = grade_temp_next + 8'd1; end
                                    2'd3: begin if (nums_16[3] != 16'd0 && (operand1 % nums_16[3]) == 16'd0) begin operand2_next = operand1 / nums_16[3]; grade_temp_next = grade_temp_next + 8'd1; end else eval_step_next = 3'd7; end
                                endcase
                                eval_step_next = 3'd2;
                            end
                            3'd2: begin // eval a op0 operand2
                                case (op0)
                                    2'd0: begin result_reg_next = nums_16[0] + operand2; end
                                    2'd1: begin result_reg_next = nums_16[0] - operand2; end
                                    2'd2: begin result_reg_next = nums_16[0] * operand2; end
                                    2'd3: begin if (operand2 != 16'd0 && (nums_16[0] % operand2) == 16'd0) begin result_reg_next = nums_16[0] / operand2; end else eval_step_next = 3'd7; end
                                endcase
                                eval_step_next = 3'd3;
                            end
                            3'd3: begin // Check result
                                if (result_reg_next == 16'd24) begin
                                    if (grade_temp_next < min_grade_next) begin
                                        min_grade_next = grade_temp_next;
                                    end
                                end
                                eval_step_next = 3'd7;
                            end
                            default: eval_step_next = 3'd7;
                        endcase

                    3'd4: // a op0 (b op1 (c op2 d))
                        case (eval_step)
                            3'd0: begin // eval c op2 d
                                case (op2)
                                    2'd0: begin operand2_next = nums_16[2] + nums_16[3]; grade_temp_next = grade_temp_next + 8'd1; end
                                    2'd1: begin operand2_next = nums_16[2] - nums_16[3]; grade_temp_next = grade_temp_next + 8'd1; end
                                    2'd2: begin operand2_next = nums_16[2] * nums_16[3]; grade_temp_next = grade_temp_next + 8'd1; end
                                    2'd3: begin if (nums_16[3] != 16'd0 && (nums_16[2] % nums_16[3]) == 16'd0) begin operand2_next = nums_16[2] / nums_16[3]; grade_temp_next = grade_temp_next + 8'd1; end else eval_step_next = 3'd7; end
                                endcase
                                eval_step_next = 3'd1;
                            end
                            3'd1: begin // eval b op1 (c op2 d)
                                case (op1)
                                    2'd0: begin operand1_next = nums_16[1] + operand2; grade_temp_next = grade_temp_next + 8'd1; end
                                    2'd1: begin operand1_next = nums_16[1] - operand2; grade_temp_next = grade_temp_next + 8'd1; end
                                    2'd2: begin operand1_next = nums_16[1] * operand2; grade_temp_next = grade_temp_next + 8'd1; end
                                    2'd3: begin if (operand2 != 16'd0 && (nums_16[1] % operand2) == 16'd0) begin operand1_next = nums_16[1] / operand2; grade_temp_next = grade_temp_next + 8'd1; end else eval_step_next = 3'd7; end
                                endcase
                                eval_step_next = 3'd2;
                            end
                            3'd2: begin // eval a op0 (b op1 (c op2 d))
                                case (op0)
                                    2'd0: begin result_reg_next = nums_16[0] + operand1; end
                                    2'd1: begin result_reg_next = nums_16[0] - operand1; end
                                    2'd2: begin result_reg_next = nums_16[0] * operand1; end
                                    2'd3: begin if (operand1 != 16'd0 && (nums_16[0] % operand1) == 16'd0) begin result_reg_next = nums_16[0] / operand1; end else eval_step_next = 3'd7; end
                                endcase
                                eval_step_next = 3'd3;
                            end
                            3'd3: begin // Check result
                                if (result_reg_next == 16'd24) begin
                                    if (grade_temp_next < min_grade_next) begin
                                        min_grade_next = grade_temp_next;
                                    end
                                end
                                eval_step_next = 3'd7;
                            end
                            default: eval_step_next = 3'd7;
                        endcase
                endcase

                if (eval_step == 3'd7) begin
                    // Move to next evaluation or finish
                    if (tree_idx < 3'd4) begin
                        tree_idx_next = tree_idx + 3'd1;
                        next_state = TREE;
                    end else begin
                        // All trees done for this operator combo
                        if (op_combo < 6'd63) begin
                            op_combo_next = op_combo + 6'd1;
                            next_state = OPS;
                        end else begin
                            // All operator combos done for this permutation
                            if (perm_idx < 3'd23) begin
                                perm_idx_next = perm_idx + 3'd1;
                                next_state = PERMUTE;
                            end else begin
                                // All permutations done
                                next_state = FINISH;
                            end
                        end
                    end
                end
            end

            FINISH: begin
                done <= 1'b1;
                grade <= min_grade;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_grade <= 8'hFF;
            grade <= 8'hFF;
            done <= 1'b0;
            perm_idx <= 3'd0;
            op_combo <= 6'd0;
            tree_idx <= 3'd0;
            eval_step <= 3'd0;
            i <= 3'd0;
            j <= 3'd0;
            temp_idx <= 3'd0;
            temp_val1 <= 16'd0;
            temp_val2 <= 16'd0;
            grade_temp <= 8'd0;
            grade_current <= 8'd0;
            operand1 <= 16'd0;
            operand2 <= 16'd0;
            result_reg <= 16'd0;
            for (i = 0; i < 4; i = i + 1) begin
                nums[i] <= 8'd0;
                nums_16[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            min_grade <= min_grade_next;
            perm_idx <= perm_idx_next;
            op_combo <= op_combo_next;
            tree_idx <= tree_idx_next;
            eval_step <= eval_step_next;
            i <= i_next;
            j <= j_next;
            temp_idx <= temp_idx_next;
            temp_val1 <= temp_val1_next;
            temp_val2 <= temp_val2_next;
            grade_temp <= grade_temp_next;
            grade_current <= grade_current_next;
            operand1 <= operand1_next;
            operand2 <= operand2_next;
            result_reg <= result_reg_next;
            for (i_next = 0; i_next < 4; i_next = i_next + 1) begin
                nums[i_next] <= nums_next[i_next];
                nums_16[i_next] <= nums_16_next[i_next];
            end
            if (state == FINISH) begin
                done <= 1'b1;
                grade <= min_grade;
            end else if (state == IDLE) begin
                done <= 1'b0;
                grade <= 8'hFF;
            end
        end
    end

endmodule