module algebra_eval (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_operators,
    input [7:0][2:0] operator,
    input [7:0][31:0] operand,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE              = 3'd0;
    localparam [2:0] CHECK_PRECEDENCE  = 3'd1;
    localparam [2:0] CALCULATE         = 3'd2;
    localparam [2:0] ADVANCE_POINTER   = 3'd3;
    localparam [2:0] DONE_STATE        = 3'd4;

    // Operation type encoding
    localparam [2:0] OP_ADD   = 3'd0;
    localparam [2:0] OP_SUB   = 3'd1;
    localparam [2:0] OP_MUL   = 3'd2;
    localparam [2:0] OP_DIV   = 3'd3;
    localparam [2:0] OP_EXP   = 3'd4;

    // State machine registers
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Control registers
    reg [3:0] pass_counter;           // 0: first pass, 1: second pass
    reg [3:0] op_index;               // Current operator index being evaluated
    reg [3:0] valid_ops_count;        // Number of operators to process in current pass
    reg [3:0] i;                      // Loop counter
    
    // Computation registers
    reg [31:0] temp_result;
    reg [31:0] temp_operand_a;
    reg [31:0] temp_operand_b;
    reg [2:0]  current_op;
    reg [31:0] operands_reg [0:8];    // Local copy of operands (9 max)
    reg [2:0]  operators_reg [0:7];   // Local copy of operators (8 max)
    reg [7:0]  cycle_count;           // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Exponentiation helper registers
    reg [31:0] exp_base;
    reg [31:0] exp_result;
    reg [4:0]  exp_counter;           // Limit exponent to 16
    reg        exp_done;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            pass_counter <= 2'd0;
            op_index <= 4'd0;
            valid_ops_count <= 4'd0;
            temp_result <= 32'd0;
            temp_operand_a <= 32'd0;
            temp_operand_b <= 32'd0;
            current_op <= 3'd0;
            cycle_count <= 8'd0;
            exp_base <= 32'd0;
            exp_result <= 32'd0;
            exp_counter <= 5'd0;
            exp_done <= 1'b0;
            // Initialize arrays
            for (i = 0; i < 9; i = i + 1) begin
                operands_reg[i] <= 32'd0;
            end
            for (i = 0; i < 8; i = i + 1) begin
                operators_reg[i] <= 3'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    pass_counter <= 2'd0;
                    op_index <= 4'd0;
                    
                    if (start) begin
                        // Copy inputs to local registers
                        for (i = 0; i < 9; i = i + 1) begin
                            operands_reg[i] <= operand[i];
                        end
                        for (i = 0; i < 8; i = i + 1) begin
                            operators_reg[i] <= operator[i];
                        end
                        valid_ops_count <= {1'b0, num_operators};
                        state <= CHECK_PRECEDENCE;
                    end
                end

                CHECK_PRECEDENCE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if we've processed all operators in this pass
                    if (op_index >= valid_ops_count) begin
                        // End of current pass
                        if (pass_counter == 2'd0) begin
                            // First pass complete, start second pass
                            pass_counter <= 2'd1;
                            op_index <= 4'd0;
                            
                            // Update valid_ops_count for second pass
                            // Count remaining non-skipped operators
                            valid_ops_count <= 4'd0;
                            for (i = 0; i < 8; i = i + 1) begin
                                if (operators_reg[i] <= 3'd1) begin
                                    valid_ops_count <= valid_ops_count + 4'd1;
                                end
                            end
                            
                            if (valid_ops_count == 4'd0) begin
                                // No operators to process in second pass
                                result <= operands_reg[0];
                                state <= DONE_STATE;
                            end else begin
                                state <= CHECK_PRECEDENCE;
                            end
                        end else begin
                            // Second pass complete
                            result <= operands_reg[0];
                            state <= DONE_STATE;
                        end
                    end else begin
                        // Check current operator precedence
                        current_op <= operators_reg[op_index];
                        
                        // First pass: handle high precedence (2, 3, 4)
                        // Second pass: handle low precedence (0, 1)
                        if (pass_counter == 2'd0 && (operators_reg[op_index] >= 3'd2 && operators_reg[op_index] <= 3'd4)) begin
                            temp_operand_a <= operands_reg[op_index];
                            temp_operand_b <= operands_reg[op_index + 4'd1];
                            state <= CALCULATE;
                        end else if (pass_counter == 2'd1 && (operators_reg[op_index] <= 3'd1)) begin
                            temp_operand_a <= operands_reg[op_index];
                            temp_operand_b <= operands_reg[op_index + 4'd1];
                            state <= CALCULATE;
                        end else begin
                            // Skip this operator
                            op_index <= op_index + 4'd1;
                            state <= CHECK_PRECEDENCE;
                        end
                    end
                end

                CALCULATE: begin
                    case (current_op)
                        OP_ADD: begin
                            temp_result <= temp_operand_a + temp_operand_b;
                            state <= ADVANCE_POINTER;
                        end
                        
                        OP_SUB: begin
                            temp_result <= temp_operand_a - temp_operand_b;
                            state <= ADVANCE_POINTER;
                        end
                        
                        OP_MUL: begin
                            // Q16.16: multiply then shift right by 16
                            // Result = (a * b) >> 16
                            // Use 64-bit intermediate
                            temp_result <= (temp_operand_a * temp_operand_b) >> 16;
                            state <= ADVANCE_POINTER;
                        end
                        
                        OP_DIV: begin
                            // Q16.16: shift left by 16 then divide
                            // Result = (a << 16) / b
                            // Check for division by zero
                            if (temp_operand_b == 32'd0) begin
                                temp_result <= 32'd0;  // Handle div by zero
                            end else begin
                                temp_result <= ({temp_operand_a, 16'd0} / temp_operand_b);
                            end
                            state <= ADVANCE_POINTER;
                        end
                        
                        OP_EXP: begin
                            // Exponentiation: integer exponentiation
                            // base and exponent as integers, result as Q16.16
                            if (exp_done) begin
                                // Exponentiation complete
                                temp_result <= exp_result;
                                exp_done <= 1'b0;
                                exp_counter <= 5'd0;
                                state <= ADVANCE_POINTER;
                            end else begin
                                // Initialize or continue exponentiation
                                if (exp_counter == 5'd0) begin
                                    exp_base <= temp_operand_a[31:16];  // Integer part
                                    exp_result <= temp_operand_b[31:16];  // Exponent as integer
                                    exp_counter <= 5'd1;
                                end else if (exp_counter < exp_result[4:0] && exp_counter < 5'd16) begin
                                    // Multiply by base
                                    exp_base <= exp_base * exp_result[15:0];
                                    exp_counter <= exp_counter + 5'd1;
                                end else begin
                                    // Complete: result in Q16.16 format (integer part in high bits)
                                    exp_result <= exp_base << 16;
                                    exp_done <= 1'b1;
                                end
                            end
                            state <= CALCULATE;  // Stay in this state
                        end
                        
                        default: begin
                            temp_result <= 32'd0;
                            state <= ADVANCE_POINTER;
                        end
                    endcase
                end

                ADVANCE_POINTER: begin
                    // Store result and shift remaining operands
                    operands_reg[op_index] <= temp_result;
                    
                    // Shift operands down by one position
                    // operands[op_index+1] becomes operands[op_index+2], etc.
                    for (i = op_index + 4'd1; i < valid_ops_count; i = i + 1) begin
                        operands_reg[i] <= operands_reg[i + 4'd1];
                    end
                    
                    // Mark operator as processed (set to invalid value)
                    operators_reg[op_index] <= 3'd7;  // Invalid op code
                    
                    // Shift operators down by one position
                    for (i = op_index; i < valid_ops_count - 4'd1; i = i + 1) begin
                        operators_reg[i] <= operators_reg[i + 4'd1];
                    end
                    
                    // Don't increment op_index, since array shifted
                    // But decrement valid_ops_count
                    valid_ops_count <= valid_ops_count - 4'd1;
                    
                    // Reset for next operation
                    exp_counter <= 5'd0;
                    exp_done <= 1'b0;
                    
                    state <= CHECK_PRECEDENCE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule