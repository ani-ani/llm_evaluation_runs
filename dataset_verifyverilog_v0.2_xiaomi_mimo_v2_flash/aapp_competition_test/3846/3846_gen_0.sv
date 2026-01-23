module leader_determiner (
    input clk,
    input rst_n,
    input start,
    input [3:0] msg_id,
    input msg_type,
    input msg_valid,
    output reg [7:0] possible_leaders,
    output reg done
);

    // Parameters
    parameter N = 8;
    parameter M = 16;

    // State Encoding
    localparam IDLE = 3'b001;
    localparam LOAD_MSG = 3'b010;
    localparam PROCESS_MSG = 3'b100;
    localparam DONE_STATE = 3'b000; // Using one-hot or binary, define explicitly
    // Let's use binary for efficiency/clarity unless specified one-hot
    localparam S_IDLE = 3'b000;
    localparam S_LOAD = 3'b001;
    localparam S_PROCESS = 3'b010;
    localparam S_UPDATE = 3'b011;
    localparam S_DONE = 3'b100;

    // Registers
    reg [2:0] current_state, next_state;
    reg [7:0] active_mask;         // Current active participants
    reg [7:0] potential_leaders;   // Candidates for leader
    reg [3:0] msg_cnt;             // Message counter
    reg [7:0] prev_active_mask;    // Store active mask from previous cycle for gap detection logic
    reg [7:0] gaps_detected;       // Tracks who has had a gap
    
    // Wires
    wire [7:0] msg_id_bit;
    
    // Map msg_id (1-based) to bit (0-based)
    // msg_id 1 -> bit 0, msg_id 2 -> bit 1, etc.
    assign msg_id_bit = (msg_id >= 1 && msg_id <= N) ? (1 << (msg_id - 1)) : 8'b0;

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            current_state <= S_IDLE;
        else
            current_state <= next_state;
    end

    // Next State Logic
    always @(*) begin
        case (current_state)
            S_IDLE: begin
                if (start)
                    next_state = S_LOAD;
                else
                    next_state = S_IDLE;
            end
            S_LOAD: begin
                // Wait for valid message or completion
                if (msg_valid) 
                    next_state = S_PROCESS;
                else if (msg_cnt == M) // Finished processing M messages
                    next_state = S_DONE;
                else
                    next_state = S_LOAD;
            end
            S_PROCESS: begin
                next_state = S_UPDATE;
            end
            S_UPDATE: begin
                // Move back to LOAD to get next message or check count
                next_state = S_LOAD;
            end
            S_DONE: begin
                next_state = S_DONE; // Stay done until reset
            end
            default: next_state = S_IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active_mask <= 8'b0;
            potential_leaders <= 8'hFF; // All possible initially (up to N bits)
            msg_cnt <= 4'b0;
            done <= 1'b0;
            possible_leaders <= 8'b0;
            gaps_detected <= 8'b0;
            prev_active_mask <= 8'b0;
        end else begin
            case (current_state)
                S_IDLE: begin
                    if (start) begin
                        active_mask <= 8'b0;
                        potential_leaders <= 8'hFF;
                        gaps_detected <= 8'b0;
                        msg_cnt <= 4'b0;
                        done <= 1'b0;
                        prev_active_mask <= 8'b0;
                    end
                end

                S_LOAD: begin
                    // Wait for valid message. If msg_cnt reaches M, transition to DONE happens in next_state logic
                    // but we can latch done here if needed. 
                    // Logic handles transition to S_PROCESS on msg_valid.
                    // If msg_valid is low, we stay here.
                    // If we are waiting for msg_valid and msg_cnt has already reached M (edge case), 
                    // next_state logic handles transition to DONE.
                    
                    // Latch prev_active for gap detection in next cycle
                    prev_active_mask <= active_mask;
                end

                S_PROCESS: begin
                    // Perform gap detection and update active mask based on loaded message
                    // Logic derived from requirements:
                    // 1. Gap: Participant X is logged off (msg_type=0) while 'active' is non-zero.
                    // Note: 'active' refers to the state BEFORE the log off event.
                    // However, we need to process sequentially. 
                    // The prompt says: "Track active participants". "A gap occurs if participant X is logged off while 'active' is non-zero."
                    // This implies: If msg_type is 0 (log off) for ID X, check if (active_mask BEFORE update) has any bits set 
                    // EXCEPT possibly X itself (if they were active). 
                    // Wait, if X logs off, they might have been part of 'active'.
                    // "Leader must be present whenever anyone is present." -> If X logs off and NO ONE else is present, that's fine.
                    // If X logs off and SOMEONE else is present (or was present just before?), then X has a gap.
                    // Actually, the text: "gap occurs if participant X is logged off while 'active' is non-zero."
                    // Usually implies: X goes low, but the system state (active others) was high.
                    // Let's look at "Track 'gaps' for each participant: a gap occurs if participant X is logged off while 'active' is non-zero."
                    // Let's assume we check the PREVIOUS active mask (prev_active_mask) which reflects state before this message.
                    // If msg_type is 0 (log off) for ID X:
                    //   If (prev_active_mask & ~msg_id_bit) != 0 (others were active)
                    //   OR maybe just (prev_active_mask != 0) is the condition?
                    // Let's stick to: If X logs off, and the system was non-empty (others were there), X is invalid.
                    // If X logs off and X was the ONLY one, that's fine.
                    // So: Gap condition for X = (msg_type == 0) && ((prev_active_mask & ~msg_id_bit) != 0)
                    // 
                    // Updates:
                    // Log on (+1): set bit in active_mask
                    // Log off (-1): clear bit in active_mask
                    
                    if (msg_valid && msg_cnt < M) begin
                        // Update Active Mask
                        if (msg_type) begin
                            // Log On
                            active_mask <= active_mask | msg_id_bit;
                        end else begin
                            // Log Off
                            active_mask <= active_mask & ~msg_id_bit;
                        end

                        // Gap Detection Logic
                        if (!msg_type) begin
                            // If logging off
                            // Check if there were other active participants BEFORE this log off
                            // prev_active_mask contains state before this message
                            if ((prev_active_mask & ~msg_id_bit) != 0) begin
                                gaps_detected <= gaps_detected | msg_id_bit;
                            end
                        end
                    end
                end

                S_UPDATE: begin
                    // Filter potential_leaders based on gaps_detected
                    // If a participant has a gap, they are removed from potential_leaders
                    potential_leaders <= potential_leaders & ~gaps_detected;
                    
                    // Increment message counter
                    if (msg_valid && msg_cnt < M) begin
                        msg_cnt <= msg_cnt + 1;
                    end
                end

                S_DONE: begin
                    done <= 1'b1;
                    // Mask output to only valid participants (1 to N)
                    possible_leaders <= potential_leaders & ((1 << N) - 1);
                end
            endcase
        end
    end

endmodule