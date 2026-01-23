module stack_game (
    input clk,
    input rst_n,
    input start,
    input [2:0] op_code,
    input [3:0] v,
    input [3:0] w,
    input [7:0] data_in,
    output reg [7:0] result,
    output reg result_valid,
    output reg [3:0] debug_stack_count
);

    // Stack Storage: 16 stacks, 16 elements deep each
    reg [7:0] stacks [0:15][0:15];
    // Stack Depth Trackers
    reg [3:0] depths [0:15];
    // Valid Stack Mask
    reg [15:0] valid_stacks;
    // Current step index (i)
    reg [3:0] i;

    // State definitions
    localparam IDLE = 3'b000;
    localparam PROCESSING = 3'b001;
    localparam POP_DONE = 3'b010;
    localparam INTERSECT_ACCUM = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state;
    reg [2:0] next_state;

    // Operation codes
    localparam OP_NONE = 3'b000;
    localparam OP_PUSH = 3'b001;
    localparam OP_POP = 3'b010;
    localparam OP_INTERSECT = 3'b011;

    // Intersection specific registers
    reg [3:0] intersect_idx_i; // Index for element in stack 'i'
    reg [7:0] intersect_count;
    reg [7:0] current_element_i;
    reg found_match;
    integer k;

    // Temporary storage for copy operation
    reg [7:0] temp_stack_data [0:15];
    reg [3:0] temp_depth;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset: Initialize all stacks as empty, valid_stacks = 0
            integer s, d;
            for (s = 0; s < 16; s = s + 1) begin
                depths[s] <= 4'b0000;
                for (d = 0; d < 16; d = d + 1) begin
                    stacks[s][d] <= 8'b00000000;
                end
            end
            valid_stacks <= 16'b0000000000000000;
            i <= 4'b0001; // Start step index from 1
            state <= IDLE;
            result <= 8'b00000000;
            result_valid <= 1'b0;
            debug_stack_count <= 4'b0000;
            intersect_idx_i <= 4'b0000;
            intersect_count <= 8'b00000000;
        end else begin
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    if (start) begin
                        if (op_code == OP_PUSH || op_code == OP_POP) begin
                            state <= PROCESSING;
                        end else if (op_code == OP_INTERSECT) begin
                            state <= INTERSECT_ACCUM;
                            intersect_idx_i <= 4'b0000;
                            intersect_count <= 8'b00000000;
                            // Fetch current element for first cycle comparison
                            if (depths[v] > 0) begin
                                current_element_i <= stacks[v][0];
                            end else begin
                                current_element_i <= 8'b00000000; // Should result in 0 count
                            end
                        end else begin
                            // Op none or invalid, just finish immediately
                            state <= DONE;
                            result <= 8'b00000000; // Don't care for none
                        end
                    end
                end

                POP_DONE: begin
                    // Wait state for transition if needed, or jump straight to DONE
                    state <= DONE;
                end

                INTERSECT_ACCUM: begin
                    // 16 cycle counter logic is implicitly handled by state transitions
                    // Compare current_element_i with all elements in stack w
                    found_match = 1'b0;
                    if (depths[w] > 0) begin
                        for (k = 0; k < 16; k = k + 1) begin
                            if (k < depths[w]) begin
                                if (stacks[w][k] == current_element_i) begin
                                    found_match = 1'b1;
                                end
                            end
                        end
                    end
                    
                    if (found_match) begin
                        intersect_count <= intersect_count + 1;
                    end

                    // Prepare next element
                    intersect_idx_i <= intersect_idx_i + 1;
                    
                    // If we have processed all elements in v OR processed 16 cycles
                    // Since v is the source of the new stack (copy of v), we iterate up to depth of v
                    // The problem says "16 cycles to scan all elements". Let's iterate 16 times to be safe/consistent with "scan all elements"
                    // However, logically we should only scan valid elements of the new stack.
                    // The new stack is a copy of 'v'.
                    if (intersect_idx_i == 4'b1111) begin
                        // 16 cycles done (indices 0-15)
                        state <= DONE;
                        result <= intersect_count;
                        result_valid <= 1'b1;
                        // Increment step index i
                        i <= i + 1;
                        // Update valid stacks mask (new stack i is created)
                        if (i < 16) valid_stacks[i] <= 1'b1;
                        // Update debug count
                        debug_stack_count <= i;
                    end else begin
                        // Load next element for next cycle comparison
                        if (intersect_idx_i + 1 < depths[v]) begin
                             current_element_i <= stacks[v][intersect_idx_i + 1];
                        end else begin
                             current_element_i <= 8'b00000000; // Pad with zeros if depth exceeded
                        end
                    end
                end

                PROCESSING: begin
                    // Handle Push and Pop (Latency 1 cycle)
                    // First, perform the copy of stack 'v' to stack 'i' (new stack)
                    // This logic assumes we process the copy in this single cycle block
                    // We need to read from stacks[v] and write to stacks[i]
                    // Since this is single cycle logic, we perform the write here.

                    if (op_code == OP_PUSH) begin
                        // Copy stack v to stack i
                        if (depths[v] > 0) begin
                            for (int idx = 0; idx < 16; idx++) begin
                                if (idx < depths[v]) begin
                                    stacks[i][idx] <= stacks[v][idx];
                                end else begin
                                    stacks[i][idx] <= 8'b00000000;
                                end
                            end
                        end
                        depths[i] <= depths[v];
                        
                        // Push data_in
                        if (depths[v] < 16) begin
                            stacks[i][depths[v]] <= data_in;
                            depths[i] <= depths[v] + 1;
                        end
                        // Note: if full, we just copy and don't push? Or overwrite?
                        // "Standard stack behavior" usually implies push increases depth.
                        // If full (16 elements), we might ignore push or wrap. Let's stick to the copy.
                        
                        // Update valid mask and index
                        if (i < 16) valid_stacks[i] <= 1'b1;
                        i <= i + 1;
                        debug_stack_count <= i;
                        
                        // Result
                        result <= 8'b00000000; // Don't care, specified 0
                        result_valid <= 1'b1;
                        state <= DONE;

                    end else if (op_code == OP_POP) begin
                        // Copy stack v to stack i
                        if (depths[v] > 0) begin
                            for (int idx = 0; idx < 16; idx++) begin
                                if (idx < depths[v]) begin
                                    stacks[i][idx] <= stacks[v][idx];
                                end else begin
                                    stacks[i][idx] <= 8'b00000000;
                                end
                            end
                        end
                        
                        // Pop logic (decrement depth, output top element)
                        // Note: In Verilog, reading from regs that are being written in same block is tricky (simulation vs synthesis).
                        // Here we are writing to stacks[i] and reading from stacks[v]. That is fine.
                        // We need to output the element being popped.
                        
                        if (depths[v] > 0) begin
                            result <= stacks[v][depths[v] - 1];
                            depths[i] <= depths[v] - 1;
                        end else begin
                            result <= 8'b00000000; // Pop empty stack
                            depths[i] <= 4'b0000;
                        end
                        
                        // Update valid mask and index
                        if (i < 16) valid_stacks[i] <= 1'b1;
                        i <= i + 1;
                        debug_stack_count <= i;
                        
                        result_valid <= 1'b1;
                        state <= DONE;
                    end else begin
                        // Should not happen if state transition logic is correct
                        state <= DONE;
                    end
                end

                DONE: begin
                    // Wait for start to go low? Or just stay high until next start?
                    // "result_valid high when result is valid".
                    // Typically we de-assert valid when ready for new command.
                    // If we stay in DONE, result is valid. When start goes high for next op, we transition.
                    if (!start) begin
                         // Handshake: start must go low before next command is accepted?
                         // The prompt says "Wait for start signal" in IDLE.
                         // So we likely need to go to IDLE or stay in DONE until start is low.
                         // Let's transition to IDLE when start goes low to be ready for next.
                         state <= IDLE;
                    end
                    // Keep result_valid high while in DONE, de-assert in IDLE logic
                    result_valid <= 1'b1; 
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule

module TopModule(output out);
  assign out = 1'b0;
endmodule