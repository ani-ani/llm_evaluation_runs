module capital_words_spaces (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire [3:0] len,
    output reg [7:0] char_out,
    output reg valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] READ_INPUT    = 3'd1;
    localparam [2:0] SCAN          = 3'd2;
    localparam [2:0] INSERT_SPACE  = 3'd3;
    localparam [2:0] OUTPUT_CHAR   = 3'd4;
    localparam [2:0] DONE_STATE    = 3'd5;

    // FSM registers
    reg [2:0] state, next_state;
    
    // Buffer and control registers
    reg [7:0] input_buffer [0:15];     // 16x8-bit input buffer
    reg [7:0] output_buffer [0:31];    // 32x8-bit output buffer
    reg [4:0] input_idx;               // Index for reading input (0-15)
    reg [4:0] scan_idx;                // Index for scanning input buffer
    reg [5:0] output_idx;              // Index for writing to output buffer (0-31)
    reg [5:0] output_pos;              // Current position in output being sent
    reg [4:0] input_len_reg;           // Store length for processing
    reg [7:0] prev_char;               // Previous character for pattern detection
    
    // Loop counter for output phase
    reg [5:0] cycle_count;
    localparam [5:0] MAX_CYCLES = 6'd40;

    integer i;

    // State transition logic (async)
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = READ_INPUT;
                else
                    next_state = IDLE;
            end
            
            READ_INPUT: begin
                if (input_idx >= input_len_reg)
                    next_state = SCAN;
                else
                    next_state = READ_INPUT;
            end
            
            SCAN: begin
                if (scan_idx >= input_len_reg)
                    next_state = OUTPUT_CHAR;
                else if (input_buffer[scan_idx] >= 8'd65 && input_buffer[scan_idx] <= 8'd90) begin
                    // Current is uppercase, check if previous was lowercase
                    if (prev_char >= 8'd97 && prev_char <= 8'd122)
                        next_state = INSERT_SPACE;
                    else
                        next_state = SCAN;
                end else begin
                    next_state = SCAN;
                end
            end
            
            INSERT_SPACE: begin
                if (output_idx >= input_len_reg)
                    next_state = OUTPUT_CHAR;
                else
                    next_state = INSERT_SPACE;
            end
            
            OUTPUT_CHAR: begin
                if (output_pos >= output_idx)
                    next_state = DONE_STATE;
                else
                    next_state = OUTPUT_CHAR;
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            char_out <= 8'd0;
            valid <= 1'b0;
            done <= 1'b0;
            input_idx <= 5'd0;
            scan_idx <= 5'd0;
            output_idx <= 6'd0;
            output_pos <= 6'd0;
            input_len_reg <= 5'd0;
            prev_char <= 8'd0;
            cycle_count <= 6'd0;
            // Initialize input buffer
            for (i = 0; i < 16; i = i + 1) begin
                input_buffer[i] <= 8'd0;
            end
            // Initialize output buffer
            for (i = 0; i < 32; i = i + 1) begin
                output_buffer[i] <= 8'd0;
            end
        end else begin
            // Default values
            state <= next_state;
            done <= 1'b0;
            valid <= 1'b0;
            
            case (next_state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    input_idx <= 5'd0;
                    scan_idx <= 5'd0;
                    output_idx <= 6'd0;
                    output_pos <= 6'd0;
                    prev_char <= 8'd0;
                    cycle_count <= 6'd0;
                end
                
                READ_INPUT: begin
                    input_buffer[input_idx] <= char_in;
                    input_idx <= input_idx + 5'd1;
                    input_len_reg <= len;
                end
                
                SCAN: begin
                    if (input_buffer[scan_idx] >= 8'd65 && input_buffer[scan_idx] <= 8'd90) begin
                        // Current is uppercase, check if previous was lowercase
                        if (prev_char >= 8'd97 && prev_char <= 8'd122) begin
                            // Need to insert space before this char
                            output_buffer[output_idx] <= 8'd32;  // Space
                            output_idx <= output_idx + 6'd1;
                            output_buffer[output_idx + 6'd1] <= input_buffer[scan_idx];
                            output_idx <= output_idx + 6'd2;
                            prev_char <= input_buffer[scan_idx];
                        end else begin
                            // No space needed
                            output_buffer[output_idx] <= input_buffer[scan_idx];
                            output_idx <= output_idx + 6'd1;
                            prev_char <= input_buffer[scan_idx];
                        end
                    end else begin
                        // Not uppercase, just add
                        output_buffer[output_idx] <= input_buffer[scan_idx];
                        output_idx <= output_idx + 6'd1;
                        prev_char <= input_buffer[scan_idx];
                    end
                    scan_idx <= scan_idx + 5'd1;
                end
                
                INSERT_SPACE: begin
                    // This state handles final space insertion after scan completion
                    // Output char logic is handled in OUTPUT_CHAR
                    cycle_count <= cycle_count + 6'd1;
                end
                
                OUTPUT_CHAR: begin
                    char_out <= output_buffer[output_pos];
                    valid <= 1'b1;
                    output_pos <= output_pos + 6'd1;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    valid <= 1'b0;
                    char_out <= 8'd0;
                end
                
                default: begin
                    // Maintain defaults
                end
            endcase
        end
    end

endmodule