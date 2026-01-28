module algebra_evaluator(
    input clk,
    input rst_n,
    input start,
    input [2:0] operator,
    input [7:0] operand,
    input [2:0] operator_index,
    input [2:0] operand_index,
    input config_done,
    output reg [15:0] result,
    output reg done,
    output reg error
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] LOAD      = 2'd1;
    localparam [1:0] CALCULATE = 2'd2;
    localparam [1:0] COMPLETE  = 2'd3;

    // Operator encoding
    localparam [2:0] OP_ADD      = 3'd0;
    localparam [2:0] OP_SUB      = 3'd1;
    localparam [2:0] OP_MUL      = 3'd2;
    localparam [2:0] OP_DIV      = 3'd3;
    localparam [2:0] OP_POW      = 3'd4;

    // Registers
    reg [1:0] state;
    reg [7:0] operands [0:7];
    reg [2:0] operators [0:6];
    reg [15:0] accumulator;
    reg [15:0] temp_result;
    reg [7:0] cycle_count;
    reg [7:0] op_count;
    reg [7:0] current_op_index;
    reg [7:0] current_operand_index;
    reg [7:0] exponent_counter;
    reg [15:0] pow_temp;
    reg [15:0] div_temp;
    reg [7:0] div_counter;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            error <= 1'b0;
            cycle_count <= 8'd0;
            op_count <= 8'd0;
            current_op_index <= 8'd0;
            current_operand_index <= 8'd0;
            accumulator <= 16'd0;
            temp_result <= 16'd0;
            exponent_counter <= 8'd0;
            pow_temp <= 16'd0;
            div_temp <= 16'd0;
            div_counter <= 8'd0;

            // Initialize operands and operators
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                operands[i] <= 8'd0;
            end
            for (i = 0; i < 7; i = i + 1) begin
                operators[i] <= 3'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    if (config_done) begin
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    // Load operands and operators
                    if (operand_index < 8) begin
                        operands[operand_index] <= operand;
                    end
                    if (operator_index < 7) begin
                        operators[operator_index] <= operator;
                    end

                    if (config_done && start) begin
                        // Initialize for calculation
                        accumulator <= {8'd0, operands[0]}; // Q8.8 format
                        op_count <= 8'd0;
                        current_op_index <= 8'd0;
                        current_operand_index <= 8'd1;
                        cycle_count <= 8'd0;
                        state <= CALCULATE;
                    end
                end

                CALCULATE: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Check for timeout
                    if (cycle_count >= 8'd100) begin
                        error <= 1'b1;
                        state <= COMPLETE;
                    end else begin
                        // Perform current operation
                        case (operators[current_op_index])
                            OP_ADD: begin
                                temp_result <= accumulator + {8'd0, operands[current_operand_index]};
                                // Check overflow
                                if (temp_result[15] !== accumulator[15] && temp_result[15] !== {8'd0, operands[current_operand_index]}[15]) begin
                                    error <= 1'b1;
                                end
                                accumulator <= temp_result;
                                current_op_index <= current_op_index + 8'd1;
                                current_operand_index <= current_operand_index + 8'd1;
                                op_count <= op_count + 8'd1;
                            end

                            OP_SUB: begin
                                temp_result <= accumulator - {8'd0, operands[current_operand_index]};
                                // Check underflow
                                if (temp_result[15] !== accumulator[15] && temp_result[15] !== ~{8'd0, operands[current_operand_index]}[15]) begin
                                    error <= 1'b1;
                                end
                                accumulator <= temp_result;
                                current_op_index <= current_op_index + 8'd1;
                                current_operand_index <= current_operand_index + 8'd1;
                                op_count <= op_count + 8'd1;
                            end

                            OP_MUL: begin
                                temp_result <= accumulator * {8'd0, operands[current_operand_index]};
                                // Clamp to 16 bits
                                accumulator <= temp_result[15:0];
                                current_op_index <= current_op_index + 8'd1;
                                current_operand_index <= current_operand_index + 8'd1;
                                op_count <= op_count + 8'd1;
                            end

                            OP_DIV: begin
                                if (operands[current_operand_index] == 8'd0) begin
                                    error <= 1'b1;
                                    state <= COMPLETE;
                                end else begin
                                    div_temp <= accumulator;
                                    div_counter <= 8'd0;
                                    // Simple integer division
                                    while (div_counter < 8'd8 && div_temp >= {8'd0, operands[current_operand_index]}) begin
                                        div_temp <= div_temp - {8'd0, operands[current_operand_index]};
                                        div_counter <= div_counter + 8'd1;
                                    end
                                    accumulator <= div_temp;
                                    current_op_index <= current_op_index + 8'd1;
                                    current_operand_index <= current_operand_index + 8'd1;
                                    op_count <= op_count + 8'd1;
                                end
                            end

                            OP_POW: begin
                                if (operands[current_operand_index] > 8'd8) begin
                                    error <= 1'b1;
                                    state <= COMPLETE;
                                end else begin
                                    pow_temp <= {8'd0, operands[current_operand_index]};
                                    exponent_counter <= operands[current_operand_index] - 8'd1;
                                    temp_result <= accumulator;

                                    // Iterative multiplication
                                    while (exponent_counter > 8'd0) begin
                                        temp_result <= temp_result * pow_temp;
                                        // Clamp to 16 bits
                                        temp_result <= temp_result[15:0];
                                        exponent_counter <= exponent_counter - 8'd1;
                                    end

                                    accumulator <= temp_result;
                                    current_op_index <= current_op_index + 8'd1;
                                    current_operand_index <= current_operand_index + 8'd1;
                                    op_count <= op_count + 8'd1;
                                end
                            end

                            default: begin
                                error <= 1'b1;
                                state <= COMPLETE;
                            end
                        endcase

                        // Check if all operations are done
                        if (op_count >= 8'd7 || current_operand_index >= 8'd8) begin
                            state <= COMPLETE;
                        end
                    end
                end

                COMPLETE: begin
                    done <= 1'b1;
                    result <= accumulator;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule