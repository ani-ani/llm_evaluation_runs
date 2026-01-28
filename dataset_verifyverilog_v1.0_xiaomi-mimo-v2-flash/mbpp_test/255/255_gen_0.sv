module CombinationGenerator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    output reg done,
    output reg out_valid,
    output reg [7:0] out_array [0:9],
    output reg [3:0] out_count
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] INIT       = 3'd1;
    localparam [2:0] GENERATE   = 3'd2;
    localparam [2:0] OUTPUT     = 3'd3;
    localparam [2:0] FINISHED   = 3'd4;

    reg [2:0] state, next_state;
    reg [3:0] max_idx; // Maximum index for each element (0, 1, or 2)
    reg [3:0] idx0, idx1, idx2; // Indices for current sequence
    reg [3:0] combo_count; // Count of generated combinations
    reg [2:0] output_idx; // Index for output array
    reg [3:0] cycle_counter; // Prevent infinite loops
    localparam [3:0] MAX_CYCLES = 4'd100;
    reg valid_generated; // Flag to indicate if valid sequence was found
    reg start_prev; // To detect rising edge of start

    integer i;

    // State transition and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            out_valid <= 1'b0;
            out_count <= 4'd0;
            for (i = 0; i < 10; i = i + 1) begin
                out_array[i] <= 8'd0;
            end
            max_idx <= 4'd0;
            idx0 <= 4'd0;
            idx1 <= 4'd0;
            idx2 <= 4'd0;
            combo_count <= 4'd0;
            output_idx <= 3'd0;
            cycle_counter <= 4'd0;
            valid_generated <= 1'b0;
            start_prev <= 1'b0;
        end else begin
            start_prev <= start;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    out_valid <= 1'b0;
                    out_count <= 4'd0;
                    cycle_counter <= 4'd0;
                    valid_generated <= 1'b0;
                    if (start && !start_prev && (n >= 4'd1 && n <= 4'd3)) begin
                        state <= INIT;
                    end else begin
                        state <= IDLE;
                    end
                end

                INIT: begin
                    // Initialize indices and counter
                    max_idx <= n; // Max index is n-1 (e.g., for n=2, indices can be 0 or 1)
                    idx0 <= 4'd0;
                    idx1 <= 4'd0;
                    idx2 <= 4'd0;
                    combo_count <= 4'd0;
                    output_idx <= 3'd0;
                    cycle_counter <= 4'd0;
                    state <= GENERATE;
                end

                GENERATE: begin
                    cycle_counter <= cycle_counter + 4'd1;
                    
                    // Check if current indices form a valid non-decreasing sequence
                    if (n == 3'd1) begin
                        // Single element, always valid
                        if (idx0 < max_idx) begin
                            // Increment for next
                            idx0 <= idx0 + 4'd1;
                        end else begin
                            // Done with all combinations
                            state <= OUTPUT;
                        end
                    end else if (n == 3'd2) begin
                        // Two elements, check if idx0 <= idx1
                        if (idx0 <= idx1) begin
                            // Valid, generate and check next
                            combo_count <= combo_count + 4'd1;
                            // Increment indices
                            if (idx1 < max_idx) begin
                                idx1 <= idx1 + 4'd1;
                            end else if (idx0 < max_idx) begin
                                idx0 <= idx0 + 4'd1;
                                idx1 <= idx0 + 4'd1; // Reset idx1 to maintain non-decreasing
                            end else begin
                                state <= OUTPUT;
                            end
                        end else begin
                            // Invalid, move to next
                            if (idx1 < max_idx) begin
                                idx1 <= idx1 + 4'd1;
                            end else if (idx0 < max_idx) begin
                                idx0 <= idx0 + 4'd1;
                                idx1 <= idx0 + 4'd1;
                            end else begin
                                state <= OUTPUT;
                            end
                        end
                    end else if (n == 3'd3) begin
                        // Three elements, check non-decreasing
                        if (idx0 <= idx1 && idx1 <= idx2) begin
                            combo_count <= combo_count + 4'd1;
                            // Increment indices
                            if (idx2 < max_idx) begin
                                idx2 <= idx2 + 4'd1;
                            end else if (idx1 < max_idx) begin
                                idx1 <= idx1 + 4'd1;
                                idx2 <= idx1 + 4'd1;
                            end else if (idx0 < max_idx) begin
                                idx0 <= idx0 + 4'd1;
                                idx1 <= idx0 + 4'd1;
                                idx2 <= idx0 + 4'd2;
                            end else begin
                                state <= OUTPUT;
                            end
                        end else begin
                            // Invalid, move to next
                            if (idx2 < max_idx) begin
                                idx2 <= idx2 + 4'd1;
                            end else if (idx1 < max_idx) begin
                                idx1 <= idx1 + 4'd1;
                                idx2 <= idx1 + 4'd1;
                            end else if (idx0 < max_idx) begin
                                idx0 <= idx0 + 4'd1;
                                idx1 <= idx0 + 4'd1;
                                idx2 <= idx0 + 4'd2;
                            end else begin
                                state <= OUTPUT;
                            end
                        end
                    end

                    // Safety timeout
                    if (cycle_counter >= MAX_CYCLES) begin
                        state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    // Output valid combinations into out_array
                    // We need to regenerate combinations based on counts or store them
                    // Simplified: Use the same logic to regenerate and output
                    // Since we don't store, we'll output as we generate again
                    // We can reuse the idx values from the end of GENERATE, but they are at max
                    // Instead, let's reinitialize and generate again to fill out_array
                    // Or, better: In GENERATE, we can directly assign to out_array on valid hit
                    // Let's modify GENERATE to handle output storage.
                    // Actually, this state will just finalize.
                    out_count <= combo_count;
                    out_valid <= 1'b1;
                    state <= FINISHED;
                end

                FINISHED: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Combinational logic for output generation
    // We need to generate the packed 8-bit values
    // Since GENERATE logic is complex, we'll add a parallel combinational block
    // to fill out_array whenever indices change.
    always @(*) begin
        // Default values
        if (state == GENERATE) begin
            // Check validity for current indices and pack
            if (n == 3'd1) begin
                // Single element
                if (idx0 <= 2'd2 && idx0 < max_idx) begin
                    out_array[0] = {6'd0, idx0[1:0]};
                end
            end else if (n == 3'd2) begin
                // Two elements
                if (idx0 <= idx1 && idx1 <= 2'd2 && idx1 < max_idx && idx0 < max_idx) begin
                    out_array[0] = {4'd0, idx1[1:0], idx0[1:0]};
                end
            end else if (n == 3'd3) begin
                // Three elements
                if (idx0 <= idx1 && idx1 <= idx2 && idx2 <= 2'd2 && idx2 < max_idx && idx1 < max_idx && idx0 < max_idx) begin
                    out_array[0] = {idx2[1:0], idx1[1:0], idx0[1:0]};
                end
            end
        end
    end

    // To properly store sequences in the output array, we need to detect the moment a valid sequence is found
    // and increment a write pointer. This requires storing the current write index separately.
    // Since we cannot store dynamically in Verilog without a separate register, we will use a separate logic.
    reg [3:0] write_idx;
    reg [2:0] last_idx0, last_idx1, last_idx2;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_idx <= 4'd0;
            // Reset out_array content
            for (i = 0; i < 10; i = i + 1) begin
                out_array[i] <= 8'd0;
            end
        end else begin
            if (state == IDLE) begin
                write_idx <= 4'd0;
                // Clear array on reset/start
                for (i = 0; i < 10; i = i + 1) begin
                    out_array[i] <= 8'd0;
                end
            end else if (state == GENERATE) begin
                // Detect valid sequence and write to array
                // We need to detect a transition to a new valid state
                // Compare current indices with previous cycle
                // But we need to store the previous values. 
                // Actually, we can just write on every valid check in GENERATE, 
                // but we must ensure we only write once per unique combination.
                // The GENERATE loop increments indices after writing or checking.
                // So we write when the condition is met.
                if (n == 3'd1) begin
                     if (idx0 < max_idx && idx0 > last_idx0) begin
                         out_array[write_idx] <= {6'd0, idx0[1:0]};
                         write_idx <= write_idx + 4'd1;
                         last_idx0 <= idx0;
                     end
                end else if (n == 3'd2) begin
                     // Check if current state is valid and different from last written
                     if (idx0 <= idx1 && idx1 < max_idx && idx0 < max_idx) begin
                         if (idx0 != last_idx0 || idx1 != last_idx1) begin
                            out_array[write_idx] <= {4'd0, idx1[1:0], idx0[1:0]};
                            write_idx <= write_idx + 4'd1;
                            last_idx0 <= idx0;
                            last_idx1 <= idx1;
                         end
                     end
                end else if (n == 3'd3) begin
                     if (idx0 <= idx1 && idx1 <= idx2 && idx2 < max_idx && idx1 < max_idx && idx0 < max_idx) begin
                         if (idx0 != last_idx0 || idx1 != last_idx1 || idx2 != last_idx2) begin
                            out_array[write_idx] <= {idx2[1:0], idx1[1:0], idx0[1:0]};
                            write_idx <= write_idx + 4'd1;
                            last_idx0 <= idx0;
                            last_idx1 <= idx1;
                            last_idx2 <= idx2;
                         end
                     end
                end
            end
        end
    end

endmodule