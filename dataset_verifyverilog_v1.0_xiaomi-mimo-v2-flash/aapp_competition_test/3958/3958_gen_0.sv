module ZebraPartition (
    input clk,
    input rst_n,
    input start,
    input char_in,
    input char_valid,
    input read_done,
    output reg ready,
    output reg done,
    output reg error,
    output reg [7:0] k_out,
    output reg [3:0] li_out,
    output reg [15:0] idx_out,
    output reg idx_valid,
    output reg subseq_done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INPUT_PHASE = 3'd1;
    localparam [2:0] VALIDATE = 3'd2;
    localparam [2:0] OUTPUT_INIT = 3'd3;
    localparam [2:0] OUTPUT_STREAM = 3'd4;
    localparam [2:0] OUTPUT_DONE = 3'd5;
    localparam [2:0] ERROR_STATE = 3'd6;
    
    // Internal storage: flat buffer for indices
    // Max 65536 chars * 2 bytes per index = 128KB
    // Using simplified storage for Icarus compatibility
    reg [15:0] index_buffer [0:65535];
    reg [15:0] buffer_ptr;
    
    // Track subsequence boundaries
    reg [15:0] subseq_start [0:255];
    reg [15:0] subseq_end [0:255];
    reg [7:0] subseq_count;
    reg [7:0] current_subseq;
    
    // Track pending '0' and '1' subsequences
    reg [7:0] pending_zero [0:255];  // indices of subsequences ending in 0
    reg [7:0] pending_one [0:255];   // indices of subsequences ending in 1
    reg [7:0] zero_count;
    reg [7:0] one_count;
    
    // State variables
    reg [2:0] state;
    reg [2:0] next_state;
    reg [15:0] char_index;
    reg [15:0] output_idx;
    reg [7:0] output_subseq_idx;
    reg [7:0] output_element_idx;
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Flags
    reg processing_valid;
    reg [7:0] temp_subseq_idx;
    reg [7:0] found_idx;
    integer i;
    
    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            ready <= 1'b1;
            done <= 1'b0;
            error <= 1'b0;
            buffer_ptr <= 16'd0;
            subseq_count <= 8'd0;
            current_subseq <= 8'd0;
            zero_count <= 8'd0;
            one_count <= 8'd0;
            char_index <= 16'd0;
            output_idx <= 16'd0;
            output_subseq_idx <= 8'd0;
            output_element_idx <= 8'd0;
            k_out <= 8'd0;
            li_out <= 4'd0;
            idx_out <= 16'd0;
            idx_valid <= 1'b0;
            subseq_done <= 1'b0;
            cycle_counter <= 8'd0;
            processing_valid <= 1'b0;
            
            // Initialize arrays
            for (i = 0; i < 256; i = i + 1) begin
                subseq_start[i] <= 16'd0;
                subseq_end[i] <= 16'd0;
                pending_zero[i] <= 8'd0;
                pending_one[i] <= 8'd0;
            end
            for (i = 0; i < 65536; i = i + 1) begin
                index_buffer[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    ready <= 1'b1;
                    done <= 1'b0;
                    error <= 1'b0;
                    idx_valid <= 1'b0;
                    subseq_done <= 1'b0;
                    cycle_counter <= 8'd0;
                    
                    if (start) begin
                        state <= INPUT_PHASE;
                        buffer_ptr <= 16'd0;
                        subseq_count <= 8'd0;
                        zero_count <= 8'd0;
                        one_count <= 8'd0;
                        char_index <= 16'd0;
                        processing_valid <= 1'b1;
                    end
                end
                
                INPUT_PHASE: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    
                    if (char_valid && processing_valid) begin
                        char_index <= char_index + 16'd1;
                        
                        if (char_in == 1'b0) begin
                            // Must extend subsequence ending in '0' or start new
                            if (zero_count > 8'd0) begin
                                // Extend existing subsequence ending in 0
                                // Get the subsequence index
                                temp_subseq_idx <= pending_zero[0];
                                
                                // Move it to pending_one (now ends in 1)
                                // Shift pending_zero array
                                for (i = 0; i < 255; i = i + 1) begin
                                    pending_zero[i] <= pending_zero[i + 1];
                                end
                                zero_count <= zero_count - 8'd1;
                                
                                // Add to pending_one
                                pending_one[one_count] <= pending_zero[0];
                                one_count <= one_count + 8'd1;
                                
                                // Store index
                                index_buffer[buffer_ptr] <= char_index;
                                buffer_ptr <= buffer_ptr + 16'd1;
                                
                                // Update subsequence end
                                subseq_end[pending_zero[0]] <= char_index;
                            end else begin
                                // Start new subsequence
                                if (subseq_count < 8'd256) begin
                                    subseq_start[subseq_count] <= char_index;
                                    subseq_end[subseq_count] <= char_index;
                                    index_buffer[buffer_ptr] <= char_index;
                                    buffer_ptr <= buffer_ptr + 16'd1;
                                    
                                    // Now ends in 1 (0 then 1 pattern start)
                                    pending_one[one_count] <= subseq_count;
                                    one_count <= one_count + 8'd1;
                                    
                                    subseq_count <= subseq_count + 8'd1;
                                end else begin
                                    error <= 1'b1;
                                    state <= ERROR_STATE;
                                end
                            end
                        end else begin
                            // char_in == 1
                            // Must extend subsequence ending in '0'
                            if (zero_count > 8'd0) begin
                                // Extend existing subsequence ending in 0
                                temp_subseq_idx <= pending_zero[0];
                                
                                // Move to pending_one
                                for (i = 0; i < 255; i = i + 1) begin
                                    pending_zero[i] <= pending_zero[i + 1];
                                end
                                zero_count <= zero_count - 8'd1;
                                
                                pending_one[one_count] <= pending_zero[0];
                                one_count <= one_count + 8'd1;
                                
                                index_buffer[buffer_ptr] <= char_index;
                                buffer_ptr <= buffer_ptr + 16'd1;
                                
                                subseq_end[pending_zero[0]] <= char_index;
                            end else begin
                                error <= 1'b1;
                                state <= ERROR_STATE;
                            end
                        end
                    end
                    
                    if (read_done) begin
                        if (processing_valid) begin
                            processing_valid <= 1'b0;
                            state <= VALIDATE;
                        end
                    end
                end
                
                VALIDATE: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    
                    // Check if any subsequence ends in '1' (waiting for '0')
                    if (one_count > 8'd0) begin
                        error <= 1'b1;
                        state <= ERROR_STATE;
                    end else begin
                        state <= OUTPUT_INIT;
                    end
                end
                
                OUTPUT_INIT: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    k_out <= subseq_count;
                    output_subseq_idx <= 8'd0;
                    state <= OUTPUT_STREAM;
                end
                
                OUTPUT_STREAM: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    idx_valid <= 1'b0;
                    subseq_done <= 1'b0;
                    
                    if (output_subseq_idx < subseq_count) begin
                        // Output current subsequence
                        if (output_element_idx == 8'd0) begin
                            // First element: output length
                            li_out <= subseq_end[output_subseq_idx] - subseq_start[output_subseq_idx] + 16'd1;
                            output_element_idx <= output_element_idx + 8'd1;
                        end else begin
                            // Output indices from buffer
                            idx_out <= index_buffer[output_idx];
                            idx_valid <= 1'b1;
                            output_idx <= output_idx + 16'd1;
                            output_element_idx <= output_element_idx + 8'd1;
                            
                            // Check if end of subsequence
                            if (index_buffer[output_idx] == subseq_end[output_subseq_idx]) begin
                                subseq_done <= 1'b1;
                                output_subseq_idx <= output_subseq_idx + 8'd1;
                                output_element_idx <= 8'd0;
                            end
                        end
                    end else begin
                        state <= OUTPUT_DONE;
                    end
                end
                
                OUTPUT_DONE: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                ERROR_STATE: begin
                    ready <= 1'b0;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Combinational logic for input handling
    always @(*) begin
        if (state == INPUT_PHASE && char_valid && processing_valid) begin
            ready = 1'b0;
        end else if (state == OUTPUT_STREAM || state == OUTPUT_INIT || state == OUTPUT_DONE) begin
            ready = 1'b0;
        end else begin
            ready = 1'b1;
        end
    end

endmodule