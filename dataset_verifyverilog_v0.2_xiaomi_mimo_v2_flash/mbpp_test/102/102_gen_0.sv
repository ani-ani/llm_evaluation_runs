module snake_to_camel(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input valid_in,
    output reg ready,
    output reg [7:0] char_out,
    output reg valid_out,
    output reg done
);

    // States
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state;
    reg [1:0] next_state;

    // Internal registers
    reg capitalize_next;      // Flag to capitalize the next letter
    reg prev_was_underscore;  // Tracks if previous char was underscore (part of logic)
    reg input_done;           // Flag that input stream has ended
    reg input_done_d;         // Delayed version for edge detection
    reg [3:0] out_count;      // Counter for output characters
    reg outputting;           // Internal flag that we are currently outputting a sequence

    // Output Buffer: We read one char at a time and potentially output 0 or 1 char
    // To handle the requirement of suppressing underscores, we need to buffer valid output
    // in case the next input char is an underscore (wait, the requirement says "multiple output chars may be produced per input char" is rare, 
    // but actually we consume one input at a time. If input is underscore, we output nothing. 
    // If input is letter, we output 1 char. The "multiple output chars" note in the prompt likely refers to edge cases or 
    // implies we might need to buffer. Let's stick to one output per input cycle usually.
    // HOWEVER, the requirement "Read characters sequentially" implies blocking handshake.
    // Let's use a small buffer to ensure ready isn't raised if we are still outputting.
    // Actually, standard streaming: consume -> process -> output.
    // We need to ensure we don't consume if the output FIFO (even if small) is full.
    // Let's assume we output immediately if valid, or discard if underscore.
    // To be safe and robust:
    // Let's implement a buffer for the output side.
    
    reg [7:0] out_buffer [0:1]; // 2 entry buffer to handle potential delays
    reg [1:0] out_wptr;
    reg [1:0] out_rptr;
    wire out_full = (out_wptr == 2'd2);
    wire out_empty = (out_wptr == out_rptr);
    wire [7:0] out_data_next;

    // Logic for output buffer
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_wptr <= 0;
            out_rptr <= 0;
        end else begin
            // Write logic
            if (state == PROCESSING && valid_in && ready) begin
                // We are consuming input. Determine if we write to buffer.
                // Logic: if char_in is underscore, do not write.
                // If char_in is lowercase and !capitalize_next, write lowercase.
                // If char_in is lowercase and capitalize_next, write uppercase.
                // If char_in is already uppercase, write as is (though the prompt implies mostly lowercase input).
                
                if (char_in != 8'h5F) begin // Not underscore
                    if (out_wptr != 2'd2) begin // Buffer not full
                        out_buffer[out_wptr] <= (capitalize_next && char_in >= 8'h61 && char_in <= 8'h7A) ? (char_in - 8'h20) : char_in;
                        out_wptr <= out_wptr + 1;
                    end
                end
            end
            
            // Read logic (Output Logic)
            if (valid_out) begin // If external consumer is ready (valid_out implies ready internal logic)
            // Wait, valid_out is just status. The consumer accepts when valid_out=1.
            // In this module, valid_out is high if buffer not empty.
            // We need to advance rptr when the outside world consumes it.
            // Since this is a self-contained module description, let's assume the 'valid_out' is the signal that tells the world data is there.
            // The prompt doesn't explicitly give an 'output_ready' from external world, so valid_out is essentially a status flag.
            // However, for a robust FIFO, we need to know when it's consumed.
            // Let's re-read: "valid_out means char_out contains valid output".
            // Usually implies a handshake. I will assume that valid_out=1 for one cycle when data is ready.
            // Since I am outputting to char_out, I need to manage the pointer.
            // Let's implement simple: if valid_out is high, we pop.
            // BUT, valid_out is output reg. We control it.
            // If valid_out is 1, and we don't have an external ready, it's a problem.
            // I will assume valid_out implies "I have data, here it is". 
            // Let's make valid_out a wire driven by !out_empty.
            // And char_out is driven by out_buffer[out_rptr].
            // And we advance out_rptr only if we are outputting (valid_out high) AND the system accepts it.
            // Since there is no external ready for output, I will consume from buffer to output register every cycle (blocking if buffer empty).
            // Actually, the standard way: valid_out=1 means data is on char_out. It stays until next cycle.
            // To avoid backpressure complexity without an output ready, I will assume single cycle transfer or simple flow.
            
            // Let's stick to a simpler synchronous output: 
            // We fill buffer. We drain buffer to char_out/valid_out.
            // valid_out will be 1 if buffer has data.
            // We increment read pointer every cycle that valid_out is high? No, that creates a streaming source.
            // The prompt asks for a valid_out signal. I will drive it.
            end
        end
    end

    // Rewriting the IO and Buffer logic cleanly:
    // Buffer: Writes happen when input is consumed and it's not an underscore.
    // Reads happen to present data on output. Since there's no output_ready, we present one char per cycle if available.
    // To be safe, let's use a valid_out register that is high if buffer is not empty.
    // The char_out will be the head of the buffer.

    // -- Corrected Buffer Logic --
    reg [7:0] out_fifo [0:1];
    reg [1:0] wptr, rptr;
    wire fifo_full = (wptr == 2'd2);
    wire fifo_empty = (rptr == wptr);

    // Pointer updates
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wptr <= 0;
            rptr <= 0;
        end else begin
            // Write to FIFO
            if (state == PROCESSING && valid_in && ready) begin
                // Determine if we need to write
                if (char_in != 8'h5F) begin // Not underscore
                    if (!fifo_full) begin
                        // Logic for transformation
                        if (capitalize_next && char_in >= 8'h61 && char_in <= 8'h7A) begin
                            out_fifo[wptr] <= char_in - 8'h20;
                        end else begin
                            out_fifo[wptr] <= char_in;
                        end
                        wptr <= wptr + 1;
                    end
                end
            end

            // Read from FIFO (Consume to Output)
            // We want to output data. If fifo not empty, we output.
            // If we output, we advance rptr.
            // This is a "streaming" output. One char per cycle if available.
            // The prompt doesn't have an output ready, so we just output.
            if (!fifo_empty) begin
                rptr <= rptr + 1;
            end
        end
    end

    // Output assignments
    always @(*) begin
        if (!fifo_empty) begin
            char_out = out_fifo[rptr];
            valid_out = 1'b1;
        end else begin
            char_out = 8'h00;
            valid_out = 1'b0;
        end
    end

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state; // Default
        case (state)
            IDLE: begin
                if (start) next_state = PROCESSING;
            end
            PROCESSING: begin
                // End of input detection
                // We need to stop when input is done AND buffer is empty
                // Input is done if we see valid_in low for 2 cycles? 
                // The prompt says: "When input ends (no more valid_in for 2 cycles), enter DONE".
                // This requires a counter for "no valid_in".
                // However, if we assume standard streaming, we know when we are done.
                // Let's assume the controller feeds data continuously until done.
                // The detection logic is outside the FSM usually, or we track it.
                // Let's implement the "2 cycles" requirement in the FSM control logic.
                
                // If we have consumed all input AND buffer is empty -> DONE
                // Since we don't have an "End of Stream" signal explicitly, we rely on the input logic.
                // The prompt says "process input characters one at a time".
                // Let's define the termination condition:
                // If input_done flag is set and buffer empty -> DONE
                if (input_done && fifo_empty) next_state = DONE;
            end
            DONE: begin
                // Wait for reset or new start
                // If start comes, go to IDLE? Or PROCESSING? Prompt says "Wait for reset or new start".
                // Usually implies stay in DONE until reset.
                if (start) next_state = IDLE; // Reset needed to restart cleanly usually
            end
        endcase
    end

    // Input Validity Counter (for "no valid_in for 2 cycles")
    reg [1:0] no_input_cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            no_input_cnt <= 0;
            input_done <= 0;
        end else begin
            if (state != PROCESSING) begin
                no_input_cnt <= 0;
                input_done <= 0;
            end else begin
                if (valid_in) begin
                    no_input_cnt <= 0;
                    input_done <= 0; // Reset done flag if new input arrives
                end else begin
                    if (no_input_cnt < 2'd3) no_input_cnt <= no_input_cnt + 1;
                    if (no_input_cnt == 2'd1) input_done <= 1'b1; // High after 2 cycles of low valid_in
                end
            end
        end
    end

    // Capitalize Flag Logic
    // Needs to be high if: 1. Start just asserted. 2. Previous char was underscore. 3. Previous char was outputted (not suppressed).
    // Since we skip underscores, we need to track the state of the previous *consumed* character.
    // If previous input was '_', flag stays true.
    // If previous input was a letter, flag becomes false (unless it was capitalized, but that doesn't matter, next is lower).
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            capitalize_next <= 1'b0;
        end else begin
            if (state == IDLE && start) begin
                capitalize_next <= 1'b1; // Start of string
            end else if (state == PROCESSING && valid_in && ready) begin
                if (char_in == 8'h5F) begin // Underscore
                    capitalize_next <= 1'b1; // Next should be capitalized
                end else begin
                    capitalize_next <= 1'b0; // Next should be normal (unless another underscore comes later)
                end
            end
        end
    end

    // Ready Logic
    // Ready is high if we are in PROCESSING and output buffer is not full
    always @(*) begin
        if (state == PROCESSING && !fifo_full) begin
            ready = 1'b1;
        end else begin
            ready = 1'b0;
        end
    end

    // Done Logic
    // Done is high in DONE state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) done <= 0;
        else if (state == DONE) done <= 1;
        else done <= 0;
    end

endmodule
