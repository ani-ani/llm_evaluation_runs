module basic_interpreter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] instruction_mem [0:15],
    output reg [7:0] output_char,
    output reg output_valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] FETCH    = 3'd1;
    localparam [2:0] DECODE   = 3'd2;
    localparam [2:0] EXECUTE  = 3'd3;
    localparam [2:0] COMPLETE = 3'd4;

    // Register file for variables (A-Z)
    reg signed [15:0] regs [0:25];

    // Program counter
    reg [3:0] pc;

    // Current instruction
    reg [63:0] current_instruction;

    // Decoded instruction fields
    reg [7:0] opcode;
    reg [7:0] operand_var;
    reg signed [15:0] operand_data;
    reg [7:0] target_label;

    // Execution state
    reg [2:0] state;
    reg [7:0] char_index;
    reg [1:0] execute_cycle;

    // String storage (8 bytes per instruction)
    reg [7:0] string_data [0:7];

    // Cycle counter to prevent infinite loops
    reg [8:0] cycle_count;
    localparam [8:0] MAX_CYCLES = 9'd512;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pc <= 4'd0;
            current_instruction <= 64'd0;
            opcode <= 8'd0;
            operand_var <= 8'd0;
            operand_data <= 16'd0;
            target_label <= 8'd0;
            char_index <= 8'd0;
            execute_cycle <= 2'd0;
            output_char <= 8'd0;
            output_valid <= 1'b0;
            done <= 1'b0;
            cycle_count <= 9'd0;

            // Initialize register file
            integer i;
            for (i = 0; i < 26; i = i + 1) begin
                regs[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    output_valid <= 1'b0;
                    if (start) begin
                        state <= FETCH;
                        pc <= 4'd0;
                        cycle_count <= 9'd0;
                    end
                end

                FETCH: begin
                    current_instruction <= instruction_mem[pc];
                    state <= DECODE;
                end

                DECODE: begin
                    opcode <= current_instruction[7:0];
                    operand_var <= current_instruction[15:8];
                    operand_data <= current_instruction[31:16];
                    target_label <= current_instruction[47:40];

                    // Extract string data (8 bytes)
                    integer j;
                    for (j = 0; j < 8; j = j + 1) begin
                        string_data[j] <= current_instruction[8*j + 7: 8*j];
                    end

                    state <= EXECUTE;
                    execute_cycle <= 2'd0;
                    char_index <= 8'd0;
                end

                EXECUTE: begin
                    case (opcode)
                        // LET operation
                        8'd0: begin
                            if (execute_cycle == 2'd0) begin
                                // First cycle: compute result
                                reg signed [15:0] op1, op2, result;
                                reg [7:0] var_index;

                                // Get first operand
                                if (operand_var[7]) begin
                                    // Literal value
                                    op1 <= operand_var[6:0];
                                end else begin
                                    // Variable
                                    var_index <= operand_var[6:0];
                                    op1 <= regs[var_index];
                                end

                                // Get second operand
                                op2 <= operand_data;

                                // Perform operation
                                case (current_instruction[23:20])
                                    4'd0: result <= op1 + op2;  // +
                                    4'd1: result <= op1 - op2;  // -
                                    4'd2: result <= op1 * op2;  // *
                                    4'd3: begin  // /
                                        if (op2 != 16'd0) begin
                                            result <= op1 / op2;
                                        end else begin
                                            result <= 16'd0;
                                        end
                                    end
                                    default: result <= 16'd0;
                                endcase

                                // Store result
                                regs[operand_var[6:0]] <= result;
                                execute_cycle <= execute_cycle + 2'd1;
                            end else begin
                                // Second cycle for mul/div
                                pc <= pc + 4'd1;
                                state <= FETCH;
                                execute_cycle <= 2'd0;
                            end
                        end

                        // IF operation
                        8'd1: begin
                            reg signed [15:0] val1, val2;
                            reg [7:0] var1, var2;
                            reg condition_met;

                            // Get first value
                            var1 <= current_instruction[39:32];
                            if (var1[7]) begin
                                val1 <= var1[6:0];
                            end else begin
                                val1 <= regs[var1[6:0]];
                            end

                            // Get second value
                            var2 <= current_instruction[47:40];
                            if (var2[7]) begin
                                val2 <= var2[6:0];
                            end else begin
                                val2 <= regs[var2[6:0]];
                            end

                            // Evaluate condition
                            condition_met = 1'b0;
                            case (current_instruction[23:20])
                                4'd0: condition_met = (val1 == val2);  // =
                                4'd1: condition_met = (val1 < val2);   // <
                                4'd2: condition_met = (val1 > val2);   // >
                                4'd3: condition_met = (val1 != val2);  // <>
                                4'd4: condition_met = (val1 <= val2);  // <=
                                4'd5: condition_met = (val1 >= val2);  // >=
                                default: condition_met = 1'b0;
                            endcase

                            if (condition_met) begin
                                pc <= target_label;
                            end else begin
                                pc <= pc + 4'd1;
                            end

                            state <= FETCH;
                        end

                        // PRINT operation
                        8'd2: begin
                            if (char_index < 8'd8) begin
                                output_char <= string_data[char_index];
                                output_valid <= 1'b1;
                                char_index <= char_index + 8'd1;
                            end else begin
                                output_valid <= 1'b0;
                                char_index <= 8'd0;
                                pc <= pc + 4'd1;
                                state <= FETCH;
                            end
                        end

                        // PRINTLN operation
                        8'd3: begin
                            if (char_index < 8'd8) begin
                                output_char <= string_data[char_index];
                                output_valid <= 1'b1;
                                char_index <= char_index + 8'd1;
                            end else if (char_index == 8'd8) begin
                                output_char <= 8'h0A;  // Newline
                                output_valid <= 1'b1;
                                char_index <= char_index + 8'd1;
                            end else begin
                                output_valid <= 1'b0;
                                char_index <= 8'd0;
                                pc <= pc + 4'd1;
                                state <= FETCH;
                            end
                        end

                        // HALT operation (implicit)
                        default: begin
                            state <= COMPLETE;
                        end
                    endcase
                end

                COMPLETE: begin
                    done <= 1'b1;
                    output_valid <= 1'b0;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    output_valid <= 1'b0;
                end
            endcase

            // Cycle counter update
            if (state != IDLE && state != COMPLETE) begin
                cycle_count <= cycle_count + 9'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    state <= COMPLETE;
                    done <= 1'b1;
                end
            end
        end
    end

endmodule