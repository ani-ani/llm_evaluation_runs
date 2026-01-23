module string_equivalence (
    input clk,
    input rst_n,
    input start,
    input [127:0] string_a,
    input [127:0] string_b,
    output reg equivalent,
    output reg done
);

    // State definition
    localparam IDLE = 3'b000;
    localparam INIT = 3'b001;
    localparam PROCESS = 3'b010;
    localparam NEXT_PASS = 3'b011;
    localparam COMPARE = 3'b100;
    localparam FINISH = 3'b101;

    // Internal Registers
    reg [127:0] reg_a;
    reg [127:0] reg_b;
    reg [2:0] state;
    reg [2:0] next_state;
    reg [2:0] block_size; // Represents k (1, 2, 4, 8)
    reg [2:0] chunk_idx;  // Iterates 0 to 7 (8 chunks of size 2k)
    
    // Helper wires for lexicographical comparison of blocks
    wire [127:0] val_a;
    wire [127:0] val_b;
    wire block_greater_a;
    wire block_greater_b;

    // Determine the current block boundaries based on block_size
    // block_size is the size of half-chunk (L or R). Total chunk size is 2*block_size.
    // block_size encoded as power of 2? Let's use direct size in bytes (1, 2, 4, 8).
    // The block to compare/swap is determined by chunk_idx and block_size.
    
    // We need to extract the two halves of the current chunk from reg_a and reg_b
    // Calculate shift amounts: chunk_idx * 2 * block_size is the start bit index of the chunk
    // L starts at start_idx, R starts at start_idx + block_size*8
    
    reg [7:0] shift_amount_a; // In bytes
    reg [7:0] shift_amount_b; // In bytes
    reg [7:0] size_bytes;     // Size of half-block in bytes (1, 2, 4, 8)
    
    // Extracted chunks
    wire [63:0] chunk_a_L;
    wire [63:0] chunk_a_R;
    wire [63:0] chunk_b_L;
    wire [63:0] chunk_b_R;
    
    // Comparison logic (combinational)
    // Since widths vary, we construct the full block for comparison
    // Actually, we can just compare the extracted parts. 
    // We need to support variable width comparison. 
    // Let's use the shift amounts to mask and compare.
    
    // Simplest approach: define vectors for L and R aligned to LSB, pad zeros, compare.
    // Since max width is 8 bytes (64 bits), we can use 64-bit intermediate wires.
    
    // Shift logic: we need to shift the register right by shift_amount bytes, then mask.
    // Note: Verilog index [0] is LSB. If we treat string as byte array, byte 0 is bits [7:0].
    
    // Let's assume Big Endian for the string array? No, usually ASCII string in mem is byte 0 is char 0.
    // Input [127:0] string_a: Let's assume [7:0] is char 0.
    
    // Extract Logic:
    // We will use shift amounts calculated in combinational block based on chunk_idx and block_size.
    
    // Helper to swap if condition met
    reg do_swap_a;
    reg do_swap_b;
    
    // Combinational process to calculate indices and values
    always @(*) begin
        // Default values
        size_bytes = 0;
        shift_amount_a = 0;
        shift_amount_b = 0;
        
        // Calculate size and shift
        // block_size input: 1, 2, 4, 8
        size_bytes = block_size; // 1 byte, 2 bytes, etc.
        
        // Shift amount = chunk_idx * 2 * size_bytes
        // Since max chunks 8 and max size 8, result is 0-120.
        // We can use a case statement or simple multiplication.
        // For hardware, simple shift is best: chunk_idx * size_bytes * 2
        // If we pre-calculate: 
        case (chunk_idx)
            3'd0: shift_amount_a = 0;
            3'd1: shift_amount_a = size_bytes << 1; // *2
            3'd2: shift_amount_a = size_bytes << 2; // *4
            3'd3: shift_amount_a = size_bytes * 6;
            3'd4: shift_amount_a = size_bytes << 3; // *8
            3'd5: shift_amount_a = size_bytes * 10;
            3'd6: shift_amount_a = size_bytes * 12;
            3'd7: shift_amount_a = size_bytes * 14;
        endcase
        shift_amount_b = shift_amount_a + size_bytes;
    end

    // Extract chunks (64-bit aligned for maximum size)
    // We need to shift the 128-bit register right by 'shift_amount' * 8 bits.
    // Then take the lower 'size_bytes*8' bits for L, and next 'size_bytes*8' bits for R.
    
    wire [127:0] shifted_a;
    wire [127:0] shifted_b;
    assign shifted_a = reg_a >> (shift_amount_a * 8);
    assign shifted_b = reg_b >> (shift_amount_b * 8);
    
    // Align L and R to LSB for comparison
    assign chunk_a_L = shifted_a[63:0]; // This contains L + padding
    assign chunk_a_R = shifted_a[127:64]; // This contains R + padding
    assign chunk_b_L = shifted_b[63:0];
    assign chunk_b_R = shifted_b[127:64];

    // Generate masked versions for comparison
    // Mask size: 1<<(size_bytes*8) - 1. 
    // Actually we just need to compare the valid bytes. 
    // Since we compare lexicographically (byte by byte), we should compare the full 64-bit values
    // if we keep the data right-aligned. 
    // Example: size 1. L is chunk_a_L[7:0], R is chunk_a_L[15:8]. 
    // We can just compare the words if we are careful about alignment.
    // If we align L to LSB, we can compare L vs R directly if we also align R to LSB.
    
    // Let's create aligned L and R for A
    // L is at shift_amount_a. R is at shift_amount_a + size_bytes.
    // We want to compare L vs R. 
    // Actually, we just need to compare the two halves of the chunk.
    // The chunk is at shift_amount_a, length 2*size_bytes.
    // L is lower part, R is upper part.
    
    wire [63:0] cmp_L_a;
    wire [63:0] cmp_R_a;
    wire [63:0] cmp_L_b;
    wire [63:0] cmp_R_b;
    
    // Mask generation
    wire [63:0] mask;
    assign mask = (64'h1 << (size_bytes * 8)) - 1;
    
    // Align L to LSB: (reg_a >> (shift_amount_a*8)) & mask
    // Align R to LSB: (reg_a >> ((shift_amount_a+size_bytes)*8)) & mask
    // Then compare.
    
    assign cmp_L_a = (reg_a >> (shift_amount_a * 8)) & mask;
    assign cmp_R_a = (reg_a >> ((shift_amount_a + size_bytes) * 8)) & mask;
    assign cmp_L_b = (reg_b >> (shift_amount_a * 8)) & mask;
    assign cmp_R_b = (reg_b >> ((shift_amount_a + size_bytes) * 8)) & mask;
    
    // Comparison results
    // Lexicographical: if L > R, swap. If L < R, keep. If equal, keep.
    // Note: The problem says "L > R, swap".
    
    always @(*) begin
        do_swap_a = 0;
        do_swap_b = 0;
        
        // Compare A
        if (cmp_L_a > cmp_R_a) do_swap_a = 1;
        
        // Compare B
        if (cmp_L_b > cmp_R_b) do_swap_b = 1;
    end

    // State Register and Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            equivalent <= 0;
            reg_a <= 0;
            reg_b <= 0;
            block_size <= 1;
            chunk_idx <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    reg_a <= string_a;
                    reg_b <= string_b;
                    block_size <= 1; // k=1
                    chunk_idx <= 0;
                    state <= PROCESS;
                end

                PROCESS: begin
                    // Perform swap for current chunk if needed
                    if (do_swap_a) begin
                        // Swap L and R in reg_a
                        // reg_a = (reg_a & ~(mask << (shift_amount_a*8))) ... 
                        // Easier: reconstruct the register
                        // We have L and R extracted. 
                        // Current: [Pad][R][L][Pad]
                        // Want: [Pad][L][R][Pad]
                        // We need to clear the chunk area and place L and R swapped.
                        
                        // Clear chunk area
                        reg_a <= reg_a & ~((mask << (shift_amount_a*8)) | (mask << ((shift_amount_a+size_bytes)*8))); 
                        // Place L (original R) and R (original L)
                        // Note: cmp_L_a and cmp_R_a are the values aligned to LSB.
                        // We place cmp_R_a at shift_amount_a, and cmp_L_a at shift_amount_a+size_bytes.
                        reg_a <= (reg_a & ~((mask << (shift_amount_a*8)) | (mask << ((shift_amount_a+size_bytes)*8)))) 
                                 | (cmp_R_a << (shift_amount_a*8)) 
                                 | (cmp_L_a << ((shift_amount_a+size_bytes)*8));
                    end
                    
                    if (do_swap_b) begin
                        reg_b <= (reg_b & ~((mask << (shift_amount_a*8)) | (mask << ((shift_amount_a+size_bytes)*8)))) 
                                 | (cmp_R_b << (shift_amount_a*8)) 
                                 | (cmp_L_b << ((shift_amount_a+size_bytes)*8));
                    end
                    
                    // Update index
                    if (chunk_idx < 7) begin // 0 to 7 (8 chunks)
                        chunk_idx <= chunk_idx + 1;
                    end else begin
                        chunk_idx <= 0;
                        state <= NEXT_PASS;
                    end
                end

                NEXT_PASS: begin
                    // Double block_size
                    block_size <= block_size << 1; // 1->2->4->8->16
                    
                    if (block_size < 8) begin
                        state <= PROCESS;
                    end else begin
                        // block_size becomes 8 in this cycle. 
                        // Wait, if block_size was 8, we are done with passes.
                        // The check should be: was the pass just completed block_size 8?
                        // Logic: block_size is updated. 
                        // If we just finished processing with block_size=4, we update to 8.
                        // We still need to process with block_size=8 (pass 4).
                        // Wait, description says: After k=8 is processed.
                        // Passes: k=1, k=2, k=4, k=8. 
                        // So if block_size becomes 8, we still need to PROCESS it.
                        // After PROCESS with k=8, we go to COMPARE.
                        // So condition to go to COMPARE is: if we just finished PROCESS with k=8.
                        // But we update block_size in NEXT_PASS. 
                        // Let's change logic: 
                        // NEXT_PASS increments block_size. 
                        // If the NEW block_size is <= 8, go PROCESS.
                        // But we need to process 1, 2, 4, 8.
                        // If current block_size was 8, we are done with loop.
                        
                        // Let's restructure slightly. 
                        // In NEXT_PASS, check if block_size == 8. If so, go COMPARE. 
                        // If not, update block_size and go PROCESS.
                        // Wait, if block_size is currently 1, we process, then go NEXT_PASS. 
                        // block_size becomes 2. 
                        // So in NEXT_PASS, we have just updated block_size.
                        // We want to process 1, 2, 4, 8.
                        // If block_size == 1 (old), we update to 2. We need to process 2.
                        // So we should check: if block_size > 8? No.
                        
                        // Correct Logic:
                        // In NEXT_PASS:
                        // If block_size == 8: 
                        //   We have already processed k=8 in the previous PROCESS state.
                        //   Go to COMPARE.
                        // Else:
                        //   block_size <= block_size * 2;
                        //   state <= PROCESS;
                        
                        if (block_size == 8) begin
                            state <= COMPARE;
                        end else begin
                            block_size <= block_size << 1;
                            state <= PROCESS;
                        end
                    end
                end

                COMPARE: begin
                    if (reg_a == reg_b) begin
                        equivalent <= 1;
                    end else begin
                        equivalent <= 0;
                    end
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule