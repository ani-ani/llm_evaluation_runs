module remove_all_spaces (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input input_valid,
    input input_done,
    output reg [7:0] output_char,
    output reg output_valid,
    output reg done
);

    parameter BUFFER_SIZE = 16;

    // State encoding
    localparam IDLE     = 3'b001;
    localparam COLLECT  = 3'b010;
    localparam PROCESS  = 3'b100;
    // COMPLETE state handled by done signal, logically part of IDLE or transition
    // We will use a separate state for COMPLETE behavior or drive done signal externally
    // Let's use a separate state for clarity, or reuse IDLE with a done pulse.
    // The spec says "Return to idle state" after done.
    // Let's define states explicitly:
    // IDLE -> (start) -> COLLECT
    // COLLECT -> (input_done) -> PROCESS
    // PROCESS -> (scan complete) -> COMPLETE
    // COMPLETE -> (next cycle) -> IDLE
    localparam COMPLETE = 3'b000; // Encoded differently to save bits or just add it
    // Let's use 4 states properly.
    localparam S_IDLE    = 3'b000;
    localparam S_COLLECT = 3'b001;
    localparam S_PROCESS = 3'b010;
    localparam S_COMPLETE = 3'b011;

    reg [2:0] state, next_state;
    
    // Buffer storage
    reg [7:0] buffer [0:BUFFER_SIZE-1];
    
    // Pointers and counters
    reg [3:0] write_ptr; // 0 to 15
    reg [3:0] read_ptr;  // 0 to 15
    reg [3:0] scan_ptr;  // for scanning in PROCESS state
    reg [3:0] valid_count; // count of non-whitespace chars to emit
    
    // Helper for whitespace detection
    wire is_whitespace;
    assign is_whitespace = (char_in == 8'h20) || 
                           (char_in == 8'h09) || 
                           (char_in == 8'h0A) || 
                           (char_in == 8'h0D);
    // For process scanning, we need to check buffer content
    wire is_buffer_whitespace;
    assign is_buffer_whitespace = (buffer[scan_ptr] == 8'h20) || 
                                  (buffer[scan_ptr] == 8'h09) || 
                                  (buffer[scan_ptr] == 8'h0A) || 
                                  (buffer[scan_ptr] == 8'h0D);

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            S_IDLE: begin
                if (start)
                    next_state = S_COLLECT;
                else
                    next_state = S_IDLE;
            end
            S_COLLECT: begin
                if (input_done)
                    next_state = S_PROCESS;
                else
                    next_state = S_COLLECT;
            end
            S_PROCESS: begin
                // We need to wait until we have scanned all valid chars
                // But we need to emit valid_count times.
                // Wait, the logic is: Scan buffer, if non-ws, emit. 
                // We can't know valid_count until we scan it all, OR we emit on the fly.
                // Spec: "5. For each non-whitespace character, emit it..."
                // Spec: "6. After emitting all non-whitespace characters, set done high"
                // This implies we scan, and if non-ws, we output. 
                // To keep it sequential (1 char per cycle), we can scan and emit in the same pass.
                // But output_valid is a pulse. We need to hold state until output is consumed.
                // Actually, simplest is: Scan buffer. If non-ws, emit (output_valid=1). Next cycle, scan next.
                // We need to know when we are done.
                // Let's assume we iterate 0 to write_ptr (total inputs).
                // When scan_ptr > write_ptr (and we finished emitting last char), go to COMPLETE.
                // However, output_valid is high for one cycle. So we emit and move scan_ptr next cycle.
                // We need to track if we have finished scanning the buffer.
                // Let's modify PROCESS logic: We will stay in PROCESS as long as scan_ptr <= write_ptr.
                // If scan_ptr > write_ptr, we are done.
                // BUT we might have delayed output. 
                // Let's optimize: Read buffer[scan_ptr]. If non-ws, set output_valid. If ws, output_valid=0.
                // Then increment scan_ptr next cycle.
                // This introduces a 1-cycle delay for the last character if we check scan_ptr > write_ptr.
                // Better: Process state iterates scan_ptr. 
                // Check condition: (scan_ptr > write_ptr) means finished.
                // But we must emit the last valid char. 
                // If we check (scan_ptr > write_ptr) at start of cycle, we don't process that char.
                // Let's stay in PROCESS until scan_ptr == write_ptr + 1.
                // Then transition to COMPLETE.
                if (scan_ptr > write_ptr)
                    next_state = S_COMPLETE;
                else
                    next_state = S_PROCESS;
            end
            S_COMPLETE: begin
                // Just need one cycle to assert done high? 
                // Spec: "done goes high after all output is complete"
                // "Return to idle state"
                // Usually COMPLETE state lasts 1 cycle then goes back to IDLE.
                next_state = S_IDLE;
            end
            default: next_state = S_IDLE;
        endcase
    end

    // Output logic (Moore/Mealy mix)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            output_char <= 8'b0;
            output_valid <= 1'b0;
            done <= 1'b0;
            write_ptr <= 4'b0;
            scan_ptr <= 4'b0;
            read_ptr <= 4'b0; // Not strictly needed separate from scan_ptr
        end else begin
            // Defaults
            output_valid <= 1'b0;
            done <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        write_ptr <= 4'b0;
                        scan_ptr <= 4'b0;
                    end
                end

                S_COLLECT: begin
                    if (input_valid) begin
                        if (write_ptr < BUFFER_SIZE) begin
                            buffer[write_ptr] <= char_in;
                            write_ptr <= write_ptr + 1;
                        end
                    end
                end

                S_PROCESS: begin
                    // scan_ptr points to current character to check
                    // We must ensure we don't overflow scan_ptr logic
                    if (scan_ptr <= write_ptr) begin
                        // Check buffer[scan_ptr] (assuming scan_ptr < write_ptr+1)
                        // If scan_ptr == write_ptr, we are checking the last stored character (if 0-based index)
                        // write_ptr points to the next free slot. So max index is write_ptr - 1.
                        // But we allow scan_ptr to reach write_ptr.
                        // If scan_ptr == write_ptr, we are done.
                        // Wait, the check in Next State is `scan_ptr > write_ptr`.
                        // So inside the block, scan_ptr <= write_ptr.
                        
                        // We need to check the character at scan_ptr.
                        // Only if scan_ptr < write_ptr do we have a character to check.
                        if (scan_ptr < write_ptr) begin
                            if (!(buffer[scan_ptr] == 8'h20 || 
                                  buffer[scan_ptr] == 8'h09 || 
                                  buffer[scan_ptr] == 8'h0A || 
                                  buffer[scan_ptr] == 8'h0D)) begin
                                output_char <= buffer[scan_ptr];
                                output_valid <= 1'b1;
                            end
                            // Increment pointer for next cycle
                            scan_ptr <= scan_ptr + 1;
                        end else begin
                            // scan_ptr == write_ptr (empty string case or end of buffer)
                            // We still increment to exit state
                            scan_ptr <= scan_ptr + 1;
                        end
                    end
                end

                S_COMPLETE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule
