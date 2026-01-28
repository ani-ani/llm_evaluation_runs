module ArrayReverse (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] arr,
    input wire [3:0] k,
    output reg [63:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state;
    reg [3:0] left_idx;
    reg [3:0] right_idx;
    reg [2:0] cycle_count;
    localparam [2:0] MAX_CYCLES = 3'd5;

    // Extract input bytes for easier access
    wire [7:0] in_byte [0:7];
    assign in_byte[0] = arr[7:0];
    assign in_byte[1] = arr[15:8];
    assign in_byte[2] = arr[23:16];
    assign in_byte[3] = arr[31:24];
    assign in_byte[4] = arr[39:32];
    assign in_byte[5] = arr[47:40];
    assign in_byte[6] = arr[55:48];
    assign in_byte[7] = arr[63:56];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 64'd0;
            done <= 1'b0;
            left_idx <= 4'd0;
            right_idx <= 4'd0;
            cycle_count <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 3'd0;
                    if (start) begin
                        if (k == 4'd0) begin
                            // No reversal needed, copy input to result
                            result <= arr;
                            state <= DONE_STATE;
                        end else begin
                            // Initialize for processing
                            left_idx <= 4'd0;
                            right_idx <= (k > 4'd8) ? 4'd7 : (k - 4'd1);
                            state <= PROCESSING;
                        end
                    end
                end

                PROCESSING: begin
                    cycle_count <= cycle_count + 3'd1;

                    // Build result array from bytes
                    // We build it as we process (left side is being reversed)
                    // Process swap and build result
                    if (left_idx < right_idx && left_idx < 4'd8 && right_idx < 4'd8) begin
                        // Swap: result gets right side byte at left position
                        // and left side byte at right position
                        // We need to handle result update incrementally
                        // For simplicity, we'll process the swap and keep result updated
                        
                        // Copy to result based on current state of processing
                        // This is a bit tricky with combinational, so we'll
                        // track swaps in a register array and assign at the end
                    end

                    // Increment indices
                    if (left_idx < right_idx && left_idx < 4'd8) begin
                        left_idx <= left_idx + 4'd1;
                        right_idx <= right_idx - 4'd1;
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Combinational logic for result construction
    always @(*) begin
        // Default: copy all input bytes
        result[7:0] = in_byte[0];
        result[15:8] = in_byte[1];
        result[23:16] = in_byte[2];
        result[31:24] = in_byte[3];
        result[39:32] = in_byte[4];
        result[47:40] = in_byte[5];
        result[55:48] = in_byte[6];
        result[63:56] = in_byte[7];

        // Only modify during processing or after
        if (state != IDLE) begin
            // Reverse elements 0 to k-1 (or 0 to 7 if k>8)
            // We need to check all indices and swap appropriately
            // Use a loop for the reversal logic
            
            // Create temporary result array for processing
            // This is tricky without arrays, so we'll use explicit assignments
            
            // For each index i from 0 to 7
            // if i < k and i < (k-i), swap with (k-1-i)
            // Actually simpler: build result based on final indices
            
            // Use local variables for clarity
            // This is combinational, so we can compute the final result
            
            if (k >= 4'd8) begin
                // Reverse entire array
                result[7:0] = in_byte[7];
                result[15:8] = in_byte[6];
                result[23:16] = in_byte[5];
                result[31:24] = in_byte[4];
                result[39:32] = in_byte[3];
                result[47:40] = in_byte[2];
                result[55:48] = in_byte[1];
                result[63:56] = in_byte[0];
            end else if (k > 4'd0) begin
                // Reverse first k elements, keep rest
                // k-1 is the last index to swap with index 0
                // k-2 swaps with 1, etc.
                
                // For each position i from 0 to k-1
                // If i < (k-i), place in_byte[k-1-i] at position i
                // If i >= (k-i), place in_byte[i] at position i (already copied)
                // Wait, that's not right for the second half of reversed segment
                
                // Simpler: Build from scratch
                // For i = 0 to k-1: result_byte[i] = in_byte[k-1-i]
                // For i = k to 7: result_byte[i] = in_byte[i]
                
                // Handle reversed portion
                if (k >= 4'd1) result[7:0] = in_byte[k-1];
                if (k >= 4'd2) result[15:8] = in_byte[k-2];
                if (k >= 4'd3) result[23:16] = in_byte[k-3];
                if (k >= 4'd4) result[31:24] = in_byte[k-4];
                if (k >= 4'd5) result[39:32] = in_byte[k-5];
                if (k >= 4'd6) result[47:40] = in_byte[k-6];
                if (k >= 4'd7) result[55:48] = in_byte[k-7];
                if (k >= 4'd8) result[63:56] = in_byte[k-8];
                
                // For positions >= k, copy directly from input
                // But we need to be careful not to overwrite the reversed portion
                // Since k can be any value 0-8, we need to handle all cases
                
                // For k=0: all positions copy from input (already set)
                // For k=1: position 0 from in_byte[0] (no change), positions 1-7 from input
                // For k=2: positions 0,1 from in_byte[1], in_byte[0], positions 2-7 from input
                // etc.
                
                // The logic above only sets the reversed portion correctly.
                // We need to ensure positions >= k are preserved from input.
                // Since we initialized result with input, we only need to modify
                // the reversed portion.
                
                // Actually, the initialization copies everything from input.
                // We just need to swap the first k elements.
                // But our current logic overwrites them correctly.
                
                // Wait, there's an issue with the non-reversed portion.
                // For k=5: result[0]=in[4], result[1]=in[3], result[2]=in[2], result[3]=in[1], result[4]=in[0]
                // result[5]=in[5], result[6]=in[6], result[7]=in[7]
                // This is correct!
                
                // But what about the cases where k-1-i < 0? We guard with if statements.
                // What about positions in the reversed portion that need to come from later indices?
                // For k=5, position 0 gets in[4], position 1 gets in[3], position 2 gets in[2]
                // Position 2 is in the middle, so it stays in place. That's correct.
                
                // Actually, the issue is that for positions i >= k/2, we're overwriting
                // with in_byte[k-1-i] which might be correct, but we need to make sure
                // we're not copying from the wrong place.
                
                // Let's reconsider. For k=5:
                // result[0] = in[4] (k-1)
                // result[1] = in[3] (k-2)
                // result[2] = in[2] (k-3)
                // result[3] = in[1] (k-4)
                // result[4] = in[0] (k-5)
                // result[5] = in[5] (preserved)
                // result[6] = in[6] (preserved)
                // result[7] = in[7] (preserved)
                // This is correct!
                
                // The issue is that the if statements above only set result when k >= certain value.
                // For k=5, we set result[0..4], but result[5..7] remain as input (correct).
                // For k=4, we set result[0..3], result[4..7] remain as input (correct).
                // This seems to work!
                
                // Wait, but what if k=0? Then we don't enter the else-if at all.
                // And result is already copied from input. Correct.
                
                // What if k=1? result[0] = in[0] (correct, no reversal). result[1..7] from input (correct).
                // What if k=2? result[0] = in[1], result[1] = in[0], result[2..7] from input (correct).
                
                // Hmm, but for k=5, result[0] gets in[4], result[1] gets in[3], etc.
                // What about result[2]? It gets in[2], which is correct (middle element stays).
                // What about result[3]? It gets in[1], which is correct (swapped with position 1).
                // What about result[4]? It gets in[0], which is correct (swapped with position 0).
                
                // Actually, I realize there's a subtle bug. For k=5:
                // The reversed portion is indices 0-4.
                // result[0] = in[4]
                // result[1] = in[3]
                // result[2] = in[2]
                // result[3] = in[1]
                // result[4] = in[0]
                // This is exactly the reverse of in[0..4]. Correct!
                
                // But wait, what about the case where we're setting result[2] = in[2]?
                // That's fine, it's the middle element.
                
                // Actually, let me trace through more carefully.
                // For k=5, we have:
                // if (k >= 4'd1) result[7:0] = in_byte[4];   // result[0] = in[4]
                // if (k >= 4'd2) result[15:8] = in_byte[3];  // result[1] = in[3]
                // if (k >= 4'd3) result[23:16] = in_byte[2]; // result[2] = in[2]
                // if (k >= 4'd4) result[31:24] = in_byte[1]; // result[3] = in[1]
                // if (k >= 4'd5) result[39:32] = in_byte[0]; // result[4] = in[0]
                // The remaining result[47:40], result[55:48], result[63:56] are already
                // set to in_byte[5], in_byte[6], in_byte[7] from initialization.
                // This is correct!
                
                // Actually, I need to be more careful. The initialization sets result
                // based on the current 'arr' input. But during PROCESSING state,
                // we're building the result as we go.
                
                // Let me reconsider the whole approach. The cleanest way is:
                // 1. In IDLE, when start=1, copy arr to a temp register array
                // 2. In PROCESSING, perform swaps on the temp array
                // 3. Copy temp array to result
                
                // But without using unpacked arrays, this is hard.
                
                // Alternative: The processing happens in one cycle if we do it combinational.
                // We can compute the entire result in one combinational always block.
                // The FSM just handles the start/done timing.
                
                // Given the constraints (max 100 cycles, but operation is simple),
                // we can do the reversal in one cycle after start.
                
                // So the FSM can be simpler:
                // IDLE -> PROCESSING (one cycle) -> DONE -> IDLE
                
                // The combinational block handles the reversal.
                // But we need to store the input at start.
                
                // Let's add a register to store the input when start is asserted.
            end
        end
    end

    // Revised FSM with input register
    reg [63:0] stored_input;
    reg [3:0] stored_k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 64'd0;
            done <= 1'b0;
            stored_input <= 64'd0;
            stored_k <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        stored_input <= arr;
                        stored_k <= (k > 4'd8) ? 4'd8 : k;
                        state <= PROCESSING;
                    end
                end

                PROCESSING: begin
                    // One cycle for processing
                    // The result is computed combinationally from stored_input and stored_k
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Combinational result computation
    // Extract bytes from stored input
    wire [7:0] stored_byte [0:7];
    assign stored_byte[0] = stored_input[7:0];
    assign stored_byte[1] = stored_input[15:8];
    assign stored_byte[2] = stored_input[23:16];
    assign stored_byte[3] = stored_input[31:24];
    assign stored_byte[4] = stored_input[39:32];
    assign stored_byte[5] = stored_input[47:40];
    assign stored_byte[6] = stored_input[55:48];
    assign stored_byte[7] = stored_input[63:56];

    always @(*) begin
        // Default: copy all stored bytes to result
        result[7:0] = stored_byte[0];
        result[15:8] = stored_byte[1];
        result[23:16] = stored_byte[2];
        result[31:24] = stored_byte[3];
        result[39:32] = stored_byte[4];
        result[47:40] = stored_byte[5];
        result[55:48] = stored_byte[6];
        result[63:56] = stored_byte[7];

        // Reverse first stored_k elements
        case (stored_k)
            4'd0, 4'd1: begin
                // No reversal needed (k=0 or k=1 means same array)
            end
            4'd2: begin
                result[7:0] = stored_byte[1];
                result[15:8] = stored_byte[0];
            end
            4'd3: begin
                result[7:0] = stored_byte[2];
                result[15:8] = stored_byte[1];
                result[23:16] = stored_byte[0];
            end
            4'd4: begin
                result[7:0] = stored_byte[3];
                result[15:8] = stored_byte[2];
                result[23:16] = stored_byte[1];
                result[31:24] = stored_byte[0];
            end
            4'd5: begin
                result[7:0] = stored_byte[4];
                result[15:8] = stored_byte[3];
                result[23:16] = stored_byte[2];
                result[31:24] = stored_byte[1];
                result[39:32] = stored_byte[0];
            end
            4'd6: begin
                result[7:0] = stored_byte[5];
                result[15:8] = stored_byte[4];
                result[23:16] = stored_byte[3];
                result[31:24] = stored_byte[2];
                result[39:32] = stored_byte[1];
                result[47:40] = stored_byte[0];
            end
            4'd7: begin
                result[7:0] = stored_byte[6];
                result[15:8] = stored_byte[5];
                result[23:16] = stored_byte[4];
                result[31:24] = stored_byte[3];
                result[39:32] = stored_byte[2];
                result[47:40] = stored_byte[1];
                result[55:48] = stored_byte[0];
            end
            4'd8, 4'd9, 4'd10, 4'd11, 4'd12, 4'd13, 4'd14, 4'd15: begin
                // k >= 8, reverse entire array
                result[7:0] = stored_byte[7];
                result[15:8] = stored_byte[6];
                result[23:16] = stored_byte[5];
                result[31:24] = stored_byte[4];
                result[39:32] = stored_byte[3];
                result[47:40] = stored_byte[2];
                result[55:48] = stored_byte[1];
                result[63:56] = stored_byte[0];
            end
            default: begin
                // Should not reach here, but handle gracefully
                result[7:0] = stored_byte[0];
                result[15:8] = stored_byte[1];
                result[23:16] = stored_byte[2];
                result[31:24] = stored_byte[3];
                result[39:32] = stored_byte[4];
                result[47:40] = stored_byte[5];
                result[55:48] = stored_byte[6];
                result[63:56] = stored_byte[7];
            end
        endcase
    end

endmodule