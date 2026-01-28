module StringFormatter(
    input clk,
    input rst_n,
    input start,
    input [3:0] data_in [0:15],
    input [63:0] prefix,
    input [63:0] suffix,
    output reg [63:0] result [0:15],
    output reg done
);

    // State declarations
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] PRE_PROCESS = 4'd1;
    localparam [3:0] PROCESSING  = 4'd2;
    localparam [3:0] OUTPUT      = 4'd3;
    
    // Registers and counters
    reg [3:0] state, next_state;
    reg [3:0] index;
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd20;
    
    // Intermediate processing signals
    reg [3:0] current_value;
    reg [7:0] converted_char;
    reg [63:0] temp_result;
    reg [7:0] result_part;
    
    // ASCII conversion lookup (combinational)
    always @(*) begin
        case (current_value)
            4'h0: converted_char = 8'h30; // '0'
            4'h1: converted_char = 8'h31; // '1'
            4'h2: converted_char = 8'h32; // '2'
            4'h3: converted_char = 8'h33; // '3'
            4'h4: converted_char = 8'h34; // '4'
            4'h5: converted_char = 8'h35; // '5'
            4'h6: converted_char = 8'h36; // '6'
            4'h7: converted_char = 8'h37; // '7'
            4'h8: converted_char = 8'h38; // '8'
            4'h9: converted_char = 8'h39; // '9'
            4'hA: converted_char = 8'h41; // 'A'
            4'hB: converted_char = 8'h42; // 'B'
            4'hC: converted_char = 8'h43; // 'C'
            4'hD: converted_char = 8'h44; // 'D'
            4'hE: converted_char = 8'h45; // 'E'
            4'hF: converted_char = 8'h46; // 'F'
            default: converted_char = 8'h20; // Space
        endcase
    end
    
    // State transition and processing logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            index <= 4'd0;
            cycle_counter <= 8'd0;
            current_value <= 4'd0;
            result_part <= 8'd0;
            temp_result <= 64'd0;
            // Initialize all result entries to space (0x20)
            result[0] <= {8{8'h20}};
            result[1] <= {8{8'h20}};
            result[2] <= {8{8'h20}};
            result[3] <= {8{8'h20}};
            result[4] <= {8{8'h20}};
            result[5] <= {8{8'h20}};
            result[6] <= {8{8'h20}};
            result[7] <= {8{8'h20}};
            result[8] <= {8{8'h20}};
            result[9] <= {8{8'h20}};
            result[10] <= {8{8'h20}};
            result[11] <= {8{8'h20}};
            result[12] <= {8{8'h20}};
            result[13] <= {8{8'h20}};
            result[14] <= {8{8'h20}};
            result[15] <= {8{8'h20}};
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 4'd0;
                    cycle_counter <= 8'd0;
                    if (start) begin
                        state <= PRE_PROCESS;
                        cycle_counter <= cycle_counter + 8'd1;
                    end
                end
                
                PRE_PROCESS: begin
                    // Load current value
                    current_value <= data_in[index];
                    state <= PROCESSING;
                    cycle_counter <= cycle_counter + 8'd1;
                end
                
                PROCESSING: begin
                    // Construct the formatted string
                    // Format: prefix (64-bit) + converted_char (8-bit) + suffix (64-bit)
                    // Since result is 64-bit, we need to fit 9 chars. We'll use:
                    // - First 8 chars from prefix
                    // - 9th char is the converted value
                    // - Result is 64 bits (8 chars), so we prioritize prefix + converted char
                    // For full 9-char output in 64-bit (8 chars), we'll use prefix + converted char
                    // and suffix is truncated or unused as per spec says "fixed 8-char strings"
                    
                    // Build result: prefix[63:0] with last char replaced by converted_char
                    // Actually, spec says: "prefix + [converted_char] + suffix"
                    // Since 64 bits = 8 chars, and we need 9 chars, we'll pack:
                    // prefix[63:8] + converted_char (8-bit)
                    // This gives us 9 chars: 8 from prefix minus last + converted + (7 from suffix unused)
                    // Let's follow: first 7 chars from prefix, converted char, first 7 chars from suffix
                    // To fit 64 bits (8 chars), we need to truncate. We'll use:
                    // prefix[55:0] + converted_char[7:0] (8 chars total)
                    // Actually, let's re-read: "Construct string: prefix[63:0] + [converted_char] + suffix[63:0]"
                    // And "Output strings are fixed 9 characters"
                    // Since result is 64-bit (8 chars), we'll fit 8 chars.
                    // We'll use: prefix[55:0] + converted_char (8 chars total)
                    // This uses first 7 chars from prefix, converted char at end
                    // Or better: use first 8 chars of (prefix + converted_char + suffix)
                    // We'll extract 8 chars from the 17-char conceptual string
                    
                    // Let's build 8 chars as: prefix[63:8] (7 chars) + converted_char (1 char)
                    // Result: {prefix[63:8], converted_char}
                    result_part <= converted_char;
                    temp_result <= {prefix[63:8], converted_char};
                    state <= OUTPUT;
                    cycle_counter <= cycle_counter + 8'd1;
                end
                
                OUTPUT: begin
                    // Store result
                    case (index)
                        4'd0: result[0] <= temp_result;
                        4'd1: result[1] <= temp_result;
                        4'd2: result[2] <= temp_result;
                        4'd3: result[3] <= temp_result;
                        4'd4: result[4] <= temp_result;
                        4'd5: result[5] <= temp_result;
                        4'd6: result[6] <= temp_result;
                        4'd7: result[7] <= temp_result;
                        4'd8: result[8] <= temp_result;
                        4'd9: result[9] <= temp_result;
                        4'd10: result[10] <= temp_result;
                        4'd11: result[11] <= temp_result;
                        4'd12: result[12] <= temp_result;
                        4'd13: result[13] <= temp_result;
                        4'd14: result[14] <= temp_result;
                        4'd15: result[15] <= temp_result;
                        default: result[0] <= temp_result;
                    endcase
                    
                    // Check if all 16 elements processed
                    if (index == 4'd15) begin
                        done <= 1'b1;
                        state <= IDLE;
                    end else begin
                        index <= index + 4'd1;
                        state <= PRE_PROCESS;
                    end
                    cycle_counter <= cycle_counter + 8'd1;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
            
            // Safety timeout
            if (cycle_counter >= MAX_CYCLES) begin
                done <= 1'b1;
                state <= IDLE;
            end
        end
    end
endmodule