module IPv4LeadingZeroRemover (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] ip_in,
    input wire [3:0] len_in,
    output reg [63:0] ip_out,
    output reg [3:0] len_out,
    output reg done,
    output reg error
);

    // State Declarations
    localparam [2:0] IDLE           = 3'd0;
    localparam [2:0] CHECK_FORMAT   = 3'd1;
    localparam [2:0] PARSE_OCTET    = 3'd2;
    localparam [2:0] OUTPUT_CHAR    = 3'd3;
    localparam [2:0] FINISH         = 3'd4;
    localparam [2:0] ERROR_STATE    = 3'd5;

    // Internal Registers
    reg [2:0] state, next_state;
    reg [3:0] read_idx;           // Index for reading input (0-14)
    reg [3:0] write_idx;          // Index for writing output (0-14)
    reg [1:0] octet_count;        // Count dots found (0-3 octets processed)
    reg [2:0] digit_count;        // Digits in current octet (0-3)
    reg [2:0] cycle_count;        // Timeout counter (max 256 cycles)
    reg octet_started;            // Flag: non-zero digit seen in current octet
    reg [7:0] temp_char;          // Buffer for current character
    reg [63:0] internal_out;      // Accumulated output

    // Temporary calculation wires
    wire [7:0] current_char;
    wire is_digit;
    wire is_dot;
    wire is_leading_zero;
    wire valid_digit_range;

    // Extract current character from packed input
    // ip_in[63:56] is index 0, ip_in[55:48] is index 1, etc.
    assign current_char = (read_idx == 4'd0) ? ip_in[63:56] :
                          (read_idx == 4'd1) ? ip_in[55:48] :
                          (read_idx == 4'd2) ? ip_in[47:40] :
                          (read_idx == 4'd3) ? ip_in[39:32] :
                          (read_idx == 4'd4) ? ip_in[31:24] :
                          (read_idx == 4'd5) ? ip_in[23:16] :
                          (read_idx == 4'd6) ? ip_in[15:8]  :
                          (read_idx == 4'd7) ? ip_in[7:0]   : 8'd0;

    // Logic helpers
    assign is_digit = (current_char >= 8'h30) && (current_char <= 8'h39);
    assign is_dot   = (current_char == 8'h2E);
    assign is_leading_zero = (current_char == 8'h30) && (digit_count == 3'd0);

    // FSM State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state; // Default stay in current state
        case (state)
            IDLE: begin
                if (start)
                    next_state = CHECK_FORMAT;
            end

            CHECK_FORMAT: begin
                if (error)
                    next_state = ERROR_STATE;
                else if (read_idx >= len_in)
                    next_state = FINISH;
                else
                    next_state = PARSE_OCTET;
            end

            PARSE_OCTET: begin
                // If we hit a dot or end of input, go to output phase for this char
                if (is_dot || (read_idx >= len_in)) begin
                    next_state = OUTPUT_CHAR;
                end else if (!is_digit) begin
                    next_state = ERROR_STATE; // Invalid char inside octet
                end else begin
                    // Stay in PARSE_OCTET to consume digits
                    // Logic will handle incrementing read_idx
                end
            end

            OUTPUT_CHAR: begin
                // After outputting a char (digit or dot), check if we are done
                if (read_idx >= len_in)
                    next_state = FINISH;
                else if (is_dot)
                    next_state = PARSE_OCTET; // Start next octet
                else
                    next_state = PARSE_OCTET; // Continue digits
            end

            FINISH: begin
                next_state = IDLE;
            end

            ERROR_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Output and Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            ip_out <= 64'd0;
            len_out <= 4'd0;
            done <= 1'b0;
            error <= 1'b0;
            read_idx <= 4'd0;
            write_idx <= 4'd0;
            octet_count <= 2'd0;
            digit_count <= 3'd0;
            cycle_count <= 8'd0;
            octet_started <= 1'b0;
            temp_char <= 8'd0;
            internal_out <= 64'd0;
        end else begin
            case (state)
                IDLE: begin
                    // Clear outputs and counters
                    done <= 1'b0;
                    error <= 1'b0;
                    ip_out <= 64'd0;
                    len_out <= 4'd0;
                    read_idx <= 4'd0;
                    write_idx <= 4'd0;
                    octet_count <= 2'd0;
                    digit_count <= 3'd0;
                    cycle_count <= 8'd0;
                    octet_started <= 1'b0;
                    temp_char <= 8'd0;
                    internal_out <= 64'd0;
                end

                CHECK_FORMAT: begin
                    // Just validate basics or move to parse
                    // Input validation logic here (dot placement etc.)
                    // Simplified: process in PARSE_OCTET
                end

                PARSE_OCTET: begin
                    cycle_count <= cycle_count + 8'd1;
                    temp_char <= current_char;

                    // Check for timeout or invalid inputs
                    if (cycle_count >= 8'd250) begin
                        error <= 1'b1;
                    end else if (read_idx < len_in) begin
                        if (is_digit) begin
                            // Check octet length limit
                            if (digit_count >= 3'd3) begin
                                error <= 1'b1;
                            end
                            digit_count <= digit_count + 3'd1;

                            // Determine if we output this digit
                            // Rule: Output if not (leading zero and more digits follow)
                            // However, since we process sequentially, "more digits follow" is hard to know.
                            // Strategy: Skip leading zeros. If first char is '0' and next char is digit, skip.
                            // If first char is '0' and next is dot/end, we must output it.
                            // To handle this, we tentatively skip '0'. If we hit dot/end, we must retroactively output '0'.
                            // Simpler Strategy: Just output non-zero digits always. 
                            // For '0': Check `next_char` in a pipeline or delay.
                            // Let's use a "skip logic".
                            
                            // If current is '0' and (digit_count == 0):
                            // We don't know if it's the last digit yet. 
                            // We'll store it in a buffer or just delay output.
                            
                            // Implementation: If digit_count > 0 or char != '0', output.
                            // If char == '0' and digit_count == 0: check next char logic or handle in OUTPUT_CHAR.
                            // 
                            // Revised: Process in OUTPUT_CHAR state.
                            // We just increment read_idx here.
                            read_idx <= read_idx + 4'd1;
                        end else if (is_dot) begin
                            // Dot found inside octet (digit_count might be 0 if error)
                            // or consecutive dots. 
                            // Check validity: Must have had 1-3 digits.
                            if (digit_count == 3'd0) begin
                                error <= 1'b1;
                            end else begin
                                octet_count <= octet_count + 2'd1;
                                digit_count <= 3'd0;
                                octet_started <= 1'b0;
                                read_idx <= read_idx + 4'd1;
                            end
                        end else begin
                            error <= 1'b1;
                        end
                    end
                end

                OUTPUT_CHAR: begin
                    // Logic to write to internal_out based on `temp_char` and state
                    // We need to handle the "leading zero suppression" here.
                    // If we just read a '0' (and it was the first digit), 
                    // and the NEXT char is a digit (not dot/eos), we SKIP this '0'.
                    
                    // We need to know what the next char is. 
                    // Since `read_idx` was already incremented in PARSE_OCTET, 
                    // `temp_char` is the current char. `current_char` wire points to new read_idx.
                    
                    // Re-evaluate current char validity for output
                    reg should_output;
                    should_output = 1'b0;
                    
                    if (is_digit) begin
                        // Check if it's a leading zero that needs suppression
                        if ((temp_char == 8'h30) && (digit_count == 3'd1)) begin
                            // This was the first digit read (logic assumes digit_count was incremented)
                            // Check next char (the one at current read_idx)
                            // If next is digit, suppress. If next is dot/end, output.
                            if (read_idx < len_in) begin
                                if (current_char >= 8'h30 && current_char <= 8'h39) begin
                                    should_output = 1'b0; // Skip leading zero
                                end else begin
                                    should_output = 1'b1; // Single zero
                                end
                            end else begin
                                should_output = 1'b1; // Single zero at end
                            end
                        end else begin
                            should_output = 1'b1;
                        end
                    end else if (is_dot) begin
                        should_output = 1'b1;
                    end

                    if (should_output && (write_idx < 4'd15)) begin
                        // Shift and insert
                        internal_out <= {internal_out[55:0], temp_char};
                        write_idx <= write_idx + 4'd1;
                    end
                end

                FINISH: begin
                    // Check final validity
                    // Must have exactly 3 dots (4 octets)
                    if (octet_count != 2'd3) begin
                        error <= 1'b1;
                        done <= 1'b1;
                    end else if (error) begin
                        done <= 1'b1;
                    end else begin
                        ip_out <= internal_out;
                        len_out <= write_idx;
                        done <= 1'b1;
                    end
                end

                ERROR_STATE: begin
                    error <= 1'b1;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule