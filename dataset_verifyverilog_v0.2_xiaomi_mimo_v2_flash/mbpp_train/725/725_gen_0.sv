module quotation_extractor (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [5:0] char_index,
    output reg [7:0] extracted [0:7],
    output reg [3:0] extracted_count,
    output reg done,
    output reg error
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam SCANNING = 2'b01;
    localparam CAPTURING = 2'b10;
    localparam DONE = 2'b11;

    // Internal registers
    reg [1:0] current_state, next_state;
    reg in_quotes;
    reg [3:0] substr_idx; // Index of current substring being captured (0-7)
    reg [3:0] char_pos;   // Position in current substring buffer (0-15)
    reg [7:0] buffer [0:15]; // Temporary buffer for current substring
    reg error_flag;
    reg [5:0] proc_index; // Tracks the character index currently being processed

    // Temporary variables for next state logic
    reg [1:0] next_state_val;
    reg next_in_quotes;
    reg [3:0] next_substr_idx;
    reg [3:0] next_char_pos;
    reg next_error_flag;
    reg [5:0] next_proc_index;
    reg [7:0] temp_buffer [0:15];
    reg [7:0] temp_extracted [0:7];
    reg [3:0] temp_extracted_count;
    reg temp_done;

    integer i, j;

    // State transition and output logic
    always @(*) begin
        // Default assignments to prevent latches
        next_state_val = current_state;
        next_in_quotes = in_quotes;
        next_substr_idx = substr_idx;
        next_char_pos = char_pos;
        next_error_flag = error_flag;
        next_proc_index = proc_index;
        
        for (i = 0; i < 16; i = i + 1) temp_buffer[i] = buffer[i];
        for (i = 0; i < 8; i = i + 1) temp_extracted[i] = extracted[i];
        temp_extracted_count = extracted_count;
        temp_done = done;

        case (current_state)
            IDLE: begin
                temp_done = 1'b0;
                if (start) begin
                    next_state_val = SCANNING;
                    next_in_quotes = 1'b0;
                    next_substr_idx = 4'd0;
                    next_char_pos = 4'd0;
                    next_error_flag = 1'b0;
                    next_proc_index = 6'd0;
                    // Clear buffer
                    for (i = 0; i < 16; i = i + 1) temp_buffer[i] = 8'd0;
                    // Clear extracted array
                    for (i = 0; i < 8; i = i + 1) temp_extracted[i] = 128'd0;
                    temp_extracted_count = 4'd0;
                end
            end

            SCANNING: begin
                if (char_index == 63 && proc_index == 63) begin
                    // Last character processed
                    if (in_quotes) begin
                        next_error_flag = 1'b1; // Unmatched quote
                    end
                    next_state_val = DONE;
                end else if (proc_index < 64) begin
                    // Process current character if it matches the expected index
                    if (char_index == proc_index) begin
                        if (char_in == 8'd34) begin // "
                            if (!in_quotes) begin
                                // Start capturing
                                next_in_quotes = 1'b1;
                                next_char_pos = 4'd0;
                                next_state_val = CAPTURING;
                            end else begin
                                // This case shouldn't happen if strictly following SCANNING logic (quotes handled in CAPTURING),
                                // but strictly speaking SCANNING is outside quotes. 
                                // If we somehow receive a quote in SCANNING while in_quotes is true, it means we missed a transition.
                                // Assuming correct transitions, we will see the quote in CAPTURING state first.
                            end
                            next_proc_index = proc_index + 1'b1;
                        end else begin
                            // Non-quote, stay in SCANNING, increment index
                            next_proc_index = proc_index + 1'b1;
                        end
                    end
                end
            end

            CAPTURING: begin
                if (char_index == proc_index) begin
                    if (char_in == 8'd34) begin // "
                        // End capturing
                        next_in_quotes = 1'b0;
                        next_state_val = SCANNING;
                        
                        if (substr_idx < 8) begin
                            // Store captured buffer into extracted array
                            // Copy buffer to extracted[substr_idx]
                            {temp_extracted[substr_idx][127:120], temp_extracted[substr_idx][119:112],
                             temp_extracted[substr_idx][111:104], temp_extracted[substr_idx][103:96],
                             temp_extracted[substr_idx][95:88], temp_extracted[substr_idx][87:80],
                             temp_extracted[substr_idx][79:72], temp_extracted[substr_idx][71:64],
                             temp_extracted[substr_idx][63:56], temp_extracted[substr_idx][55:48],
                             temp_extracted[substr_idx][47:40], temp_extracted[substr_idx][39:32],
                             temp_extracted[substr_idx][31:24], temp_extracted[substr_idx][23:16],
                             temp_extracted[substr_idx][15:8], temp_extracted[substr_idx][7:0]} = 
                            {buffer[15], buffer[14], buffer[13], buffer[12], buffer[11], buffer[10], buffer[9], buffer[8],
                             buffer[7], buffer[6], buffer[5], buffer[4], buffer[3], buffer[2], buffer[1], buffer[0]};
                            
                            temp_extracted_count = substr_idx + 1'b1;
                            if (substr_idx == 7) begin
                                // Max substrings reached, but we allow finishing current one? 
                                // Req says error if >8. This is the 8th one (index 7), so it's valid.
                                // If we found another one later, we'd set error.
                            end
                        end else begin
                            next_error_flag = 1'b1; // Too many substrings
                        end
                    end else begin
                        // Capture character
                        if (char_pos < 16) begin
                            temp_buffer[char_pos] = char_in;
                            next_char_pos = char_pos + 1'b1;
                        end else begin
                            // Exceeded max length
                            next_error_flag = 1'b1;
                        end
                    end
                    next_proc_index = proc_index + 1'b1;
                end
            end

            DONE: begin
                temp_done = 1'b1;
                if (!rst_n) begin
                    next_state_val = IDLE;
                end
            end
            
            default: next_state_val = IDLE;
        endcase

        // Global reset override
        if (!rst_n) begin
            next_state_val = IDLE;
            next_in_quotes = 1'b0;
            next_substr_idx = 4'd0;
            next_char_pos = 4'd0;
            next_error_flag = 1'b0;
            next_proc_index = 6'd0;
            temp_done = 1'b0;
            // Reset extracted outputs
            for (i = 0; i < 8; i = i + 1) temp_extracted[i] = 128'd0;
            temp_extracted_count = 4'd0;
        end
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            in_quotes <= 1'b0;
            substr_idx <= 4'd0;
            char_pos <= 4'd0;
            error_flag <= 1'b0;
            proc_index <= 6'd0;
            done <= 1'b0;
            extracted_count <= 4'd0;
            for (i = 0; i < 16; i = i + 1) buffer[i] <= 8'd0;
            for (i = 0; i < 8; i = i + 1) extracted[i] <= 128'd0;
        end else begin
            // Update registers from next state logic variables
            current_state <= next_state_val;
            in_quotes <= next_in_quotes;
            
            // Logic to update internal state and outputs
            // We need to track when a substring is finished to increment index
            // In the combinational block above, we used temp variables.
            // We need to detect transitions to update specific registers.
            
            // Handling specific updates based on transition
            // Since we can't directly pass 'temp' variables back to state logic easily without loops,
            // we update based on the conditions identified in the next state logic.
            
            // Re-evaluating the logic for correct sequential update:
            // The 'temp' variables in the always @(*) block were intended to be used.
            // Here we assign the registered values from those temps.
            
            buffer <= temp_buffer;
            extracted <= temp_extracted;
            extracted_count <= temp_extracted_count;
            done <= temp_done;
            
            // Internal state updates
            // We must handle the capturing index increment specifically when a quote closes
            // This happens when we transition from CAPTURING to SCANNING
            
            if (current_state == CAPTURING && next_state_val == SCANNING) begin
                if (char_in == 8'd34 && substr_idx < 8) begin
                    substr_idx <= substr_idx + 1'b1;
                end
            end
            
            if (current_state == IDLE && start) begin
                substr_idx <= 4'd0;
                char_pos <= 4'd0;
            end else if (current_state == CAPTURING) begin
                if (char_index == proc_index) begin
                    if (char_in != 8'd34) begin
                        if (char_pos < 16) begin
                            char_pos <= char_pos + 1'b1;
                        end
                    end
                end
            end

            if (current_state == IDLE && start) begin
                proc_index <= 6'd0;
                error_flag <= 1'b0;
            end else if ((current_state == SCANNING || current_state == CAPTURING) && char_index == proc_index) begin
                proc_index <= proc_index + 1'b1;
            end
            
            // Error updates
            if (current_state == IDLE && start) begin
                error_flag <= 1'b0;
            end else begin
                if (next_error_flag) begin
                    error_flag <= 1'b1;
                end
                // Check for unmatched quote at the very end of processing in SCANNING state
                if (current_state == SCANNING && char_index == 63 && proc_index == 63 && in_quotes) begin
                     error_flag <= 1'b1;
                end
                // Check for substring length exceeded in CAPTURING state
                if (current_state == CAPTURING && char_index == proc_index && char_in != 8'd34 && char_pos >= 16) begin
                    error_flag <= 1'b1;
                end
                // Check for too many substrings (index 8 reached)
                if (current_state == CAPTURING && next_state_val == SCANNING && substr_idx >= 8) begin
                    error_flag <= 1'b1;
                end
            end
        end
    end

    // Assign final output error
    // error output is high if error_flag is high OR if we are in a terminal error state
    assign error = error_flag;

endmodule
