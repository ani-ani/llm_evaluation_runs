module anti_shuffle (
    input clk,
    input rst_n,
    input start,
    input [15:0][7:0] input_string,
    output reg [15:0][7:0] result_string,
    output reg done
);

    parameter STR_LEN = 16;
    parameter CHAR_W = 8;

    // State Encoding
    localparam IDLE = 3'b001;
    localparam SCAN_SORT = 3'b010;
    localparam OUTPUT = 3'b100;
    localparam DONE_STATE = 3'b101;

    // Registers
    reg [2:0] current_state;
    reg [CHAR_W-1:0] buffer [0:STR_LEN-1];
    
    // Sorting Registers
    reg sorting_active;
    reg [3:0] word_start_idx;
    reg [3:0] word_end_idx;
    reg [3:0] scan_idx;      // For scanning words and bubble sort outer loop
    reg [3:0] sort_idx;      // For bubble sort inner loop
    reg [3:0] pass_counter;  // To bound the 256 cycle requirement

    // Wires for ASCII checks
    wire is_alpha [0:STR_LEN-1];
    genvar i;
    generate
        for (i = 0; i < STR_LEN; i = i + 1) begin : alpha_check
            assign is_alpha[i] = ((buffer[i] >= 8'h41 && buffer[i] <= 8'h5A) || 
                                  (buffer[i] >= 8'h61 && buffer[i] <= 8'h7A));
        end
    endgenerate

    // Next State Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            case (current_state)
                IDLE: begin
                    if (start) begin
                        current_state <= SCAN_SORT;
                    end
                end
                SCAN_SORT: begin
                    // Transition to OUTPUT when all passes are done
                    // We will use a pass_counter to ensure 256 cycles (or fewer if done early)
                    // For simplicity and guaranteed latency, we run a fixed number of passes over the string
                    if (pass_counter >= 8'd255) begin // Wait out 256 cycles (0-255)
                        current_state <= OUTPUT;
                    end
                end
                OUTPUT: begin
                    current_state <= DONE_STATE;
                end
                DONE_STATE: begin
                    // Stay here until reset or new start
                    if (start) current_state <= SCAN_SORT;
                    else if (!rst_n) current_state <= IDLE;
                end
                default: current_state <= IDLE;
            endcase
        end
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset outputs and internal regs
            result_string <= '{default: 0};
            done <= 1'b0;
            pass_counter <= 8'd0;
            scan_idx <= 4'd0;
            sort_idx <= 4'd0;
            word_start_idx <= 4'd0;
            word_end_idx <= 4'd0;
            sorting_active <= 1'b0;
            // Clear buffer (optional, but good practice)
            // buffer <= '{default: 0}; // Cannot assign array directly in always block for some tools
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    pass_counter <= 8'd0;
                    scan_idx <= 4'd0;
                    sort_idx <= 4'd0;
                    sorting_active <= 1'b0;
                    if (start) begin
                        // Load input into buffer
                        buffer <= input_string;
                    end
                end

                SCAN_SORT: begin
                    // We implement a generic pass over the entire string per clock cycle.
                    // To meet 256 cycles requirement, we run the logic for exactly 256 cycles.
                    // We effectively perform one 'sweep' of bubble sort logic per cycle.
                    // Since the design is purely combinational per cycle for the sorted segment,
                    // we must sequence the operations carefully to use the 256 cycles.
                    
                    // Strategy: 
                    // Cycle 1..N: Process words sequentially.
                    // To stay within bounds, we use the pass_counter to iterate.
                    
                    pass_counter <= pass_counter + 1;
                    
                    // Simple Algorithm: Iterate through indices 0 to 15.
                    // In one clock cycle, we can perform comparisons for adjacent pairs.
                    // But to strictly adhere to "Use state machine" and "256 cycles", 
                    // we will serialize the sorting operation.
                    
                    // Refined Strategy for 256 cycles:
                    // We will perform a bubble sort sweep across the WHOLE buffer.
                    // However, we must respect word boundaries.
                    
                    // Logic to move along the buffer:
                    // We use scan_idx to track which character pair we are comparing.
                    
                    if (scan_idx < STR_LEN - 1) begin
                        // Check if both current and next are alphabetic
                        if (is_alpha[scan_idx] && is_alpha[scan_idx + 1]) begin
                            // Compare and Swap if needed (Bubble Sort logic)
                            if (buffer[scan_idx] > buffer[scan_idx + 1]) begin
                                buffer[scan_idx] <= buffer[scan_idx + 1];
                                buffer[scan_idx + 1] <= buffer[scan_idx];
                            end
                        end
                        // If either is non-alpha, we just skip (boundary preserved)
                        scan_idx <= scan_idx + 1;
                    end else begin
                        // End of buffer reached in this cycle (conceptually)
                        // To strictly use 256 cycles and be a "Sequential" module as requested,
                        // we will just increment pass_counter and reset scan_idx.
                        // This effectively performs 16 comparisons per cycle.
                        // 16 chars * 16 cycles = 256 comparisons total.
                        // Since we do 16 comparisons per cycle (if unconstrained), 
                        // we would be done in 16 cycles. 
                        // To enforce the 256 cycle latency, we can slow it down.
                        
                        // Let's do 1 comparison per cycle to be safe and simple.
                        // Loop 0 to 255.
                    end
                end

                OUTPUT: begin
                    // Transfer buffer to result_string
                    result_string <= buffer;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // --- Revised Datapath for Strict 1 Comparison Per Cycle (Guarantees 256 cycles) ---
    // The above logic attempts to do 16 comparisons per cycle. 
    // The requirement asks for 256 cycles to allow bubble sort on worst case.
    // Worst case for 16 elements is 120 swaps, but bubble sort usually runs N*N passes.
    // 16*16 = 256 passes.
    // Let's implement a cycle counter that performs one swap check per cycle.
    // We will reuse the same always block but overwrite the logic above with this specific sequence.

    // Re-implementation of SCAN_SORT logic specifically for 256 cycles:
    // We need a way to map 'pass_counter' (0-255) to specific comparisons.
    // Since 256 cycles > (16 * 16), we can afford to perform multiple sweeps.
    // Let's do a standard bubble sort inner loop logic driven by the cycle count.
    
    // Since we must provide a single module, let's ensure the logic is consistent.
    // The previous logic inside SCAN_SORT was a concurrent sweep. 
    // Let's replace it with a sequential logic that matches the 256 cycle intent.

endmodule

// The module above implements the logic. 
// To strictly meet "Use state machine" and "256 cycles", let's refine the 'SCAN_SORT' block.
// The current implementation in the block above (lines 95-125) is actually concurrent per clock 
// (doing up to 16 comparisons per clock). This might be too fast for the "256 cycles" constraint.
// However, the prompt says "256 clock cycles ... to allow bubble sort on worst case".
// This implies a serial process.

// Let's provide a cleaner implementation that adheres strictly to the request.
// We will implement a counter-based approach that performs the bubble sort algorithm 
// strictly one step per clock cycle (or logically mapped steps).

module anti_shuffle_final (
    input clk,
    input rst_n,
    input start,
    input [15:0][7:0] input_string,
    output reg [15:0][7:0] result_string,
    output reg done
);

    parameter STR_LEN = 16;
    parameter CHAR_W = 8;

    // States
    localparam IDLE = 2'b00;
    localparam SORT = 2'b01;
    localparam OUTPUT = 2'b10;
    localparam DONE = 2'b11;

    reg [1:0] state;
    reg [7:0] cycle_count; // 0-255
    reg [CHAR_W-1:0] buffer [0:STR_LEN-1];
    
    // Helper logic to check alpha
    function automatic logic is_alpha_func(input [7:0] char);
        begin
            is_alpha_func = (char >= 8'h41 && char <= 8'h5A) || (char >= 8'h61 && char <= 8'h7A);
        end
    endfunction

    // Sequencer for Bubble Sort:
    // To utilize 256 cycles, we can iterate through the array 16 times (for 16 chars) 
    // and in each iteration, perform the inner loop of bubble sort.
    // Let's simplify: Run a full sweep of the array (comparing adjacent pairs) 
    // exactly 16 times. 16 sweeps * 16 checks per sweep = 256 operations.
    // Since we want to do it in a sequential "clock cycle" manner, we can map:
    // cycle_count 0..15: Sweep 1
    // cycle_count 16..31: Sweep 2
    // ...
    // cycle_count 240..255: Sweep 16
    
    // In each cycle, we determine which pair to compare based on cycle_count.
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
            // buffer cleared implicitly or handled in IDLE
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        buffer <= input_string; // Load input
                        state <= SORT;
                    end
                end

                SORT: begin
                    // One comparison/sway per cycle logic
                    // We need to know the current sweep index and position within sweep
                    // sweep_idx = cycle_count / 16 (integer division)
                    // pos_idx = cycle_count % 16 (modulo)
                    // Actually, bubble sort inner loop usually goes 0 to N-1-sweep_idx.
                    // But to fill 256 cycles exactly with a simple pattern:
                    // We will perform (N-1) comparisons per sweep. N=16 -> 15 comparisons.
                    // 15 * 16 = 240. We have 256 cycles. We can just repeat or do extra idle.
                    // Let's stick to the prompt's "bubble sort logic".
                    
                    // We will perform 16 sweeps. Each sweep scans indices 0 to 14.
                    // Total comparisons = 16 * 15 = 240. 
                    // We will use the remaining 16 cycles to complete the sort (or just loop).
                    // To be safe and simple, let's just run the comparison logic.
                    
                    // Map cycle_count to (sweep, index)
                    // Let sweep = cycle_count[7:4] (0-15)
                    // Let index = cycle_count[3:0] (0-15)
                    
                    // If index < 15, we can do a comparison between index and index+1.
                    // However, standard bubble sort reduces the inner loop range.
                    // To keep it simple for 256 cycles, we will check ALL adjacent pairs 16 times.
                    // This guarantees sorting.
                    
                    if (cycle_count < 8'd255) begin
                        cycle_count <= cycle_count + 1;
                        
                        // Calculate indices based on cycle_count
                        // We can just iterate through indices 0 to 14 repeatedly.
                        // Let current_compare_index = cycle_count % 15.
                        // Since cycle_count goes 0-255, we will iterate 0-14 17 times roughly.
                        
                        // Let's use a separate index register for the scan to make it cleaner
                        // But to stick to one counter: 
                        // Use cycle_count[3:0] as the position (0-14). 
                        // Use cycle_count[7:4] as the repetition count.
                        
                        // If we use cycle_count[3:0] < 15:
                        if (cycle_count[3:0] < 4'd15) begin
                            if (buffer[cycle_count[3:0]] > buffer[cycle_count[3:0] + 1]) begin
                                // Check boundaries: Only swap if BOTH are alpha
                                // Or strictly: If they are adjacent in a word.
                                // Prompt: "Compare adjacent characters and swap if needed."
                                // "Non-alphabetic characters are preserved exactly at their positions"
                                
                                // Condition: Is char at index A, char at index+1 B.
                                // If A > B, AND both are alphabetic, swap.
                                // If A is alpha and B is not, they are boundary, don't swap.
                                // If A is not alpha and B is alpha, boundary, don't swap.
                                
                                // So, swap ONLY if both are alpha and A > B.
                                if (is_alpha_func(buffer[cycle_count[3:0]]) && 
                                    is_alpha_func(buffer[cycle_count[3:0] + 1])) begin
                                    buffer[cycle_count[3:0]] <= buffer[cycle_count[3:0] + 1];
                                    buffer[cycle_count[3:0] + 1] <= buffer[cycle_count[3:0]];
                                end
                            end
                        end
                        
                    end else begin
                        // 255 cycles done. Next cycle is 256th (total 256 cycles in state SORT + transition)
                        // Actually, cycle_count goes 0..255 (256 counts). 
                        // We run logic for 0..254. On 255, we transition.
                        state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    result_string <= buffer;
                    state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start) state <= IDLE; // Wait for start to go low before accepting new
                end
            endcase
        end
    end

endmodule
