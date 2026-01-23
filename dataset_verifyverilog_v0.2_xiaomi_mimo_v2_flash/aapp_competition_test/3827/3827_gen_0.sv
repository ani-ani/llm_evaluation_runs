module string_validator (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [2:0] idx,
    output reg result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam READ = 2'b01;
    localparam VALIDATE = 2'b10;
    localparam DONE_STATE = 2'b11;

    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [3:0] count_a;
    reg [3:0] count_b;
    reg [3:0] count_c;
    reg [7:0] prev_char;
    reg [3:0] cycle_counter;
    reg [7:0] buffer [0:7];
    reg [2:0] write_idx;
    reg order_violation;
    reg stop_processing;

    // Temporary variables for next state logic
    reg [3:0] next_count_a;
    reg [3:0] next_count_b;
    reg [3:0] next_count_c;
    reg [7:0] next_prev_char;
    reg [3:0] next_cycle_counter;
    reg next_order_violation;
    reg next_stop_processing;
    reg next_result;
    reg next_done;
    reg [2:0] next_write_idx;
    integer i;

    // State transition and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count_a <= 4'b0;
            count_b <= 4'b0;
            count_c <= 4'b0;
            prev_char <= 8'h00;
            cycle_counter <= 4'b0;
            order_violation <= 1'b0;
            stop_processing <= 1'b0;
            result <= 1'b0;
            done <= 1'b0;
            write_idx <= 3'b0;
            // Initialize buffer (optional but good practice)
            for (i = 0; i < 8; i = i + 1) begin
                buffer[i] <= 8'h00;
            end
        end else begin
            state <= next_state;
            count_a <= next_count_a;
            count_b <= next_count_b;
            count_c <= next_count_c;
            prev_char <= next_prev_char;
            cycle_counter <= next_cycle_counter;
            order_violation <= next_order_violation;
            stop_processing <= next_stop_processing;
            result <= next_result;
            done <= next_done;
            write_idx <= next_write_idx;
            // Buffer update logic for READ state
            if (state == READ && start) begin
                 // Input is captured based on idx, passed in char_in
                 // We need to store it in the buffer at the specified idx
                 buffer[idx] <= char_in;
            end
        end
    end

    // Combinational next state logic
    always @(*) begin
        // Default assignments to avoid latches
        next_state = state;
        next_count_a = count_a;
        next_count_b = count_b;
        next_count_c = count_c;
        next_prev_char = prev_char;
        next_cycle_counter = cycle_counter;
        next_order_violation = order_violation;
        next_stop_processing = stop_processing;
        next_result = result;
        next_done = 1'b0;
        next_write_idx = write_idx;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = READ;
                    next_count_a = 4'b0;
                    next_count_b = 4'b0;
                    next_count_c = 4'b0;
                    next_prev_char = 8'h00;
                    next_cycle_counter = 4'b0;
                    next_order_violation = 1'b0;
                    next_stop_processing = 1'b0;
                    next_write_idx = 3'b0;
                    next_result = 1'b0;
                end
            end

            READ: begin
                // We process input as it arrives. The problem description implies 8 cycles to process string.
                // Since inputs arrive every cycle, we process them immediately.
                // However, the interface uses idx. To simulate a stream, we assume idx increments or is fixed?
                // "idx for char_in (0 to 7)" implies we might receive all 8 chars, possibly out of order.
                // But a stream usually implies sequential. Let's assume sequential input, i.e., idx increments 0..7.
                // Or maybe 'start' triggers the capture of 1 char per cycle for 8 cycles.
                // If inputs are not sequential, we need to wait for all 8. But "8 cycles to process" suggests 1 char/cycle.
                // Let's assume the provided inputs are valid for the cycle and we act on them.
                // But the buffer logic `buffer[idx] <= char_in` in the clocked block implies random access.
                // If random access, we need to know when all 8 are valid. 
                // Let's stick to the timing: 8 cycles in READ. We iterate 8 times. 
                // We will consume `char_in` sequentially. 
                // Wait, the interface `idx` is input. This implies the sender puts char_in at idx.
                // If so, the module itself doesn't count indices, it sees inputs. 
                // To strictly follow "8 cycles to process", we likely count cycles 0-7.
                // Let's assume a standard streaming interface where `char_in` is valid when `start` is high (or valid signal).
                // The prompt says "start // start validation". Usually a pulse.
                // Let's re-read: "Input 'aabc' ... Expected: result=1 ... after 12 cycles".
                // If we have 8 cycles of input + 4 cycles of validation = 12.
                // The `idx` input is tricky. If it's a random access interface, we need a "load_done" or similar.
                // If it's stream, `idx` is redundant.
                // Let's assume `start` is held high for 8 cycles, feeding one char per cycle. 
                // OR, `start` pulses once, and then for 8 cycles `char_in` is valid.
                // Given `idx` is input, maybe the sender asserts `start` and puts `char_in` at `idx`.
                // To make it stateless-ish: `start` pulses, then we go to READ for 8 cycles.
                // Inside READ, we accept `char_in`. We need to know which index it is. 
                // If `idx` is an input, we rely on it.
                // Let's assume the testbench drives `char_in` and `idx` for 8 cycles.
                // We will count `cycle_counter` from 0 to 7.
                // We will latch `char_in` into `buffer[cycle_counter]`? No, `buffer[idx]`.
                // If `idx` is provided, we store it. 
                // But if we need to track order, we need the sequence. 
                // If `idx` is sequential, `buffer[idx]` works. 
                // If `idx` is not sequential, the order check depends on `buffer` content order.
                // Let's assume we read `char_in` whenever `start` is high during READ.
                // Since `start` is a single pulse in IDLE, maybe in READ we don't need `start`?
                // Let's assume `start` is high for 1 cycle in IDLE. Then we enter READ.
                // In READ, we assume `char_in` is valid for 8 cycles.
                // BUT the input spec says `input [2:0] idx`. This is explicit.
                // We will store `char_in` at `buffer[idx]`. 
                // We need a mechanism to know when all 8 chars are loaded.
                // Since we have a fixed 8 cycles latency requirement, let's simply count 8 cycles of `start` or `valid`.
                // Let's assume `start` is a pulse, and for the next 8 cycles, `char_in` is valid.
                // We use `idx` to determine the order for the validation part? 
                // Actually, the description: "Load characters into buffer (8 cycles)".
                // "Input 'aabc' ... characters ... 0,0,0,0". This implies the string is always 8 chars.
                // If the input is 8 chars, we can just store them.
                // Let's assume `start` triggers the sequence. 
                // The simplest interpretation for a stream: `start` goes high. We enter READ. 
                // We count 8 cycles. In each cycle, we take `char_in`.
                // What about `idx`? If the sender puts `char_in` and `idx` matching the cycle count (0..7), fine.
                // If not, we just store `buffer[idx] = char_in`. 
                // For the order check, we need to check the sequence. 
                // Let's define: In READ state, we capture `char_in` into `buffer[idx]`.
                // We increment a counter `write_idx` from 0 to 7.
                // Wait, `idx` is an INPUT. So the sender provides it.
                // We will assume the sender drives `idx` sequentially 0..7.
                // If we want to be robust, we just store the character at the specified index.
                // Then, for the VALIDATE step, we need to iterate through the buffer.
                // The prompt says: "Order Check ... during READ".
                // This implies we check as data comes in. 
                // So, `start` pulse -> READ. 
                // In READ, we receive `char_in` and `idx`. 
                // We need to know the *previous* character to check order.
                // If `idx` is sequential, `prev_char` is the char from previous cycle.
                // If `idx` is not sequential (e.g. 0, 3, 1), order checking is weird.
                // Given the context, `idx` is likely just to allow writing to the buffer, and we assume sequential operation or we sort later.
                // BUT, "Order violation detection during READ". This implies we must detect it on the fly.
                // Therefore, we must receive characters in order.
                // So, we assume `idx` increments 0..7.
                // Let's implement:
                // 1. In READ, we capture `char_in` into `buffer[idx]`.
                // 2. We compare `char_in` with `prev_char` (if `idx` > 0).
                // 3. To handle `idx` correctly, let's assume we are given `char_in` and `idx` and they are aligned.
                // 
                // Revised Logic for READ:
                // If `start` is asserted (pulse), we go to READ.
                // While in READ, we check `char_in` against `prev_char`. 
                // BUT `prev_char` is defined by `idx`? 
                // Let's simplify: We treat the input as a stream where `char_in` is the next character.
                // The `idx` input is confusing. 
                // Maybe `idx` is used for the *output* buffer? No, input.
                // Let's strictly follow: "Load characters into buffer (8 cycles)".
                // We will have a `cycle_counter` 0..7.
                // We will write `char_in` to `buffer[cycle_counter]`. 
                // Does `idx` matter? 
                // If the user provides `idx`, perhaps we write to `buffer[idx]`. 
                // Let's assume the testbench sends `char_in` and `idx` for 8 cycles. 
                // We will write `buffer[idx] <= char_in`.
                // For order check: 
                // The problem is `prev_char`. If `idx` jumps, we can't check order continuously.
                // I will assume `idx` is sequential 0..7. 
                // Wait, if `idx` is an input, I should probably use it to index the buffer.
                // Let's assume the stream comes in order, and `idx` is just a 'valid' index.
                // If `idx` is provided, we check `char_in` vs `prev_char`.
                // We need to detect order violation immediately.
                // Let's use `cycle_counter` to track how many chars we've received.
                // When `start` is high, go to READ.
                // In READ, if `cycle_counter` < 8:
                //   `buffer[idx] <= char_in` (or we can just use `idx` to track order? No, `idx` is input).
                //   Let's assume the sender provides `char_in` sequentially. `idx` might just be the counter output of the sender.
                //   We will ignore `idx` for the logic flow, just use it to store in buffer (though if sequential, index is known).
                //   We will rely on a simple counter `write_ptr` 0..7.
                //   Why have `idx` input then? 
                //   Maybe `idx` is the index of `char_in` in a register file style interface.
                //   If so, the controller sets `idx` and `char_in`.
                //   But we need to know when all 8 are done. 
                //   We will count `cycle_counter` from 0 to 7. 
                //   In each cycle, we assume `char_in` is valid. 
                //   We store `buffer[cycle_counter] <= char_in`.
                //   This satisfies "Load characters into buffer".
                //   Regarding `idx`: It is provided but we will use internal counter for sequencing.
                //   OR: `idx` is the internal index? No, `input [2:0] idx`.
                //   Let's assume `start` goes high. We enter READ.
                //   We need 8 cycles. 
                //   We will assume the sender provides `char_in` and sets `idx` to the current cycle count (0..7).
                //   We will check `cycle_counter` vs `idx` to ensure alignment? No, that's restrictive.
                //   Let's just assume `char_in` comes in order. 
                //   We will NOT use `idx` for logic, just store it if needed. 
                //   Actually, the problem says "input [2:0] idx // index for char_in". 
                //   This strongly implies we are writing to `buffer[idx]`.
                //   If we are writing to `buffer[idx]`, how do we check order? 
                //   We check order during READ. 
                //   This implies `idx` increments 0, 1, 2... and we receive `char_in`.
                //   If `idx` jumps, order check fails.
                //   So, let's check: `if (idx != cycle_counter) order_violation = 1`? No, that's not char order.
                //   Let's assume `char_in` is the stream and `idx` is just echoed or unused for logic.
                //   BUT, I must use the inputs. 
                //   Let's stick to `start` pulsing -> READ for 8 cycles.
                //   In each cycle, we take `char_in`. 
                //   We store `buffer[cycle_counter] <= char_in`.
                //   We check order of `char_in` against `prev_char`.
                //   We ignore `idx` for the logic flow, but store it? No, we use `idx` to validate the stream.
                //   Let's use `idx` as the 'valid index' signal. 
                //   If `start` is high, we enter READ. 
                //   We expect `idx` to be 0. Then 1. Then 2. 
                //   If `idx` arrives out of sequence, it's a protocol violation, not a string violation.
                //   However, `result` should be 0 on invalid string. 
                //   If `idx` arrives 0, 1, 2... we are good.
                //   Let's assume the sender drives `idx` 0..7. 
                //   We will capture `char_in` when `idx` matches `cycle_counter`.
                //   If `idx` != `cycle_counter`, we wait? 
                //   If we don't receive data for a cycle, we can't finish in 8 cycles.
                //   Let's simplify: `start` is high for 1 cycle. We go to READ.
                //   We have a counter `c` 0..7. 
                //   In READ, if `idx` == `c`, we capture `char_in` into `buffer[c]` and `c++`. 
                //   If `idx` != `c`, we might have a stall or error. 
                //   Given the "12 cycles" latency, we probably shouldn't stall. 
                //   So, we likely just use `char_in` directly.
                //   Let's assume `idx` is just there, and we process 8 cycles regardless.
                //   We will increment `cycle_counter` every clock in READ.
                //   We store `char_in` into `buffer[cycle_counter]`. 
                //   We check `char_in` against `prev_char`. 
                //   This works for sequential input. 
                //   If `idx` is provided but doesn't match `cycle_counter`, it's ambiguous. 
                //   I will assume the sender matches `idx` to the order. 
                //   Wait, if `idx` is an input, maybe the user puts `char_in` at random `idx`.
                //   If so, order checking in READ is impossible without sorting.
                //   So, `idx` must be sequential.
                //   I will ignore `idx` for the control flow, strictly following "8 cycles to process".
                //   I will use `char_in` as the stream.
                //   (If I must use `idx`, I would say `if (idx != cycle_counter) stop_processing = 1`, but let's skip that).
                //   Wait, the prompt says "Implementation Details: ... Order violation detection during READ".
                //   This implies `char_in` arrives in order.
                //   I will proceed with `cycle_counter` 0..7 driving the process.
                //   I will assume `char_in` is the character for that cycle.
                //   I will ignore `idx` for the logic, OR I will treat `idx` as the cycle counter. 
                //   If `idx` is input, it means the external world tells us the index.
                //   If I use internal counter, `idx` is redundant.
                //   Let's use `idx` to derive the state? No.
                //   Let's assume `start` triggers 8 cycles. `idx` is used to identify which buffer slot to update.
                //   But we process sequentially.
                //   Let's assume `idx` is the 'valid' indicator. 
                //   If `idx` is 0, 1, 2... we process. 
                //   If `idx` is a constant, we don't progress. 
                //   This is the most robust interpretation: 
                //   `start` -> IDLE to READ.
                //   In READ, we wait for `idx` to change? No, latency is fixed.
                //   I will ignore `idx` for the state transition and just use a counter.
                //   This is the only way to guarantee 12 cycles. 
                //   I will write the code assuming `char_in` is valid in READ.

                // Logic:
                // If `start` is high, transition to READ.
                // In READ:
                //   Increment cycle_counter (0 to 7).
                //   Capture `char_in` -> `buffer[cycle_counter]`.
                //   Check order violation: `if (char_in < prev_char) order_violation = 1`.
                //   Update `prev_char` = `char_in`.
                //   Count characters: `count_a`, `count_b`, `count_c`.
                //   Stop if null byte (0x00) or invalid char (not a, b, c).
                //   After 8 cycles (cycle_counter == 7), transition to VALIDATE.
                //   If stop_processing triggered earlier (e.g. invalid char), we still spend remaining cycles in READ or jump to VALIDATE? 
                //   Prompt says: "Processing stops immediately on invalid sequence". 
                //   But we must wait 12 cycles total. 
                //   If we stop early, we need to fill the time to 12 cycles. 
                //   Let's say we transition to VALIDATE early? 
                //   No, "Result valid 12 clock cycles after start".
                //   So we must wait exactly 4 cycles after processing.
                //   If we detect error in cycle 2, we have processed 2 chars. We need 4 validation cycles. 
                //   Total 2 + 4 = 6. That's less than 12.
                //   So we must continue counting until 12? 
                //   Or maybe we stay in READ for 8 cycles regardless? 
                //   "Processing stops immediately". This implies we stop updating counters.
                //   But we must wait for 12 cycles. 
                //   Let's go to VALIDATE only when cycle_counter reaches 7.
                //   If we detected invalid input, we keep `stop_processing` high. 
                //   In VALIDATE, we calculate result.

                // Transition to VALIDATE:
                if (cycle_counter == 4'd7) begin
                    next_state = VALIDATE;
                    next_cycle_counter = 4'b0;
                end else begin
                    next_cycle_counter = cycle_counter + 1;
                    
                    // Capture char_in (assuming sequential stream)
                    // If we are not stopped, process input
                    if (!stop_processing) begin
                        // Check for null terminator or invalid char
                        if (char_in == 8'h00 || 
                            (char_in != 8'h61 && char_in != 8'h62 && char_in != 8'h63)) begin
                            next_stop_processing = 1'b1;
                        end else begin
                            // Update counts
                            if (char_in == 8'h61) begin // 'a'
                                if (count_a < 15) next_count_a = count_a + 1;
                                else next_count_a = count_a; // Saturation
                            end else if (char_in == 8'h62) begin // 'b'
                                if (count_b < 15) next_count_b = count_b + 1;
                                else next_count_b = count_b;
                            end else if (char_in == 8'h63) begin // 'c'
                                if (count_c < 15) next_count_c = count_c + 1;
                                else next_count_c = count_c;
                            end

                            // Order check
                            if (cycle_counter > 0) begin
                                if (char_in < prev_char) begin
                                    next_order_violation = 1'b1;
                                end
                            end
                            next_prev_char = char_in;
                        end
                    end
                    // If stop_processing is already high, we just count cycles (wait)
                end
            end

            VALIDATE: begin
                // Verification takes 4 cycles.
                if (cycle_counter == 4'd3) begin
                    next_state = DONE_STATE;
                    next_cycle_counter = 4'b0;
                    next_done = 1'b1;
                    
                    // Calculate Result
                    if (order_violation || stop_processing) begin
                        next_result = 1'b0;
                    end else if (count_a < 1 || count_b < 1) begin
                        // Must have at least one 'a' and 'b'
                        next_result = 1'b0;
                    end else if ((count_c == count_a) || (count_c == count_b)) begin
                        next_result = 1'b1;
                    end else begin
                        next_result = 1'b0;
                    end
                end else begin
                    next_cycle_counter = cycle_counter + 1;
                    // Keep result/done low during calculation
                    next_result = result; 
                    next_done = 1'b0;
                end
            end

            DONE_STATE: begin
                // Wait for reset or next start. 
                // If start is asserted again, we transition to READ.
                if (start) begin
                    next_state = READ;
                    next_count_a = 4'b0;
                    next_count_b = 4'b0;
                    next_count_c = 4'b0;
                    next_prev_char = 8'h00;
                    next_cycle_counter = 4'b0;
                    next_order_violation = 1'b0;
                    next_stop_processing = 1'b0;
                    next_result = 1'b0;
                    next_done = 1'b0;
                    next_write_idx = 3'b0;
                end else begin
                    next_done = 1'b1;
                end
            end
        endcase
    end

endmodule