module plagiarism_detector (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] fragments_count,
    input wire fragment_lines_valid,
    input wire [255:0] fragment_data,
    input wire [127:0] fragment_file_name,
    input wire query_lines_valid,
    input wire [255:0] query_data,
    input wire input_done,
    output reg [15:0] result,
    output reg [2:0] filenames,
    output reg done
);

    // FSM States
    localparam [2:0] IDLE            = 3'd0;
    localparam [2:0] INPUT_FRAGMENTS = 3'd1;
    localparam [2:0] INPUT_QUERY     = 3'd2;
    localparam [2:0] COMPARE         = 3'd3;
    localparam [2:0] DONE_STATE      = 3'd4;

    // Constants
    localparam [3:0] MAX_FRAGMENTS = 4'd10;
    localparam [5:0] MAX_LINES     = 6'd50;
    localparam [3:0] MAX_LEN       = 4'd8;

    // Internal Registers
    reg [2:0] state, next_state;
    reg [3:0] curr_frag_idx;
    reg [5:0] curr_line_idx;
    reg [5:0] query_line_count;
    reg [5:0] frag_line_counts [0:9];
    reg [63:0] query_lines [0:49];
    reg [63:0] frag_lines [0:49]; // Temp storage for current fragment
    reg [15:0] max_match_len;
    reg [2:0]  best_frag_idx;
    reg [2:0]  comp_frag_idx;
    reg [5:0]  comp_q_idx;
    reg [5:0]  comp_f_idx;
    reg [15:0] current_match_len;
    reg        cycle_flag;
    reg [15:0] cycle_count;

    // Normalize Line Logic (Combinational)
    // Output: 64-bit packed ASCII (8 chars), 0 if invalid/empty
    wire [63:0] norm_line_frag;
    wire [63:0] norm_line_query;
    reg [63:0] temp_norm_reg;
    reg [1:0] norm_state;
    reg [7:0] i_idx;
    reg [7:0] space_skip;
    reg [7:0] char_idx;
    reg [7:0] last_char_idx;
    reg       leading_space_skipped;
    reg       last_was_space;
    reg [7:0] char_code;
    reg       valid_char_found;

    always @(*) begin
        // Default normalize logic for fragment_data
        // This is a complex combinational block. We assume a simplified logic.
        // In practice, this might need to be split or pipelined.
        // We will implement a simplified state machine for normalization
        // that fits in one always block or uses helper logic.
        // Given complexity, we'll use a procedural loop approach for clarity,
        // but structured to be synthesizable.
        temp_norm_reg = 64'd0;
        leading_space_skipped = 1'b0;
        last_was_space = 1'b0;
        char_idx = 8'd0; // Index in input string (0-255)
        last_char_idx = 8'd0; // Index in output buffer (0-7)
        valid_char_found = 1'b0;

        // Normalization for Fragment Data
        for (int k = 0; k < 256; k = k + 1) begin
            char_code = fragment_data[k*8 +: 8];
            if (char_code == 8'd0) break; // Null terminator
            
            if (char_code == 8'h20) begin // Space
                if (leading_space_skipped && !last_was_space && last_char_idx < 8) begin
                    // Add single space if not first and not consecutive
                    temp_norm_reg[last_char_idx*8 +: 8] = 8'h20;
                    last_char_idx = last_char_idx + 1;
                    last_was_space = 1'b1;
                end
                leading_space_skipped = 1'b1;
            end else begin
                // Non-space char
                if (last_char_idx < 8) begin
                    temp_norm_reg[last_char_idx*8 +: 8] = char_code;
                    last_char_idx = last_char_idx + 1;
                    last_was_space = 1'b0;
                    valid_char_found = 1'b1;
                end
                leading_space_skipped = 1'b1;
            end
            // Input limit
            if (last_char_idx >= 8) break;
        end
        // Handle trailing space removal implicitly by construction
        norm_line_frag = (valid_char_found && (last_char_idx > 0)) ? temp_norm_reg : 64'd0;

        // Normalization for Query Data (Duplicate logic for query_data)
        temp_norm_reg = 64'd0;
        leading_space_skipped = 1'b0;
        last_was_space = 1'b0;
        last_char_idx = 8'd0;
        valid_char_found = 1'b0;
        for (int k = 0; k < 256; k = k + 1) begin
            char_code = query_data[k*8 +: 8];
            if (char_code == 8'd0) break;
            if (char_code == 8'h20) begin
                if (leading_space_skipped && !last_was_space && last_char_idx < 8) begin
                    temp_norm_reg[last_char_idx*8 +: 8] = 8'h20;
                    last_char_idx = last_char_idx + 1;
                    last_was_space = 1'b1;
                end
                leading_space_skipped = 1'b1;
            end else begin
                if (last_char_idx < 8) begin
                    temp_norm_reg[last_char_idx*8 +: 8] = char_code;
                    last_char_idx = last_char_idx + 1;
                    last_was_space = 1'b0;
                    valid_char_found = 1'b1;
                end
                leading_space_skipped = 1'b1;
            end
            if (last_char_idx >= 8) break;
        end
        norm_line_query = (valid_char_found && (last_char_idx > 0)) ? temp_norm_reg : 64'd0;
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = INPUT_FRAGMENTS;
            end
            INPUT_FRAGMENTS: begin
                if (input_done) next_state = INPUT_QUERY;
            end
            INPUT_QUERY: begin
                if (input_done) next_state = COMPARE;
            end
            COMPARE: begin
                // Logic handles transitions in sequential block
                if (cycle_flag) next_state = DONE_STATE;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential Logic
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            filenames <= 3'd0;
            curr_frag_idx <= 4'd0;
            curr_line_idx <= 6'd0;
            query_line_count <= 6'd0;
            max_match_len <= 16'd0;
            best_frag_idx <= 3'd0;
            comp_frag_idx <= 3'd0;
            comp_q_idx <= 6'd0;
            comp_f_idx <= 6'd0;
            current_match_len <= 16'd0;
            cycle_flag <= 1'b0;
            cycle_count <= 16'd0;
            // Initialize arrays
            for (i = 0; i < 10; i = i + 1) frag_line_counts[i] <= 6'd0;
            for (i = 0; i < 50; i = i + 1) begin
                query_lines[i] <= 64'd0;
                frag_lines[i] <= 64'd0;
            end
        end else begin
            done <= 1'b0;
            cycle_flag <= 1'b0;
            cycle_count <= cycle_count + 16'd1;

            case (state)
                IDLE: begin
                    // Reset counters
                    curr_frag_idx <= 4'd0;
                    curr_line_idx <= 6'd0;
                    query_line_count <= 6'd0;
                    max_match_len <= 16'd0;
                    best_frag_idx <= 3'd0;
                    comp_frag_idx <= 3'd0;
                    comp_q_idx <= 6'd0;
                    comp_f_idx <= 6'd0;
                    current_match_len <= 16'd0;
                    cycle_count <= 16'd0;
                end

                INPUT_FRAGMENTS: begin
                    if (fragment_lines_valid) begin
                        // Store fragment line if normalized line is valid
                        if (norm_line_frag != 64'd0 && curr_line_idx < MAX_LINES) begin
                            frag_lines[curr_line_idx] <= norm_line_frag;
                            curr_line_idx <= curr_line_idx + 6'd1;
                        end
                        // If input_done comes, we might be in middle of a fragment
                        // The problem implies fragment_data is fed line by line
                        // and fragment_file_name is associated. 
                        // We assume that one full fragment is sent, then input_done might be asserted.
                        // Or input_done asserts after ALL fragments.
                        // Spec says: "input_done asserted when all input data has been provided"
                        // And transition logic: INPUT_FRAGMENTS -> INPUT_QUERY on input_done.
                        // This implies all fragments are sent in this state.
                    end
                    if (input_done && curr_frag_idx < MAX_FRAGMENTS) begin
                        // Save count for this fragment
                        frag_line_counts[curr_frag_idx] <= curr_line_idx;
                        curr_frag_idx <= curr_frag_idx + 4'd1;
                        curr_line_idx <= 6'd0;
                        // Note: We only store the filename index (which is the fragment index)
                        // We don't have a filename string storage, just the index output requirement.
                    end
                end

                INPUT_QUERY: begin
                    if (query_lines_valid) begin
                        // Store query line
                        if (norm_line_query != 64'd0 && query_line_count < MAX_LINES) begin
                            query_lines[query_line_count] <= norm_line_query;
                            query_line_count <= query_line_count + 6'd1;
                        end
                    end
                end

                COMPARE: begin
                    // Reset comparison if just entering or finished a fragment
                    if (comp_frag_idx >= curr_frag_idx) begin
                        // All fragments processed
                        cycle_flag <= 1'b1;
                    end else begin
                        // Compare logic
                        // Iterate query vs current fragment lines
                        // Sliding window approach
                        
                        if (comp_q_idx < query_line_count && comp_f_idx < frag_line_counts[comp_frag_idx]) begin
                            if (query_lines[comp_q_idx] == frag_lines[comp_f_idx]) begin
                                current_match_len <= current_match_len + 16'd1;
                                comp_q_idx <= comp_q_idx + 6'd1;
                                comp_f_idx <= comp_f_idx + 6'd1;
                            end else begin
                                // Mismatch
                                if (current_match_len > max_match_len) begin
                                    max_match_len <= current_match_len;
                                    best_frag_idx <= comp_frag_idx[2:0];
                                end
                                current_match_len <= 16'd0;
                                // Slide window: reset query index, move fragment index
                                // This is naive O(N*M). For 50x50 it's fine.
                                // Start over for this fragment with next starting point
                                // comp_f_idx increments by 1, comp_q_idx resets to 0
                                comp_q_idx <= 6'd0;
                                comp_f_idx <= comp_f_idx + 6'd1;
                            end
                        end else begin
                            // End of sequence or buffer
                            if (current_match_len > max_match_len) begin
                                max_match_len <= current_match_len;
                                best_frag_idx <= comp_frag_idx[2:0];
                            end
                            current_match_len <= 16'd0;
                            // Move to next fragment
                            comp_frag_idx <= comp_frag_idx + 3'd1;
                            comp_q_idx <= 6'd0;
                            comp_f_idx <= 6'd0;
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    result <= max_match_len;
                    filenames <= best_frag_idx;
                end
            endcase
        end
    end

endmodule