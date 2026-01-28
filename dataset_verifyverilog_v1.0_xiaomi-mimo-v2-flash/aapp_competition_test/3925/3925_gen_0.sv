module ZebraSolver #(
    parameter MAX_LEN = 64
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire data_in,
    input wire data_valid,
    input wire [5:0] len_in,
    output reg [6:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] RECV = 3'd1;
    localparam [2:0] SCAN = 3'd2;
    localparam [2:0] DONE = 3'd3;

    // Registers
    reg [2:0] state, next_state;
    reg [5:0] length_reg;          // Current string length
    reg [5:0] idx;                 // General purpose index
    reg [6:0] max_run;             // Current maximum run found
    reg [6:0] curr_run;            // Current run length
    reg bit_prev;                  // Previous bit for comparison
    reg bit_curr;                  // Current bit from buffer
    reg bit_first;                 // Store the first bit of the string
    
    // Buffer to store the input string (1 bit wide)
    // In synthesizable Verilog, we use a register array for small sizes
    reg [0:0] buffer [0:MAX_LEN-1]; // Indexed [0] to [MAX_LEN-1]
    
    // Control signals
    reg scanning_done;
    
    integer i;

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
                if (start) next_state = RECV;
            end
            RECV: begin
                // Transition when we have read 'len_in' bits
                if (data_valid && (idx == length_reg - 6'd1)) begin
                    next_state = SCAN;
                end
            end
            SCAN: begin
                // Scan 2 * length bits (s + s logic)
                // We iterate idx from 0 to 2*length - 1
                if (scanning_done) begin
                    next_state = DONE;
                end
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            result <= 7'd0;
            done <= 1'b0;
            length_reg <= 6'd0;
            idx <= 6'd0;
            max_run <= 7'd0;
            curr_run <= 7'd0;
            bit_prev <= 1'b0;
            bit_curr <= 1'b0;
            bit_first <= 1'b0;
            scanning_done <= 1'b0;
            // Clear buffer (optional but good practice)
            for (i = 0; i < MAX_LEN; i = i + 1) begin
                buffer[i] <= 1'b0;
            end
        end else begin
            // Default values
            done <= 1'b0;
            scanning_done <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        length_reg <= len_in;
                        idx <= 6'd0;
                        max_run <= 7'd0;
                        curr_run <= 7'd0;
                        // No need to clear buffer here, we overwrite
                    end
                end

                RECV: begin
                    if (data_valid) begin
                        // Store bit in buffer
                        buffer[idx] <= data_in;
                        
                        // Capture first bit
                        if (idx == 6'd0) begin
                            bit_first <= data_in;
                            curr_run <= 7'd1;
                            max_run <= 7'd1;
                            bit_prev <= data_in;
                        end else begin
                            // Check alternation for linear scan (prefix logic part)
                            if (data_in != bit_prev) begin
                                curr_run <= curr_run + 7'd1;
                                if (curr_run + 7'd1 > max_run) begin
                                    max_run <= curr_run + 7'd1;
                                end
                            end else begin
                                curr_run <= 7'd1;
                            end
                            bit_prev <= data_in;
                        end
                        
                        // Increment index
                        idx <= idx + 6'd1;
                    end
                end

                SCAN: begin
                    // We need to simulate s + s logic
                    // Total iterations = 2 * length_reg
                    // If length is 0, skip
                    if (length_reg == 6'd0) begin
                        scanning_done <= 1'b1;
                    end else if (idx < (length_reg << 1)) begin
                        // Determine bit from buffer (circular access)
                        // current index in s is idx % length_reg
                        // Since length <= 64, idx is up to 128. 
                        // We can compute index manually or rely on modulo if synthesizer supports it.
                        // Let's do manual modulo logic for safety or use simple register logic.
                        // Since idx increments, we can track index within buffer.
                        
                        // Find current buffer index: idx % length_reg
                        // Note: length_reg is <= 64, so idx % length_reg is just idx if idx < 64, else idx - 64.
                        bit_curr <= (idx < length_reg) ? buffer[idx] : buffer[idx - length_reg];
                        
                        // Logic check: 
                        // We are scanning s+s. We need to compare current bit with previous bit in s+s.
                        // Previous bit is at (idx - 1) % (2*length)? No, just previous in sequence.
                        // We stored 'bit_prev' from RECV phase. 
                        // For the first bit of SCAN (idx=0), bit_prev is the last bit of RECV.
                        
                        // Actually, let's restart the run tracking for the SCAN phase if we want to find
                        // the longest run in s+s purely. 
                        // Or we can continue from where RECV left off.
                        // The 'max_run' currently holds the max run in 's' (linear).
                        // We want to find max run in 's+s' which might span the boundary.
                        
                        // Let's reset curr_run for the SCAN phase and re-scan the whole s+s (excluding the first bit if we want, but easier to re-scan).
                        // Wait, if we re-scan, we lose the 'max_run' from RECV.
                        // Better: Continue from idx=0 of SCAN phase.
                        // At start of SCAN, 'bit_prev' holds the last bit of the string.
                        // We load the first bit of the string (buffer[0]) as 'bit_curr'.
                        
                        // Re-logic:
                        // We iterate i from 0 to 2*length - 1.
                        // Access buffer[i % length].
                        // Compare with buffer[(i-1) % length] (handling wrap for i=0 -> last bit).
                        
                        // Let's use 'idx' as the loop counter 0 to 2N-1.
                        // We need the previous bit to compare.
                        // For i=0, prev is s[N-1].
                        // For i>0, prev is s[(i-1)%N].
                        
                        // Let's compute indices for clarity:
                        // curr_buf_idx = (idx < length_reg) ? idx : (idx - length_reg);
                        // prev_buf_idx = (idx == 0) ? (length_reg - 1) : 
                        //                (idx <= length_reg) ? (idx - 1) : 
                        //                (idx - length_reg - 1); 
                        // This is messy. 
                        
                        // Simpler: Use a separate counter for the buffer index that wraps automatically.
                        // Let's reuse 'idx' logic carefully.
                        
                        // We need to compare current bit with the bit at (idx - 1) modulo (2*length)? 
                        // No, the sequence is linear in s+s.
                        // Current bit: s[idx % N]
                        // Previous bit: s[(idx - 1) % N]
                        
                        // Implementing (idx-1)%N efficiently:
                        // If idx == 0: prev_idx = N - 1
                        // Else: prev_idx = idx - 1 (if idx < N) or idx - 1 (if idx >= N)
                        // Wait, if idx=65 (N=64), we are looking at s[1]. Previous is s[0].
                        // So the mapping is: bit is at idx_mod = (idx < length_reg ? idx : idx - length_reg)
                        // Previous bit is at prev_idx_mod = (idx == 0) ? length_reg-1 : 
                        //                                      (idx <= length_reg) ? idx-1 : 
                        //                                      idx - length_reg - 1
                        
                        // Let's simplify the FSM state logic:
                        // At each step, we load 'bit_curr' and 'bit_prev'.
                        
                        // Calculate indices:
                        // int curr_idx, prev_idx;
                        // curr_idx = (idx < length_reg) ? idx : (idx - length_reg);
                        // prev_idx = (idx == 0) ? (length_reg - 1) : 
                        //           (idx <= length_reg) ? (idx - 1) : 
                        //           (idx - length_reg - 1);
                        
                        // Since we can't use integer variables in always block for synthesis easily if they act as state,
                        // we will compute indices using temporary wires or logic.
                        
                        // We need a temporary 'prev_bit' for comparison.
                        // We can update 'bit_prev' register at the end of the cycle.
                        
                        // 1. Get current bit from buffer:
                        reg [5:0] curr_buf_idx;
                        reg [5:0] prev_buf_idx;
                        
                        if (idx < length_reg) begin
                            curr_buf_idx = idx;
                        end else begin
                            curr_buf_idx = idx - length_reg;
                        end
                        
                        if (idx == 6'd0) begin
                            prev_buf_idx = length_reg - 6'd1;
                        end else if (idx <= length_reg) begin
                            prev_buf_idx = idx - 6'd1;
                        end else begin
                            prev_buf_idx = idx - length_reg - 6'd1;
                        end
                        
                        // Read bits
                        bit_curr <= buffer[curr_buf_idx];
                        bit_prev <= buffer[prev_buf_idx];
                        
                        // Compare
                        if (buffer[curr_buf_idx] != buffer[prev_buf_idx]) begin
                            // Alternating
                            curr_run <= curr_run + 7'd1;
                            if (curr_run + 7'd1 > max_run) begin
                                max_run <= curr_run + 7'd1;
                            end
                        end else begin
                            // Not alternating, reset run to 1 (current bit starts a new run)
                            curr_run <= 7'd1;
                            // Note: max_run is not updated here because a single bit is always a run of 1, 
                            // and max_run is likely already >= 1.
                        end
                        
                        // Cap max_run at length_reg (circular logic limit)
                        // Actually, the problem asks for max zebra in circular string, capped at N.
                        // So we shouldn't let max_run exceed N.
                        if (max_run > length_reg) begin
                            max_run <= length_reg;
                        end
                        
                        idx <= idx + 6'd1;
                    end else begin
                        // Scanning finished
                        scanning_done <= 1'b1;
                    end
                end

                DONE: begin
                    result <= max_run;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule