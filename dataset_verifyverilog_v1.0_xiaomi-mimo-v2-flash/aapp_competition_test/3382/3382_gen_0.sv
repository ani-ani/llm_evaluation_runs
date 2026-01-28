module challenge24 (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] in0, in1, in2, in3,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE   = 3'd0;
    localparam [2:0] PERM   = 3'd1;
    localparam [2:0] OPS    = 3'd2;
    localparam [2:0] PAREN  = 3'd3;
    localparam [2:0] EVAL   = 3'd4;
    localparam [2:0] CHECK  = 3'd5;
    localparam [2:0] DONE   = 3'd6;

    // Operator definitions
    localparam [1:0] OP_MUL = 2'd0;
    localparam [1:0] OP_ADD = 2'd1;
    localparam [1:0] OP_SUB = 2'd2;
    localparam [1:0] OP_DIV = 2'd3;

    // Parenthesization mode definitions (0-4)
    localparam [2:0] MODE_0 = 3'd0;  // A+B+C+D
    localparam [2:0] MODE_1 = 3'd1;  // A+(B+C)+D
    localparam [2:0] MODE_2 = 3'd2;  // (A+B)+(C+D)
    localparam [2:0] MODE_3 = 3'd3;  // (A+(B+C))+D
    localparam [2:0] MODE_4 = 3'd4;  // A+((B+C)+D)

    // Registers
    reg [2:0] state, next_state;
    reg [4:0] perm_counter;      // 0-23 for permutations
    reg [5:0] ops_counter;       // 0-63 for operator combos
    reg [2:0] paren_counter;     // 0-4 for paren modes
    reg [7:0] min_grade;         // Track minimum grade found
    reg grade_found;             // Flag if 24 achievable
    reg [7:0] cycle_count;       // For timeout protection
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Input storage
    reg [7:0] inputs [0:3];
    reg [7:0] original_order [0:3];

    // Permutation storage (indices into original array)
    reg [1:0] perm_indices [0:3];

    // Operator storage
    reg [1:0] ops [0:2];

    // Computation registers
    reg signed [31:0] val0, val1, val2, val3;
    reg signed [31:0] temp_val1, temp_val2, temp_val3, final_val;
    reg [7:0] current_grade;
    reg valid_expr;

    // Permutation generation - base-4 encoding
    wire [1:0] p0, p1, p2, p3;
    assign p0 = perm_counter[1:0];
    assign p1 = perm_counter[3:2];
    assign p2 = perm_counter[4] ? (perm_counter[1:0] + 2'd1) : (perm_counter[1:0] + 2'd2);
    assign p3 = perm_counter[4] ? (perm_counter[3:2] + 2'd2) : (perm_counter[3:2] + 2'd1);

    // Operator extraction from ops_counter (6-bit: 2 bits per operator)
    wire [1:0] op0, op1, op2;
    assign op0 = ops_counter[1:0];
    assign op1 = ops_counter[3:2];
    assign op2 = ops_counter[5:4];

    // Helper: Get value by index
    function signed [31:0] get_val;
        input [1:0] idx;
        case (idx)
            2'd0: get_val = {24'd0, inputs[0]};
            2'd1: get_val = {24'd0, inputs[1]};
            2'd2: get_val = {24'd0, inputs[2]};
            2'd3: get_val = {24'd0, inputs[3]};
            default: get_val = 32'd0;
        endcase
    endfunction

    // Helper: Perform operation
    function signed [31:0] do_op;
        input signed [31:0] a;
        input signed [31:0] b;
        input [1:0] op;
        begin
            case (op)
                OP_MUL: do_op = a * b;
                OP_ADD: do_op = a + b;
                OP_SUB: do_op = a - b;
                OP_DIV: do_op = (b != 32'd0 && (a % b) == 32'd0) ? a / b : 32'sh7FFFFFFF;
                default: do_op = 32'd0;
            endcase
        end
    endfunction

    // Helper: Calculate grade
    function [7:0] calc_grade;
        input [2:0] mode;
        reg [7:0] inversions;
        reg [7:0] paren_count;
        integer i, j;
        begin
            // Calculate inversions
            inversions = 8'd0;
            for (i = 0; i < 4; i = i + 1) begin
                for (j = i + 1; j < 4; j = j + 1) begin
                    if (original_order[perm_indices[i]] > original_order[perm_indices[j]]) begin
                        inversions = inversions + 8'd1;
                    end
                end
            end

            // Parentheses count based on mode
            case (mode)
                MODE_0: paren_count = 8'd0;
                default: paren_count = 8'd2; // Modes 1-4 all have 2 parens
            endcase

            calc_grade = 8'd2 * inversions + 8'd2 * paren_count;
        end
    endfunction

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            perm_counter <= 5'd0;
            ops_counter <= 6'd0;
            paren_counter <= 3'd0;
            min_grade <= 8'd255;
            grade_found <= 1'b0;
            cycle_count <= 8'd0;
            inputs[0] <= 8'd0;
            inputs[1] <= 8'd0;
            inputs[2] <= 8'd0;
            inputs[3] <= 8'd0;
            original_order[0] <= 8'd0;
            original_order[1] <= 8'd0;
            original_order[2] <= 8'd0;
            original_order[3] <= 8'd0;
            perm_indices[0] <= 2'd0;
            perm_indices[1] <= 2'd0;
            perm_indices[2] <= 2'd0;
            perm_indices[3] <= 2'd0;
            ops[0] <= 2'd0;
            ops[1] <= 2'd0;
            ops[2] <= 2'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Store inputs
                        inputs[0] <= in0;
                        inputs[1] <= in1;
                        inputs[2] <= in2;
                        inputs[3] <= in3;
                        original_order[0] <= in0;
                        original_order[1] <= in1;
                        original_order[2] <= in2;
                        original_order[3] <= in3;
                        // Reset counters
                        perm_counter <= 5'd0;
                        ops_counter <= 6'd0;
                        paren_counter <= 3'd0;
                        min_grade <= 8'd255;
                        grade_found <= 1'b0;
                        state <= PERM;
                    end
                end

                PERM: begin
                    // Store current permutation indices
                    perm_indices[0] <= p0;
                    perm_indices[1] <= p1;
                    perm_indices[2] <= p2;
                    perm_indices[3] <= p3;
                    ops_counter <= 6'd0;
                    state <= OPS;
                end

                OPS: begin
                    // Store current operators
                    ops[0] <= op0;
                    ops[1] <= op1;
                    ops[2] <= op2;
                    paren_counter <= 3'd0;
                    state <= PAREN;
                end

                PAREN: begin
                    // Get values for current permutation
                    val0 <= get_val(perm_indices[0]);
                    val1 <= get_val(perm_indices[1]);
                    val2 <= get_val(perm_indices[2]);
                    val3 <= get_val(perm_indices[3]);
                    state <= EVAL;
                end

                EVAL: begin
                    valid_expr <= 1'b1;
                    case (paren_counter)
                        MODE_0: begin // A op0 B op1 C op2 D
                            temp_val1 <= do_op(val0, val1, ops[0]);
                            temp_val2 <= do_op(temp_val1, val2, ops[1]);
                            final_val <= do_op(temp_val2, val3, ops[2]);
                        end
                        MODE_1: begin // A + (B + C) + D
                            // ops[0]=+, ops[1]=+, ops[2]=+
                            temp_val1 <= do_op(val1, val2, OP_ADD);
                            temp_val2 <= do_op(val0, temp_val1, OP_ADD);
                            final_val <= do_op(temp_val2, val3, OP_ADD);
                        end
                        MODE_2: begin // (A + B) + (C + D)
                            temp_val1 <= do_op(val0, val1, OP_ADD);
                            temp_val2 <= do_op(val2, val3, OP_ADD);
                            final_val <= do_op(temp_val1, temp_val2, OP_ADD);
                        end
                        MODE_3: begin // (A + (B + C)) + D
                            temp_val1 <= do_op(val1, val2, OP_ADD);
                            temp_val2 <= do_op(val0, temp_val1, OP_ADD);
                            final_val <= do_op(temp_val2, val3, OP_ADD);
                        end
                        MODE_4: begin // A + ((B + C) + D)
                            temp_val1 <= do_op(val1, val2, OP_ADD);
                            temp_val2 <= do_op(temp_val1, val3, OP_ADD);
                            final_val <= do_op(val0, temp_val2, OP_ADD);
                        end
                        default: begin
                            final_val <= 32'd0;
                        end
                    endcase
                    
                    // Check for division errors
                    if (ops[0] == OP_DIV && (val1 == 32'd0 || (val0 % val1) != 32'd0)) begin
                        valid_expr <= 1'b0;
                    end
                    if (ops[1] == OP_DIV && (val2 == 32'd0 || (temp_val1 % val2) != 32'd0)) begin
                        valid_expr <= 1'b0;
                    end
                    if (ops[2] == OP_DIV && (val3 == 32'd0 || (temp_val2 % val3) != 32'd0)) begin
                        valid_expr <= 1'b0;
                    end
                    state <= CHECK;
                end

                CHECK: begin
                    if (valid_expr && final_val == 32'd24) begin
                        current_grade <= calc_grade(paren_counter);
                        if (calc_grade(paren_counter) < min_grade) begin
                            min_grade <= calc_grade(paren_counter);
                            grade_found <= 1'b1;
                            // Early exit if grade 0 found
                            if (calc_grade(paren_counter) == 8'd0) begin
                                state <= DONE;
                            end else begin
                                // Continue to next combination
                                if (paren_counter < 3'd4) begin
                                    paren_counter <= paren_counter + 3'd1;
                                    state <= PAREN;
                                end else if (ops_counter < 6'd63) begin
                                    ops_counter <= ops_counter + 6'd1;
                                    state <= OPS;
                                end else if (perm_counter < 5'd23) begin
                                    perm_counter <= perm_counter + 5'd1;
                                    state <= PERM;
                                end else begin
                                    state <= DONE;
                                end
                            end
                        end else begin
                            // Continue to next combination
                            if (paren_counter < 3'd4) begin
                                paren_counter <= paren_counter + 3'd1;
                                state <= PAREN;
                            end else if (ops_counter < 6'd63) begin
                                ops_counter <= ops_counter + 6'd1;
                                state <= OPS;
                            end else if (perm_counter < 5'd23) begin
                                perm_counter <= perm_counter + 5'd1;
                                state <= PERM;
                            end else begin
                                state <= DONE;
                            end
                        end
                    end else begin
                        // Expression invalid or not 24
                        if (paren_counter < 3'd4) begin
                            paren_counter <= paren_counter + 3'd1;
                            state <= PAREN;
                        end else if (ops_counter < 6'd63) begin
                            ops_counter <= ops_counter + 6'd1;
                            state <= OPS;
                        end else if (perm_counter < 5'd23) begin
                            perm_counter <= perm_counter + 5'd1;
                            state <= PERM;
                        end else begin
                            state <= DONE;
                        end
                    end
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    if (grade_found) begin
                        result <= min_grade;
                    end else begin
                        result <= 8'd255;
                    end
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule