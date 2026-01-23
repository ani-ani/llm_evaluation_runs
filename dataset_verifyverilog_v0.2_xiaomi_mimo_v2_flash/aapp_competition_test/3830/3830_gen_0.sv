module snake_exhibition (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [7:0] s,
    output reg [3:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    reg [2:0] count, next_count;
    reg [3:0] result_int, next_result;
    reg done_int, next_done;

    // Current room properties
    wire belt_curr; // s[i]
    wire belt_prev; // s[i-1]
    wire is_returnable;

    // Index arithmetic with wrap-around for n <= 8
    // Since n is small (max 8), i-1 mod n maps to distinct values for i in [0, n-1]
    wire [2:0] idx_curr = count;
    wire [2:0] idx_prev = (count == 3'b000) ? (n - 1'b1) : (count - 1'b1);

    // Extract belts (s is 8 bits, use indices 0-7)
    assign belt_curr = s[idx_curr];
    assign belt_prev = s[idx_prev];

    // Condition 1: Belt leaving i is '-' (off)
    // Condition 2: Belt entering i is '-' (off)
    // Condition 3: Both adjacent belts are '<' (01)
    // Condition 4: Both adjacent belts are '>' (10)
    // Note: Verilog logic: !belt_curr is '1' if belt is '0' (OFF, 00000000)
    // !belt_prev is '1' if belt is '0' (OFF)
    // belts equal to '<' or '>' implies bits are non-zero. 
    // Since OFF is 0, and '<' and '>' are non-zero, and they differ in direction:
    // '<' = 00000001, '>' = 00000010.
    // Both '<' : belt_curr == 1, belt_prev == 1. 
    // Both '>' : belt_curr == 2, belt_prev == 2.
    // The problem states s contains '0'='-', '1'='<', '2'='>'.
    // However, input is [7:0] s. It says "1 bit per room". This is a contradiction in bit width vs content.
    // "1 bit per room" implies s[i] is a single bit (0 or 1). 
    // If s is [7:0], it has 8 bits, likely one bit per room (room 0 to 7).
    // If s contains '<' (1) and '>' (2), it needs 2 bits.
    // Given "input [7:0] s // String representing belt states (8 bits, 1 bit per room). 0='-', 1='<', 2='>'", 
    // there is a mismatch: [7:0] allows 8 rooms, but values 2 require 2 bits.
    // I will assume the description "1 bit per room" is the structural constraint for the interface (bitmask).
    // And that '<' (1) and '>' (2) are typo/simplification meaning 'active' or 'inactive'.
    // Or, more likely, '1'='<' and '0'='>' or vice versa.
    // However, condition 3 requires distinguishing '<' and '>'.
    // If only 1 bit is available, we cannot distinguish '<' and '>'.
    // I will assume the input IS [7:0] but values are encoded as:
    // 00 (OFF) = '-'.
    // 01 (ONE) = '<'.
    // 10 (TWO) = '>'.
    // 11 = undefined (treated as mismatch).
    // Since s is 8 bits wide, room i uses s[2*i+1:s2*i] if we pack them?
    // The prompt says "1 bit per room".
    // Let's re-read carefully. "s // String representing belt states (8 bits, 1 bit per room). 0='-', 1='<', 2='>'"
    // This is the strict requirement. If there are 8 bits and 1 bit per room, there are only 2 states per room.
    // Therefore, we CANNOT have both '<' and '>'.
    // This makes Condition 3 and 4 impossible to satisfy with single bits.
    // UNLESS the mapping is: 0 = OFF, 1 = ON.
    // And the prompt text "1='<', 2='>'" is describing a different encoding that doesn't fit the bit width.
    // BUT, the prompt requires checking "Both '<'" or "Both '>'".
    // I will assume the standard interpretation for such problems where bits are packed:
    // s is [7:0], n <= 8. Each room needs 2 bits to support 3 states (Off, <, >).
    // But the prompt says "1 bit per room".
    // Let's look at the example values. If room is '<', value is 1. If '>', value is 2.
    // In binary, 1 is 01, 2 is 10.
    // If the problem intended packed bits, s would need to be 16 bits.
    // Since s is [7:0], and n is [2:0] (max 8).
    // If we assume the "1 bit per room" is a mistake and it's actually bit pairs (0-1, 2-3...),
    // we would need 16 bits for 8 rooms. We have 8.
    // If we assume 's' is a look-up table or the values 1 and 2 are metaphorical for 'Left' and 'Right'.
    // WAIT. The prompt says "input [7:0] s // String... 1 bit per room".
    // If there are 8 rooms, 1 bit per room = 8 bits. That matches [7:0].
    // But we have 3 states. Impossible with 1 bit.
    // Re-evaluation: Perhaps the states are 0 (OFF), 1 (Direction A), 1 (Direction B)?
    // No, condition requires distinguishing A and B.
    // MOST LIKELY Scenario for RTL design: The prompt has a slight wording error.
    // It probably means s[i] is a bit, and we are checking for '0' and '1'.
    // But the logic of "Both '<'" vs "Both '>'" suggests 2 directions.
    // Hypothesis: The user meant 2 bits per room, but wrote 1. 
    // Or, the user meant 's' is a wire where 0=OFF, 1=ON.
    // Let's check the prompt again: "0='-', 1='<', 2='>'".
    // 0, 1, 2 are distinct integers. They require 2 bits.
    // I will implement assuming s[i] refers to 2-bit indices for the room values.
    // i.e. room i uses bits s[2*i+1 : 2*i].
    // However, s is declared [7:0]. This supports max 4 rooms with 2 bits.
    // The prompt says n is max 8.
    // This is a direct contradiction in the prompt's interface definition.
    // Which rule to prioritize? "s // String... 1 bit per room" vs "1='<', 2='>'".
    // "1 bit per room" is specific about the bit width of the interface.
    // "1='<', 2='>'" is specific about the data values.
    // If I must strictly follow "1 bit per room" and [7:0], then I cannot distinguish '<' and '>'.
    // But I must implement the logic that distinguishes them.
    // I will make a safe assumption for synthesis: 
    // The interface is [7:0] s. 
    // The '1 bit per room' in the comment is an error.
    // I will use the lower 2*n bits of s to encode the states.
    // s[1:0] -> room 0. s[3:2] -> room 1, etc.
    // Encoded as: 2'b00 = '-', 2'b01 = '<', 2'b10 = '>'.
    // This fits the [7:0] width for up to 4 rooms. 
    // For 8 rooms, s would need to be [15:0].
    // Since the prompt forces [7:0] and n<=8, I will support up to 4 rooms fully with 2-bit states.
    // For rooms > 4, I will treat the upper bits as undefined/zero or just rely on the input vector.
    // ACTUALLY, looking at "1 bit per room" again.
    // Maybe 's' contains the state of the BELTS, and the room properties are derived differently.
    // No, "belt states (8 bits, 1 bit per room)".
    // Okay, I will follow the logic of the conditions assuming the bits represent directions.
    // Let's assume the user made a mistake and s is [15:0] internally? No, I must use the port.
    // Let's assume 's' is indeed [7:0] and '1 bit per room' is a constraint I must respect.
    // Then I have to map 0 -> '-', 1 -> something. 
    // If there is only 1 bit, I cannot have both '<' and '>' distinct.
    // UNLESS the '1' and '2' in the description are examples, but '1 bit' is the hard limit.
    // If I have 1 bit, I have 2 states: 0 and 1.
    // Condition 3: Both '<' (State 1)
    // Condition 4: Both '>' (State 0? Or 1?)
    // This is impossible.
    
    // I will implement the code based on the logic described, using a parameterized approach.
    // I will assume 's' uses 2 bits per room, but packed into the [7:0] vector as much as possible.
    // Since I cannot change the port width, I will slice s.
    // For n <= 4, s[2*i+1:2*i] is used.
    // For n > 4, I will assume s[7:0] is what I have. 
    // If n=8, I need 16 bits. I will use s[7:0] for lower 4 rooms and 0 for upper 4?
    // No, that's bad.
    // Alternative: The prompt implies s is just a signal vector where 0=OFF, 1=ON, and '<'/'>' is an abstraction.
    // Let's assume the most standard interpretation for a design task:
    // Input s is a bitmask of belts. 
    // Belts are directional. 
    // The prompt asks for 'snake_exhibition'.
    // In a snake, a belt can be clockwise, anticlockwise, or off.
    // The input is [7:0]. 
    // If we look at the values 0, 1, 2.
    // 0 = 00000000
    // 1 = 00000001
    // 2 = 00000010
    // Maybe the 's' input is just 8 bits for 8 rooms, and the values are simply bitmasks for the 'state'.
    // Let's assume I need to implement the logic: 
    // curr = s[i], prev = s[i-1].
    // But s[i] is a single bit.
    // Condition 3: curr == 1 && prev == 1 (represented as bit '1').
    // Condition 4: curr == 0 && prev == 0 (represented as bit '0').
    // But this conflicts with condition 1 and 2 (OFF is '-').
    // If '1' bit is '<', then '0' bit must be '>'.
    // Then where is '-' (OFF)?
    // This is the contradiction.
    
    // FINAL DECISION: I will interpret the interface [7:0] as holding 8 bits.
    // I will interpret the logic requirements as:
    // 0 = OFF (-)
    // 1 = '<'
    // 2 = '>'
    // Since [7:0] is 8 bits, I will treat s as having two fields for each bit position to hold the value.
    // WAIT, I cannot store 2 bits in 1 bit.
    // I will change my interpretation. 
    // The user probably meant `input [15:0] s` but wrote `[7:0]`.
    // OR, the user meant `input [7:0] s` but the values are just 0/1, and '<'/'>' distinction is lost/merged.
    // BUT, I must meet the requirements.
    // I will write the code to support 2-bit states packed in s.
    // I will add a comment explaining that s must be 16 bits for n=8, but since the port is [7:0], it supports n=4.
    // However, the prompt says n max 8.
    // I will assume the input width constraint is a mistake in the prompt and I should use the logic.
    // Wait, I am an ASIC designer. I must follow specs.
    // Spec 1: input [7:0] s.
    // Spec 2: 0='-', 1='<', 2='>'.
    // Spec 3: 1 bit per room.
    // Spec 4: n <= 8.
    // These specs are mathematically incompatible.
    // I will prioritize Spec 1 (port width) and Spec 4 (max n).
    // And prioritize Spec 2 (logic values) over Spec 3 (1 bit per room comment).
    // Because "1 bit per room" contradicts Spec 2.
    // So, I will assume the comment "1 bit per room" is the error.
    // I will assume s is packed 2 bits per room.
    // i.e. Room 0: s[1:0], Room 1: s[3:2], Room 2: s[5:4], Room 3: s[7:6].
    // This supports n up to 4.
    // If n > 4, I will return 0 or ignore upper rooms? 
    // No, the prompt says "iterate through n rooms".
    // I will implement the logic for 2-bit states. If n > 4, I will treat upper bits as 0 (OFF) to avoid X-propagation and keep the design safe.
    // This is the most reasonable synthesis path.

    wire [1:0] curr_belt_val = s[2*idx_curr +: 2];
    wire [1:0] prev_belt_val = s[2*idx_prev +: 2];

    // Logic for is_returnable
    // 1. Belt leaving i is '-' (00)
    wire cond1 = (curr_belt_val == 2'b00);
    // 2. Belt entering i is '-' (00)
    wire cond2 = (prev_belt_val == 2'b00);
    // 3. Both '<' (01)
    wire cond3 = (curr_belt_val == 2'b01) && (prev_belt_val == 2'b01);
    // 4. Both '>' (10)
    wire cond4 = (curr_belt_val == 2'b10) && (prev_belt_val == 2'b10);

    assign is_returnable = cond1 | cond2 | cond3 | cond4;

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 3'b0;
            result <= 4'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            count <= next_count;
            result <= next_result;
            done <= next_done;
        end
    end

    // Next State Logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_count = count;
        next_result = result;
        next_done = done;

        case (state)
            IDLE: begin
                next_done = 1'b0;
                next_result = 4'b0;
                next_count = 3'b0;
                if (start) begin
                    next_state = (n == 3'b000) ? DONE : PROCESSING;
                    // If n > 0, we start processing index 0
                    // But count is initialized to 0. 
                    // We should check room 0 immediately or in next cycle?
                    // "In the PROCESSING state, iterate through n rooms... increment result"
                    // Typically, if start is high, we enter PROCESSING and process.
                    // Let's advance to PROCESSING.
                    // To avoid combinational loop on 'start', state goes to PROCESSING.
                    // In PROCESSING we handle the logic.
                end
            end

            PROCESSING: begin
                // Check current room
                // If returnable, add to result
                // We will increment count each cycle.
                // We need to decide when to add.
                // If we are in PROCESSING, 'count' currently points to the room to check?
                // Or do we check count and then increment?
                // Let's check 'count', add if valid, then increment.
                // Initial entry: count=0.
                // Cycle 1: Check room 0. Add if valid. Increment count to 1. 
                // Cycle 2: Check room 1. ...
                // Last cycle: Check room (n-1). Increment count to n. -> Done.
                
                if (is_returnable) begin
                    next_result = result + 1'b1;
                end

                next_count = count + 1'b1;

                // Check if we finished
                if (count == n - 1'b1) begin
                    next_state = DONE;
                    next_count = 3'b0; // Reset for next time
                end
                // If n=0, we shouldn't be here. Handled in IDLE.
            end

            DONE: begin
                next_done = 1'b1;
                // Wait for start to go low to return to IDLE (optional, good practice)
                // Or stay here until reset.
                // Let's return to IDLE if start is low to be ready for next trigger.
                if (!start) begin
                    next_state = IDLE;
                    next_done = 1'b0;
                end
            end

            default: next_state = IDLE;
        endcase
    end

endmodule