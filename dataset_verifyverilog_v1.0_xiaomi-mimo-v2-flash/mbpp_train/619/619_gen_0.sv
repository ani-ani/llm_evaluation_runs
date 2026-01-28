module move_digits_to_end (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] input_string [0:15],
    input wire [3:0] valid_length,
    output reg [7:0] output_string [0:15],
    output reg done,
    output reg valid
);

    // State definitions
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] FIRST_PASS   = 3'd1;
    localparam [2:0] SECOND_PASS  = 3'd2;
    localparam [2:0] PADDING      = 3'd3;
    localparam [2:0] FINISH       = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] idx;              // Input string index (0-15)
    reg [3:0] non_digit_ptr;    // Position for next non-digit in output
    reg [3:0] digit_ptr;        // Position for next digit in output
    reg [3:0] i;                // Loop counter for padding
    reg found_digit;            // Flag to check if current char is digit
    reg [7:0] current_char;     // Current character being processed
    reg first_pass_done;        // Flag for first pass completion

    // Check if current character is a digit (ASCII '0'-'9')
    always @(*) begin
        if (current_char >= 8'h30 && current_char <= 8'h39) begin
            found_digit = 1'b1;
        end else begin
            found_digit = 1'b0;
        end
    end

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = FIRST_PASS;
                end else begin
                    next_state = IDLE;
                end
            end
            
            FIRST_PASS: begin
                if (idx >= valid_length) begin
                    next_state = SECOND_PASS;
                end else begin
                    next_state = FIRST_PASS;
                end
            end
            
            SECOND_PASS: begin
                if (idx >= valid_length) begin
                    if (digit_ptr < 4'd16) begin
                        next_state = PADDING;
                    end else begin
                        next_state = FINISH;
                    end
                end else begin
                    next_state = SECOND_PASS;
                end
            end
            
            PADDING: begin
                if (i >= 4'd16) begin
                    next_state = FINISH;
                end else begin
                    next_state = PADDING;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Main FSM logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            idx <= 4'd0;
            non_digit_ptr <= 4'd0;
            digit_ptr <= 4'd0;
            i <= 4'd0;
            found_digit <= 1'b0;
            first_pass_done <= 1'b0;
            current_char <= 8'd0;
            // Initialize output_string to spaces
            for (int j = 0; j < 16; j = j + 1) begin
                output_string[j] <= 8'h20;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    idx <= 4'd0;
                    non_digit_ptr <= 4'd0;
                    digit_ptr <= 4'd0;
                    i <= 4'd0;
                    first_pass_done <= 1'b0;
                    // Reset output string to spaces
                    for (int j = 0; j < 16; j = j + 1) begin
                        output_string[j] <= 8'h20;
                    end
                end
                
                FIRST_PASS: begin
                    // Process characters one by one
                    if (idx < valid_length) begin
                        current_char <= input_string[idx];
                        
                        if (input_string[idx] >= 8'h30 && input_string[idx] <= 8'h39) begin
                            // It's a digit - will be processed in second pass
                            // Just increment idx
                        end else begin
                            // Not a digit - write directly to output
                            if (non_digit_ptr < 4'd16) begin
                                output_string[non_digit_ptr] <= input_string[idx];
                                non_digit_ptr <= non_digit_ptr + 4'd1;
                            end
                        end
                        
                        idx <= idx + 4'd1;
                    end
                end
                
                SECOND_PASS: begin
                    // Process characters again for digits
                    if (idx < valid_length) begin
                        if (input_string[idx] >= 8'h30 && input_string[idx] <= 8'h39) begin
                            // It's a digit - write to output
                            if (digit_ptr < 4'd16) begin
                                output_string[digit_ptr] <= input_string[idx];
                                digit_ptr <= digit_ptr + 4'd1;
                            end
                        end
                        
                        idx <= idx + 4'd1;
                    end
                end
                
                PADDING: begin
                    // Fill remaining positions with spaces
                    if (i < 4'd16) begin
                        if (output_string[i] == 8'h00) begin
                            output_string[i] <= 8'h20;
                        end
                        i <= i + 4'd1;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    valid <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule