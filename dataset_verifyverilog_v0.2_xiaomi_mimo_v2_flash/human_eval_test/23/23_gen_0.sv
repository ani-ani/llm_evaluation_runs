module strlen (
    input clk,
    input rst_n,
    input start,
    input [127:0] string_data,
    output reg [3:0] length,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam SCANNING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    reg [3:0] count, next_count;
    reg [3:0] i; // Index for current byte to check
    wire [7:0] current_byte;

    // Extract current byte based on count
    // count goes from 0 to 15. 
    // count=0 checks byte 0 at string_data[127:120]
    // count=1 checks byte 1 at string_data[119:112]
    // ...
    // count=15 checks byte 15 at string_data[7:0]
    assign current_byte = string_data[127 - (count * 8) -: 8];

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic & Output Logic (Moore machine style combined)
    always @(*) begin
        // Default assignments
        next_state = state;
        next_count = count;
        done = 1'b0;
        length = count;

        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    next_state = SCANNING;
                    next_count = 4'd0;
                end
            end

            SCANNING: begin
                // Check for null terminator or limit reached
                // We are processing the byte corresponding to current 'count' value
                // At this cycle, 'current_byte' is valid based on current 'count'
                
                if (current_byte == 8'h00 || count == 4'd15) begin
                    // Null found or max length reached
                    // The length of the string is count + 1 (if not null) or count (if null is current)
                    // Wait... If we found null at current 'count', is length count or count?
                    // Requirement: "Check if current byte is 0x00... If null found, transition to DONE state."
                    // If we find null at byte 0, length should be 0. 
                    // If we find null at byte 2, length should be 2.
                    // So length = count.
                    // What about limit? "After 16 bytes, force transition..."
                    // If count is 15, we processed 16 bytes (0..15). Length is 16. 
                    // So if count==15, length = 16. 
                    // Logic: If current_byte is null, length = count. 
                    //        Else (if count==15), length = count + 1.
                    
                    next_state = DONE;
                    if (current_byte == 8'h00)
                        length = count;
                    else
                        length = count + 1'b1;
                    next_count = count; // Keep value for DONE state
                end else begin
                    // Not null, increment count
                    next_count = count + 1'b1;
                end
            end

            DONE: begin
                done = 1'b1;
                length = count;
                // Stay in DONE until reset or restart (start signal handled in IDLE logic for next cycle)
                // But wait, if we are in DONE and start is asserted, what happens?
                // Requirement says: "Hold length result and wait for reset or next start."
                // Usually, "wait for next start" implies transitioning back to IDLE or SCANNING when start is high.
                // However, standard FSM design for "Result valid 17 cycles after start" usually implies:
                // Wait in DONE. If start is asserted again, we should probably go to IDLE or SCANNING.
                // To be safe and robust: 
                // If start is asserted, we reset the process (go to SCANNING with count=0).
                if (start) begin
                    next_state = SCANNING;
                    next_count = 4'd0;
                    done = 1'b0;
                end else begin
                    // If rst_n is high and start is low, stay in DONE
                    // next_state is already state (DONE)
                end
            end

            default: begin
                next_state = IDLE;
                next_count = 4'd0;
            end
        endcase
    end

endmodule