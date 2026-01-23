module challenge24 (
    input clk,
    input rst_n,
    input start,
    input [7:0] val0,
    input [7:0] val1,
    input [7:0] val2,
    input [7:0] val3,
    output reg [3:0] min_grade,
    output reg found,
    output reg done
);

    // State definitions
    typedef enum logic [4:0] {
        IDLE,
        LOAD_PERM,
        CALCULATE,
        NEXT_OP,
        NEXT_PERM,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Permutation tracking
    reg [7:0] perm_vals [0:3];
    reg [5:0] perm_counter;
    reg [3:0] perm_inversion_cost;

    // Operator tracking
    reg [1:0] op0, op1, op2;
    reg [5:0] op_counter;

    // Parentheses tracking
    reg [2:0] paren_case;

    // Calculation tracking
    reg [31:0] a, b, c, d;
    reg [31:0] temp0, temp1, temp2, temp3;
    reg [31:0] result;
    reg valid_result;

    // Grade tracking
    reg [3:0] current_grade;
    reg [3:0] best_grade;
    reg best_found;

    // Permutation generation
    reg [5:0] perm_index;
    reg [7:0] perm_temp [0:3];

    // Operator definitions
    localparam OP_ADD = 2'b00;
    localparam OP_SUB = 2'b01;
    localparam OP_MUL = 2'b10;
    localparam OP_DIV = 2'b11;

    // Parentheses cost
    localparam [2:0] PAREN_COST [0:4] = '{0, 1, 1, 2, 2};

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            min_grade <= 4'b1111;
            found <= 1'b0;
            done <= 1'b0;
            perm_counter <= 6'b0;
            op_counter <= 6'b0;
            paren_case <= 3'b0;
            best_grade <= 4'b1111;
            best_found <= 1'b0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = LOAD_PERM;
            end
            LOAD_PERM: begin
                next_state = CALCULATE;
            end
            CALCULATE: begin
                next_state = NEXT_OP;
            end
            NEXT_OP: begin
                if (op_counter == 6'b111111) begin
                    next_state = NEXT_PERM;
                end else begin
                    next_state = CALCULATE;
                end
            end
            NEXT_PERM: begin
                if (perm_counter == 6'b101111) begin
                    next_state = DONE;
                end else begin
                    next_state = LOAD_PERM;
                end
            end
            DONE: begin
                next_state = IDLE;
            end
        endcase
    end

    // Permutation generation
    always @(posedge clk) begin
        if (!rst_n) begin
            perm_counter <= 6'b0;
            perm_index <= 6'b0;
        end else if (current_state == LOAD_PERM) begin
            // Generate next permutation
            perm_index <= perm_counter;
            perm_temp[0] <= val0;
            perm_temp[1] <= val1;
            perm_temp[2] <= val2;
            perm_temp[3] <= val3;

            // Calculate inversion cost
            perm_inversion_cost <= 0;
            for (int i = 0; i < 4; i++) begin
                for (int j = i+1; j < 4; j++) begin
                    if (perm_temp[i] > perm_temp[j]) begin
                        perm_inversion_cost <= perm_inversion_cost + 1;
                    end
                end
            end

            // Store permutation
            perm_vals[0] <= perm_temp[0];
            perm_vals[1] <= perm_temp[1];
            perm_vals[2] <= perm_temp[2];
            perm_vals[3] <= perm_temp[3];
        end
    end

    // Operator generation
    always @(posedge clk) begin
        if (!rst_n) begin
            op_counter <= 6'b0;
            op0 <= OP_ADD;
            op1 <= OP_ADD;
            op2 <= OP_ADD;
        end else if (current_state == NEXT_OP) begin
            op_counter <= op_counter + 1;
            op0 <= op_counter[1:0];
            op1 <= op_counter[3:2];
            op2 <= op_counter[5:4];
        end
    end

    // Parentheses case generation
    always @(posedge clk) begin
        if (!rst_n) begin
            paren_case <= 3'b0;
        end else if (current_state == CALCULATE) begin
            paren_case <= paren_case + 1;
            if (paren_case == 5) begin
                paren_case <= 3'b0;
            end
        end
    end

    // Calculation logic
    always @(posedge clk) begin
        if (!rst_n) begin
            a <= 0;
            b <= 0;
            c <= 0;
            d <= 0;
            result <= 0;
            valid_result <= 0;
        end else if (current_state == CALCULATE) begin
            a <= perm_vals[0];
            b <= perm_vals[1];
            c <= perm_vals[2];
            d <= perm_vals[3];

            case (paren_case)
                3'b000: begin // ((a op b) op c) op d
                    // First operation
                    case (op0)
                        OP_ADD: temp0 <= a + b;
                        OP_SUB: temp0 <= a - b;
                        OP_MUL: temp0 <= a * b;
                        OP_DIV: begin
                            if (b != 0 && a % b == 0) temp0 <= a / b;
                            else valid_result <= 0;
                        end
                    endcase
                    // Second operation
                    case (op1)
                        OP_ADD: temp1 <= temp0 + c;
                        OP_SUB: temp1 <= temp0 - c;
                        OP_MUL: temp1 <= temp0 * c;
                        OP_DIV: begin
                            if (c != 0 && temp0 % c == 0) temp1 <= temp0 / c;
                            else valid_result <= 0;
                        end
                    endcase
                    // Third operation
                    case (op2)
                        OP_ADD: result <= temp1 + d;
                        OP_SUB: result <= temp1 - d;
                        OP_MUL: result <= temp1 * d;
                        OP_DIV: begin
                            if (d != 0 && temp1 % d == 0) result <= temp1 / d;
                            else valid_result <= 0;
                        end
                    endcase
                end
                3'b001: begin // (a op (b op c)) op d
                    // First operation
                    case (op1)
                        OP_ADD: temp0 <= b + c;
                        OP_SUB: temp0 <= b - c;
                        OP_MUL: temp0 <= b * c;
                        OP_DIV: begin
                            if (c != 0 && b % c == 0) temp0 <= b / c;
                            else valid_result <= 0;
                        end
                    endcase
                    // Second operation
                    case (op0)
                        OP_ADD: temp1 <= a + temp0;
                        OP_SUB: temp1 <= a - temp0;
                        OP_MUL: temp1 <= a * temp0;
                        OP_DIV: begin
                            if (temp0 != 0 && a % temp0 == 0) temp1 <= a / temp0;
                            else valid_result <= 0;
                        end
                    endcase
                    // Third operation
                    case (op2)
                        OP_ADD: result <= temp1 + d;
                        OP_SUB: result <= temp1 - d;
                        OP_MUL: result <= temp1 * d;
                        OP_DIV: begin
                            if (d != 0 && temp1 % d == 0) result <= temp1 / d;
                            else valid_result <= 0;
                        end
                    endcase
                end
                3'b010: begin // a op ((b op c) op d)
                    // First operation
                    case (op1)
                        OP_ADD: temp0 <= b + c;
                        OP_SUB: temp0 <= b - c;
                        OP_MUL: temp0 <= b * c;
                        OP_DIV: begin
                            if (c != 0 && b % c == 0) temp0 <= b / c;
                            else valid_result <= 0;
                        end
                    endcase
                    // Second operation
                    case (op2)
                        OP_ADD: temp1 <= temp0 + d;
                        OP_SUB: temp1 <= temp0 - d;
                        OP_MUL: temp1 <= temp0 * d;
                        OP_DIV: begin
                            if (d != 0 && temp0 % d == 0) temp1 <= temp0 / d;
                            else valid_result <= 0;
                        end
                    endcase
                    // Third operation
                    case (op0)
                        OP_ADD: result <= a + temp1;
                        OP_SUB: result <= a - temp1;
                        OP_MUL: result <= a * temp1;
                        OP_DIV: begin
                            if (temp1 != 0 && a % temp1 == 0) result <= a / temp1;
                            else valid_result <= 0;
                        end
                    endcase
                end
                3'b011: begin // a op (b op (c op d))
                    // First operation
                    case (op2)
                        OP_ADD: temp0 <= c + d;
                        OP_SUB: temp0 <= c - d;
                        OP_MUL: temp0 <= c * d;
                        OP_DIV: begin
                            if (d != 0 && c % d == 0) temp0 <= c / d;
                            else valid_result <= 0;
                        end
                    endcase
                    // Second operation
                    case (op1)
                        OP_ADD: temp1 <= b + temp0;
                        OP_SUB: temp1 <= b - temp0;
                        OP_MUL: temp1 <= b * temp0;
                        OP_DIV: begin
                            if (temp0 != 0 && b % temp0 == 0) temp1 <= b / temp0;
                            else valid_result <= 0;
                        end
                    endcase
                    // Third operation
                    case (op0)
                        OP_ADD: result <= a + temp1;
                        OP_SUB: result <= a - temp1;
                        OP_MUL: result <= a * temp1;
                        OP_DIV: begin
                            if (temp1 != 0 && a % temp1 == 0) result <= a / temp1;
                            else valid_result <= 0;
                        end
                    endcase
                end
                3'b100: begin // (a op b) op (c op d)
                    // First operation
                    case (op0)
                        OP_ADD: temp0 <= a + b;
                        OP_SUB: temp0 <= a - b;
                        OP_MUL: temp0 <= a * b;
                        OP_DIV: begin
                            if (b != 0 && a % b == 0) temp0 <= a / b;
                            else valid_result <= 0;
                        end
                    endcase
                    // Second operation
                    case (op2)
                        OP_ADD: temp1 <= c + d;
                        OP_SUB: temp1 <= c - d;
                        OP_MUL: temp1 <= c * d;
                        OP_DIV: begin
                            if (d != 0 && c % d == 0) temp1 <= c / d;
                            else valid_result <= 0;
                        end
                    endcase
                    // Third operation
                    case (op1)
                        OP_ADD: result <= temp0 + temp1;
                        OP_SUB: result <= temp0 - temp1;
                        OP_MUL: result <= temp0 * temp1;
                        OP_DIV: begin
                            if (temp1 != 0 && temp0 % temp1 == 0) result <= temp0 / temp1;
                            else valid_result <= 0;
                        end
                    endcase
                end
            endcase

            // Check result
            if (result == 24 && valid_result) begin
                current_grade <= perm_inversion_cost + PAREN_COST[paren_case];
                if (current_grade < best_grade) begin
                    best_grade <= current_grade;
                    best_found <= 1'b1;
                end
            end
        end
    end

    // Output logic
    always @(posedge clk) begin
        if (!rst_n) begin
            min_grade <= 4'b1111;
            found <= 1'b0;
            done <= 1'b0;
        end else begin
            if (current_state == DONE) begin
                min_grade <= best_grade;
                found <= best_found;
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

    // Permutation counter increment
    always @(posedge clk) begin
        if (!rst_n) begin
            perm_counter <= 6'b0;
        end else if (current_state == NEXT_PERM) begin
            perm_counter <= perm_counter + 1;
        end
    end

endmodule