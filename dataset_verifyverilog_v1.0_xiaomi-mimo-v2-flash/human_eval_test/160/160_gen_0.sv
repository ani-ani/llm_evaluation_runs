module algebra_evaluator (
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

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] CALCULATE = 3'd2;
    localparam [2:0] COMPLETE = 3'd3;
    localparam [2:0] ERROR_STATE = 3'd4;

    // Operation encoding
    localparam [2:0] OP_ADD = 3'd0;
    localparam [2:0] OP_SUB = 3'd1;
    localparam [2:0] OP_MUL = 3'd2;
    localparam [2:0] OP_DIV = 3'd3;
    localparam [2:0] OP_POW = 3'd4;

    // Registers for storage
    reg [7:0] operands_reg [0:7];  // 8 operands
    reg [2:0] operators_reg [0:6];  // 7 operators (for max 8 operands)
    reg [2:0] state, next_state;
    reg [15:0] accumulator;
    reg [15:0] temp_reg;
    reg [7:0] operand_ptr;
    reg [7:0] cycle_counter;
    reg [7:0] exp_counter;
    reg [7:0] divisor_reg;
    
    // Timeout counters
    localparam [7:0] MAX_CAL_CYCLES = 8'd100;
    localparam [7:0] MAX_TOTAL_CYCLES = 8'd200;
    localparam [7:0] MAX_OP_CYCLES = 8'd8;
    localparam [7:0] MAX_EXPONENT = 8'd8;
    
    // Overflow detection
    wire overflow_add;
    wire overflow_sub;
    wire overflow_mul;
    assign overflow_add = (accumulator[15] && !temp_reg[15] && !operands_reg[operand_ptr][7]) || 
                          (!accumulator[15] && temp_reg[15] && operands_reg[operand_ptr][7]);
    assign overflow_sub = (accumulator[15] && !temp_reg[15] && operands_reg[operand_ptr][7]) || 
                          (!accumulator[15] && temp_reg[15] && !operands_reg[operand_ptr][7]);
    assign overflow_mul = (temp_reg != (accumulator * operands_reg[operand_ptr]));

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            error <= 1'b0;
            accumulator <= 16'd0;
            temp_reg <= 16'd0;
            operand_ptr <= 8'd0;
            cycle_counter <= 8'd0;
            exp_counter <= 8'd0;
            divisor_reg <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                operands_reg[i] <= 8'd0;
            end
            for (i = 0; i < 7; i = i + 1) begin
                operators_reg[i] <= 3'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    cycle_counter <= 8'd0;
                    if (config_done && start) begin
                        state <= LOAD;
                        operand_ptr <= 8'd0;
                    end
                end
                
                LOAD: begin
                    if (operand_ptr < 8'd8) begin
                        // Store operand
                        operands_reg[operand_ptr] <= operand;
                        operand_ptr <= operand_ptr + 8'd1;
                        // Also check for operator at same time
                        if (operand_ptr < 8'd7 && operator_index < 3'd7) begin
                            operators_reg[operator_index] <= operator;
                        end
                    end else begin
                        // Load remaining operators if any
                        if (operator_index < 3'd7) begin
                            operators_reg[operator_index] <= operator;
                        end
                        // Start calculation when config complete
                        state <= CALCULATE;
                        accumulator <= {8'd0, operands_reg[0]};
                        operand_ptr <= 8'd0;
                        cycle_counter <= 8'd0;
                    end
                end
                
                CALCULATE: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    
                    if (operand_ptr >= 8'd7 || cycle_counter >= MAX_CAL_CYCLES) begin
                        state <= COMPLETE;
                    end else begin
                        case (operators_reg[operand_ptr])
                            OP_ADD: begin
                                temp_reg <= accumulator + {8'd0, operands_reg[operand_ptr + 1]};
                                if (temp_reg[15:8] != 8'd0 && temp_reg[15:8] != 8'hFF) begin
                                    accumulator <= temp_reg;
                                end else begin
                                    error <= 1'b1;
                                    state <= ERROR_STATE;
                                end
                                operand_ptr <= operand_ptr + 8'd1;
                            end
                            
                            OP_SUB: begin
                                temp_reg <= accumulator - {8'd0, operands_reg[operand_ptr + 1]};
                                if (temp_reg[15] || temp_reg[15:8] == 8'hFF) begin
                                    error <= 1'b1;
                                    state <= ERROR_STATE;
                                end else begin
                                    accumulator <= temp_reg;
                                end
                                operand_ptr <= operand_ptr + 8'd1;
                            end
                            
                            OP_MUL: begin
                                // Multiplication: 16x8 = 24 bits, keep middle 16
                                temp_reg <= (accumulator * operands_reg[operand_ptr + 1]) >> 8;
                                if (temp_reg[15:8] != 8'd0 && temp_reg[15:8] != 8'hFF) begin
                                    error <= 1'b1;
                                    state <= ERROR_STATE;
                                end else begin
                                    accumulator <= temp_reg;
                                end
                                operand_ptr <= operand_ptr + 8'd1;
                            end
                            
                            OP_DIV: begin
                                divisor_reg <= operands_reg[operand_ptr + 1];
                                if (divisor_reg == 8'd0) begin
                                    error <= 1'b1;
                                    state <= ERROR_STATE;
                                end else begin
                                    // Integer division: (accumulator / divisor) << 8
                                    temp_reg <= (accumulator << 8) / divisor_reg;
                                    if (temp_reg[15:8] != 8'd0) begin
                                        error <= 1'b1;
                                        state <= ERROR_STATE;
                                    end else begin
                                        accumulator <= temp_reg;
                                    end
                                    operand_ptr <= operand_ptr + 8'd1;
                                end
                            end
                            
                            OP_POW: begin
                                // Exponentiation with limit
                                if (cycle_counter >= MAX_OP_CYCLES || 
                                    operands_reg[operand_ptr + 1] >= MAX_EXPONENT) begin
                                    error <= 1'b1;
                                    state <= ERROR_STATE;
                                end else if (exp_counter < operands_reg[operand_ptr + 1]) begin
                                    if (exp_counter == 8'd0) begin
                                        temp_reg <= {8'd0, operands_reg[operand_ptr]};
                                        exp_counter <= 8'd1;
                                    end else begin
                                        temp_reg <= temp_reg * {8'd0, operands_reg[operand_ptr]};
                                        if (temp_reg[15:8] != 8'd0) begin
                                            error <= 1'b1;
                                            state <= ERROR_STATE;
                                        end
                                        exp_counter <= exp_counter + 8'd1;
                                    end
                                end else begin
                                    accumulator <= temp_reg;
                                    exp_counter <= 8'd0;
                                    operand_ptr <= operand_ptr + 8'd1;
                                end
                            end
                            
                            default: begin
                                error <= 1'b1;
                                state <= ERROR_STATE;
                            end
                        endcase
                    end
                end
                
                COMPLETE: begin
                    result <= accumulator;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                ERROR_STATE: begin
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