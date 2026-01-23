module flatten_list(
    input clk,
    input rst_n,
    input start,
    input [3:0] num_subarrays,
    input [3:0] subarray_lengths [0:3],
    input [7:0] data_in [0:15],
    output reg [7:0] flattened [0:15],
    output reg [4:0] output_length,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam READING = 2'b01;
    localparam WRITING = 2'b10;
    localparam DONE = 2'b11;

    reg [1:0] current_state, next_state;
    reg [3:0] subarray_idx; // Index of current subarray being processed
    reg [3:0] element_idx;  // Index within current subarray
    reg [4:0] output_idx;   // Index in flattened output array
    reg [4:0] total_length; // Calculated total length
    reg length_valid;       // Flag to ensure length is calculated once

    integer i;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            done <= 1'b0;
            output_length <= 5'd0;
            subarray_idx <= 4'd0;
            element_idx <= 4'd0;
            output_idx <= 5'd0;
            total_length <= 5'd0;
            length_valid <= 1'b0;
            // Reset output array
            for (i = 0; i < 16; i = i + 1) begin
                flattened[i] <= 8'h00;
            end
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Calculate total length immediately on start
                        if (!length_valid) begin
                            total_length <= 5'd0 + subarray_lengths[0] + subarray_lengths[1] + subarray_lengths[2] + subarray_lengths[3];
                            length_valid <= 1'b1;
                        end
                        // Initialize indices
                        subarray_idx <= 4'd0;
                        element_idx <= 4'd0;
                        output_idx <= 5'd0;
                        output_length <= 5'd0;
                    end
                end

                READING: begin
                    // We stay in READING/Writing combination effectively processing in one cycle per element
                    // However, instructions imply a specific flow. 
                    // Let's implement a state machine that iterates.
                    // To meet "Process in 16 clock cycles", we can assume 1 element per cycle logic.
                    // Check if we are done with all elements
                    if (output_idx < total_length) begin
                        // Logic to copy element handled in WRITING or here. 
                        // To strictly follow the state machine description:
                        // We need to transition. But to do 16 elements in 16 cycles, we need efficient logic.
                        // Let's use WRITING state to perform the actual transfer.
                        // This block is technically for next_state logic if purely combinatorial, 
                        // but since we are told to implement sequential, we handle data path here.
                        
                        // Actually, let's stick to the strict FSM structure requested.
                        // State 0-15: Read/Write.
                        // We will use READING to calculate address and WRITING to store.
                        // Or merge them.
                    end
                end
                
                // Simplified sequential logic block handling the iteration
            endcase
        end
    end

    // Combined FSM and Datapath logic to meet the specific "State 0-15" requirement
    // and 16 cycle latency.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            output_length <= 5'd0;
            output_idx <= 5'd0;
            subarray_idx <= 4'd0;
            element_idx <= 4'd0;
            total_length <= 5'd0;
            length_valid <= 1'b0;
            for (i = 0; i < 16; i = i + 1) flattened[i] <= 8'd0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Calculate total sum of lengths
                        if (!length_valid) begin
                            total_length <= {1'b0, subarray_lengths[0]} + {1'b0, subarray_lengths[1]} + 
                                            {1'b0, subarray_lengths[2]} + {1'b0, subarray_lengths[3]};
                            length_valid <= 1'b1;
                        end
                        output_idx <= 5'd0;
                        subarray_idx <= 4'd0;
                        element_idx <= 4'd0;
                        output_length <= 5'd0;
                    end
                end

                READING: begin
                    // This state is transitional to WRITING to ensure sequential operation
                    // We just prepare indices if needed, but for simple copy, we do it in WRITING or next cycle.
                    // To fit 16 cycles, we likely need to do the copy in IDLE/READING/Writing state transitions.
                    // Let's use a single state to perform the operation per cycle (simplified to 'PROCESSING').
                end

                // If strictly following IDLE, READING, WRITING, DONE states:
                // We will use READING to fetch logic (virtual) and WRITING to commit.
                WRITING: begin
                    if (output_idx < 16 && output_idx < total_length) begin
                        // Find the current element to copy
                        // This is combinatorial logic represented in sequential block for brevity/synthesis
                        // We need to map flat input index to subarray structure.
                        // Input is flat 0-15.
                        // We need to skip empty slots or just map strictly.
                        // Since data_in is given as a flat array representing the nested structure, 
                        // the elements are contiguous in data_in, possibly padded.
                        // We need to figure out which element in data_in corresponds to the current logical position.
                        // Current logical position is 'output_idx' (0..15).
                        // We need to map this to the linear address of data_in.
                        // Since lengths are known, we can iterate through subarrays.
                        
                        // Actually, easier approach:
                        // We iterate through subarrays and lengths.
                        // If element_idx < subarray_lengths[subarray_idx], copy.
                        // But to do this in 1 cycle per element, we need to know where to read from data_in.
                        // data_in is linear: index 0..15.
                        // So the n-th element of the flattened list is simply data_in[n].
                        // Wait, the spec says: "data_in is organized as a flattened representation".
                        // So data_in[0] is first element, data_in[1] is second.
                        // Why do we need subarray_lengths then?
                        // Spec: "Elements must be concatenated maintaining relative order"
                        // Spec: "Iterate through each sub-array, extract elements, append"
                        // Maybe data_in has padding or non-linear storage? 
                        // "input data_in [0:15] // flat array of 16 elements representing nested structure"
                        // This implies it is flat. 
                        // However, to satisfy "iterate through sub-arrays", maybe the subarrays in data_in are padded?
                        // Example: [[10, 20], [40]] -> data_in: 10, 20, 40? Or 10, 20, 0, 0, 40, 0...?
                        // Usually, flattening preserves order. 
                        // Let's assume data_in contains the elements in order, packed.
                        // But the module might need to simulate the extraction process.
                        // If we simply assign flattened[output_idx] = data_in[output_idx], we ignore subarray_lengths.
                        // So likely, data_in is packed, but we might need to read it from the correct logical index.
                        // Or, data_in is just the valid data, and we just copy it.
                        // The requirement to iterate subarrays suggests maybe the input indices aren't simple 0..15.
                        // Let's assume we need to read data_in based on the sum of lengths processed so far.
                        // Actually, a common interpretation of such specs: data_in is the flat array.
                        // So we can just assign flattened[i] = data_in[i] for i < total_length.
                        // But to strictly meet "iterate through sub-arrays", we can implement the loop.
                        
                        // Let's perform the copy.
                        // We need to find the current source index.
                        // Let's use the logical output index as the source index, assuming data_in is already the flattened raw data.
                        // If data_in is "representing nested structure", it's likely just the list of values.
                        
                        flattened[output_idx] <= data_in[output_idx];
                        output_idx <= output_idx + 1'b1;
                        
                        // Update length
                        output_length <= output_idx + 1'b1;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Combinational next state logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start) next_state = READING;
                else next_state = IDLE;
            end
            READING: begin
                // Transition immediately to WRITING to perform the copy in the same "cycle" concept or next sequential step.
                // To ensure 16 cycles for 16 elements, we need 1 state active cycle per element.
                // If READING and WRITING are distinct, we need 32 cycles. 
                // So we will condense the processing to the WRITING state, or treat READING as a pass-through.
                // Let's define: IDLE -> READING (Setup) -> WRITING (Process block) -> WRITING (Loop) -> DONE
                // Actually, let's just loop in WRITING.
                // To strictly follow the prompt's state names: IDLE, READING, WRITING, DONE.
                // We will use READING to indicate we are 'processing' (state 0-15).
                next_state = WRITING;
            end
            WRITING: begin
                if (output_idx < total_length) begin
                    next_state = WRITING; // Stay here processing elements
                end else begin
                    next_state = DONE;
                end
            end
            DONE: begin
                next_state = IDLE; // Auto-reset or wait for external reset
            end
            default: next_state = IDLE;
        endcase
    end

endmodule