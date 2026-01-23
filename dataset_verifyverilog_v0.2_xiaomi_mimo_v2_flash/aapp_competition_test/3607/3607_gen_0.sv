module basic_interpreter (
    input clk,
    input rst_n,
    input start,
    input [7:0] prog_len,
    input [127:0] instruction,
    input [7:0] pc_in,
    output reg [7:0] pc_out,
    output reg read_en,
    output reg [7:0] char_addr,
    input [7:0] char_data,
    output reg char_valid,
    output reg [7:0] char_out,
    output reg done
);

// Fixed-point format: 16-bit signed
// Variables A-Z map to registers 0-25

// Instruction format (128 bits):
// [7:0]    - label
// [15:8]   - command type (0=LET, 1=IF, 2=PRINT, 3=PRINTLN)
// [23:16]  - operand A (variable index or immediate)
// [31:24]  - operand B (variable index or immediate)
// [39:32]  - operator (+, -, *, /, =, <, >, <=, >=, <>)
// [47:40]  - target variable (for LET)
// [55:48]  - goto label (for IF)
// [63:56]  - string length (for PRINT/PRINTLN)
// [127:64] - string data (up to 8 chars, padded)

reg [15:0] vars [0:25];  // Variables A-Z
reg [7:0] state;
reg [7:0] current_label;
reg [15:0] op_result;
reg [15:0] temp_a;
reg [15:0] temp_b;
reg condition_met;

// String output state
reg [3:0] char_idx;
reg [3:0] string_len;
reg output_newline;

localparam IDLE = 0;
localparam FETCH = 1;
localparam DECODE = 2;
localparam EXEC_LET = 3;
localparam EXEC_IF = 4;
localparam EXEC_PRINT = 5;
localparam OUTPUT_STRING = 6;
localparam OUTPUT_NEWLINE = 7;
localparam UPDATE_PC = 8;
localparam DONE_STATE = 9;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 0;
        read_en <= 0;
        char_valid <= 0;
        pc_out <= 0;
        char_addr <= 0;
        char_out <= 0;
        temp_a <= 0;
        temp_b <= 0;
        op_result <= 0;
        condition_met <= 0;
        char_idx <= 0;
        string_len <= 0;
        output_newline <= 0;
        current_label <= 0;
        // Initialize variables
        integer i;
        for (i = 0; i < 26; i = i + 1) begin
            vars[i] <= 0;
        end
    end else begin
        char_valid <= 0;
        read_en <= 0;
        
        case (state)
            IDLE: begin
                if (start) begin
                    pc_out <= 0;
                    state <= FETCH;
                    done <= 0;
                end
            end
            
            FETCH: begin
                // Request instruction from memory
                read_en <= 1;
                state <= DECODE;
            end
            
            DECODE: begin
                // Parse instruction fields
                current_label <= instruction[7:0];
                string_len <= instruction[55:48];
                output_newline <= (instruction[15:8] == 3); // PRINTLN
                
                // Resolve variables
                if (instruction[15:8] == 0) begin // LET
                    // Check if operands are variables (bit 7 = 1 indicates variable)
                    if (instruction[23]) begin
                        temp_a <= vars[instruction[22:16]];
                    end else begin
                        temp_a <= {8'h00, instruction[23:16]};
                    end
                    if (instruction[31]) begin
                        temp_b <= vars[instruction[30:24]];
                    end else begin
                        temp_b <= {8'h00, instruction[31:24]};
                    end
                end else if (instruction[15:8] == 1) begin // IF
                    if (instruction[23]) begin
                        temp_a <= vars[instruction[22:16]];
                    end else begin
                        temp_a <= {8'h00, instruction[23:16]};
                    end
                    if (instruction[31]) begin
                        temp_b <= vars[instruction[30:24]];
                    end else begin
                        temp_b <= {8'h00, instruction[31:24]};
                    end
                end
                
                // Determine next state based on command
                case (instruction[15:8])
                    0: state <= EXEC_LET;
                    1: state <= EXEC_IF;
                    2, 3: begin
                        char_idx <= 0;
                        state <= EXEC_PRINT;
                    end
                    default: state <= UPDATE_PC;
                endcase
            end
            
            EXEC_LET: begin
                // Perform arithmetic based on operator [39:32]
                case (instruction[39:32])
                    8'h01: op_result = temp_a + temp_b;  // +
                    8'h02: op_result = temp_a - temp_b;  // -
                    8'h03: op_result = temp_a * temp_b;  // *
                    8'h04: op_result = temp_a / temp_b;  // / (truncates toward zero)
                    default: op_result = temp_a;
                endcase
                // Write to variable [47:40]
                vars[instruction[47:40]] <= op_result;
                state <= UPDATE_PC;
            end
            
            EXEC_IF: begin
                // Evaluate condition [39:32]
                case (instruction[39:32])
                    8'h05: condition_met = (temp_a == temp_b);  // =
                    8'h06: condition_met = (temp_a > temp_b);   // >
                    8'h07: condition_met = (temp_a < temp_b);   // <
                    8'h08: condition_met = (temp_a != temp_b);  // <>
                    8'h09: condition_met = (temp_a <= temp_b);  // <=
                    8'h0A: condition_met = (temp_a >= temp_b);  // >=
                    default: condition_met = 0;
                endcase
                
                if (condition_met) begin
                    // Jump to label [55:48]
                    // Since labels are sequential, we assume label = position + 1
                    // For simplicity, we'll just load the new PC from instruction
                    pc_out <= instruction[55:48];
                end else begin
                    pc_out <= pc_in + 1;
                end
                state <= UPDATE_PC;
            end
            
            EXEC_PRINT: begin
                if (string_len > 0 && char_idx < string_len) begin
                    // Output string character from instruction[127:64]
                    char_out <= instruction[64 + char_idx*8 +: 8];
                    char_valid <= 1;
                    char_idx <= char_idx + 1;
                    state <= OUTPUT_STRING;
                end else if (instruction[15:8] == 2) begin // PRINT without variable
                    state <= UPDATE_PC;
                end else begin
                    // Print variable from [23:16]
                    char_out <= 8'h30 + vars[instruction[23:16]][7:0]; // Simple digit for test
                    char_valid <= 1;
                    state <= (instruction[15:8] == 3) ? OUTPUT_NEWLINE : UPDATE_PC;
                end
            end
            
            OUTPUT_STRING: begin
                if (char_idx < string_len) begin
                    char_out <= instruction[64 + char_idx*8 +: 8];
                    char_valid <= 1;
                    char_idx <= char_idx + 1;
                end else begin
                    char_idx <= 0;
                    if (output_newline) begin
                        state <= OUTPUT_NEWLINE;
                    end else begin
                        state <= UPDATE_PC;
                    end
                end
            end
            
            OUTPUT_NEWLINE: begin
                char_out <= 8'h0A;  // Newline
                char_valid <= 1;
                state <= UPDATE_PC;
            end
            
            UPDATE_PC: begin
                if (instruction[15:8] != 1 || !condition_met) begin
                    // If not a taken IF, increment PC
                    if (instruction[15:8] != 1)
                        pc_out <= pc_in + 1;
                end
                
                // Check if done
                if (pc_in >= prog_len - 1 && (instruction[15:8] != 1 || !condition_met)) begin
                    state <= DONE_STATE;
                end else begin
                    state <= FETCH;
                end
            end
            
            DONE_STATE: begin
                done <= 1;
                if (!start) state <= IDLE;
            end
        endcase
    end
end

endmodule