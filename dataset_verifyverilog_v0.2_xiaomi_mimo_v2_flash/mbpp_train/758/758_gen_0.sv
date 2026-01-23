module sublist_histogram(
    input clk,
    input rst_n,
    input start,
    input [2:0] num_sublists,
    input [2:0] sublist_lengths [0:7],
    input [7:0] sublists [0:7][0:7],
    output reg [2:0] output_index,
    output reg [7:0] unique_list [0:7],
    output reg [2:0] list_length,
    output reg [7:0] count,
    output reg output_valid,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam PROCESS = 3'b010;
    localparam OUTPUT = 3'b011;
    localparam DONE = 3'b100;

    // Internal registers and arrays
    reg [2:0] state;
    reg [2:0] current_sublist_idx; // Index of sublist being processed
    reg [2:0] unique_count; // Number of unique sublists found
    
    // Storage for unique sublists
    reg [7:0] unique_data [0:7][0:7];
    reg [2:0] unique_lengths [0:7];
    reg [7:0] unique_counts [0:7];
    
    // Temporary storage for matching
    reg match_found;
    reg [2:0] match_idx;
    reg [2:0] elem_idx;
    
    // Output state
    reg [2:0] output_ptr;
    
    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            output_index <= 0;
            list_length <= 0;
            count <= 0;
            output_valid <= 0;
            done <= 0;
            current_sublist_idx <= 0;
            unique_count <= 0;
            output_ptr <= 0;
            match_found <= 0;
            match_idx <= 0;
            elem_idx <= 0;
            // Reset unique arrays
            for (i = 0; i < 8; i = i + 1) begin
                unique_lengths[i] <= 0;
                unique_counts[i] <= 0;
                for (j = 0; j < 8; j = j + 1) begin
                    unique_data[i][j] <= 8'b0;
                end
            end
            // Reset output array
            for (i = 0; i < 8; i = i + 1) begin
                unique_list[i] <= 8'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    output_valid <= 0;
                    done <= 0;
                    if (start) begin
                        state <= LOAD;
                        current_sublist_idx <= 0;
                        unique_count <= 0;
                        // Reset storage
                        for (i = 0; i < 8; i = i + 1) begin
                            unique_lengths[i] <= 0;
                            unique_counts[i] <= 0;
                            for (j = 0; j < 8; j = j + 1) begin
                                unique_data[i][j] <= 8'b0;
                            end
                        end
                    end
                end

                LOAD: begin
                    // Process current sublist
                    if (current_sublist_idx < num_sublists) begin
                        // Check against existing unique sublists
                        if (unique_count == 0) begin
                            // First sublist, add it
                            unique_count <= 1;
                            unique_lengths[0] <= sublist_lengths[current_sublist_idx];
                            unique_counts[0] <= 1;
                            for (j = 0; j < 8; j = j + 1) begin
                                unique_data[0][j] <= sublists[current_sublist_idx][j];
                            end
                            current_sublist_idx <= current_sublist_idx + 1;
                        end else begin
                            // Need to compare
                            state <= PROCESS;
                            match_found <= 0;
                            match_idx <= 0;
                            elem_idx <= 0;
                        end
                    end else begin
                        // Done loading, move to output
                        state <= OUTPUT;
                        output_ptr <= 0;
                    end
                end

                PROCESS: begin
                    // Compare current sublist (sublists[current_sublist_idx]) with unique_data[match_idx]
                    if (match_idx < unique_count) begin
                        if (elem_idx < 8) begin
                            // Check if we are within valid lengths
                            if (elem_idx < sublist_lengths[current_sublist_idx] && 
                                elem_idx < unique_lengths[match_idx]) begin
                                if (sublists[current_sublist_idx][elem_idx] != unique_data[match_idx][elem_idx]) begin
                                    // Mismatch, move to next unique list
                                    match_idx <= match_idx + 1;
                                    elem_idx <= 0;
                                end else begin
                                    elem_idx <= elem_idx + 1;
                                end
                            end else begin
                                // Reached end of at least one list
                                if (elem_idx >= sublist_lengths[current_sublist_idx] && 
                                    elem_idx >= unique_lengths[match_idx]) begin
                                    // Both ended at same length - Full Match
                                    match_found <= 1;
                                    state <= LOAD;
                                    // Increment count
                                    unique_counts[match_idx] <= unique_counts[match_idx] + 1;
                                    current_sublist_idx <= current_sublist_idx + 1;
                                end else begin
                                    // Length mismatch, not a match
                                    match_idx <= match_idx + 1;
                                    elem_idx <= 0;
                                end
                            end
                        end else begin
                            // elem_idx reached 8
                            if (sublist_lengths[current_sublist_idx] <= 8 && unique_lengths[match_idx] <= 8) begin
                                // Full match (if lengths were 8 or less)
                                // Actually if we looped 0-7 without mismatch, and lengths are same
                                if (sublist_lengths[current_sublist_idx] == unique_lengths[match_idx]) begin
                                    match_found <= 1;
                                    state <= LOAD;
                                    unique_counts[match_idx] <= unique_counts[match_idx] + 1;
                                    current_sublist_idx <= current_sublist_idx + 1;
                                end else begin
                                    // Should not happen if logic handles lengths correctly, but reset to next
                                    match_idx <= match_idx + 1;
                                    elem_idx <= 0;
                                end
                            end else begin
                                match_idx <= match_idx + 1;
                                elem_idx <= 0;
                            end
                        end
                    end else begin
                        // No match found in existing unique lists
                        if (unique_count < 8) begin
                            // Add as new unique sublist
                            unique_count <= unique_count + 1;
                            unique_lengths[unique_count] <= sublist_lengths[current_sublist_idx];
                            unique_counts[unique_count] <= 1;
                            for (j = 0; j < 8; j = j + 1) begin
                                unique_data[unique_count][j] <= sublists[current_sublist_idx][j];
                            end
                        end
                        state <= LOAD;
                        current_sublist_idx <= current_sublist_idx + 1;
                    end
                end

                OUTPUT: begin
                    if (output_ptr < unique_count) begin
                        output_valid <= 1;
                        output_index <= output_ptr;
                        list_length <= unique_lengths[output_ptr];
                        count <= unique_counts[output_ptr];
                        // Pad with zeros if needed (storage is already 0 padded)
                        for (i = 0; i < 8; i = i + 1) begin
                            unique_list[i] <= unique_data[output_ptr][i];
                        end
                        output_ptr <= output_ptr + 1;
                    end else begin
                        output_valid <= 0;
                        done <= 1;
                        state <= DONE;
                    end
                end

                DONE: begin
                    // Stay here until reset or start
                    done <= 1;
                    if (start) begin
                        // Restart if requested (needs start to go low first)
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
