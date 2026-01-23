module plagiarism_detector (
    input clk,
    input rst_n,
    input start,
    input [255:0] current_line,
    input line_valid,
    input [255:0] repo_line_0,
    input [255:0] repo_line_1,
    input [1:0] repo_valid,
    input [3:0] repo_index,
    input fragment_end,
    input snippet_end,
    output reg [7:0] max_match_length,
    output reg [255:0] matching_filenames,
    output reg done,
    output reg match_found
);

    // Parameters
    parameter MAX_FRAGMENTS = 100;
    parameter MAX_FILENAME_LEN = 8;
    parameter MAX_FILENAMES = 255 / (MAX_FILENAME_LEN + 1); // Space separated

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        READ_FRAGMENT,
        NORMALIZE,
        COMPARE,
        UPDATE_STATE,
        FINALIZE
    } state_t;

    // Internal registers
    state_t current_state, next_state;
    reg [7:0] match_count [0:MAX_FRAGMENTS-1];
    reg [7:0] current_max;
    reg [255:0] normalized_line;
    reg [7:0] fragment_idx;
    reg [7:0] line_counter;
    reg [7:0] filename_ptr;
    reg [255:0] filename_buffer;
    reg [7:0] max_fragments;
    reg [7:0] active_fragments;
    reg [MAX_FRAGMENTS-1:0] fragment_active;
    reg [7:0] temp_match_length;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            max_match_length <= 0;
            matching_filenames <= 0;
            done <= 0;
            match_found <= 0;
            current_max <= 0;
            fragment_idx <= 0;
            line_counter <= 0;
            filename_ptr <= 0;
            filename_buffer <= 0;
            max_fragments <= 0;
            active_fragments <= 0;
            for (int i = 0; i < MAX_FRAGMENTS; i++) begin
                match_count[i] <= 0;
                fragment_active[i] <= 0;
            end
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = READ_FRAGMENT;
            end
            READ_FRAGMENT: begin
                if (fragment_end) next_state = NORMALIZE;
                else if (line_valid) next_state = NORMALIZE;
            end
            NORMALIZE: begin
                next_state = COMPARE;
            end
            COMPARE: begin
                next_state = UPDATE_STATE;
            end
            UPDATE_STATE: begin
                if (fragment_end) next_state = FINALIZE;
                else if (snippet_end) next_state = FINALIZE;
                else next_state = READ_FRAGMENT;
            end
            FINALIZE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Normalization logic
    always @(posedge clk) begin
        if (current_state == NORMALIZE && line_valid) begin
            reg [255:0] temp_line = current_line;
            reg [7:0] i, j;
            reg space_flag;

            // Trim leading spaces
            for (i = 0; i < 256; i++) begin
                if (temp_line[i] != " ") break;
            end

            // Trim trailing spaces and collapse multiple spaces
            normalized_line = 0;
            space_flag = 0;
            j = 0;
            for (; i < 256; i++) begin
                if (temp_line[i] == " ") begin
                    if (!space_flag && j > 0) begin
                        normalized_line[j] = " ";
                        j++;
                        space_flag = 1;
                    end
                end else begin
                    normalized_line[j] = temp_line[i];
                    j++;
                    space_flag = 0;
                end
            end

            // Remove trailing space if any
            if (j > 0 && normalized_line[j-1] == " ") begin
                normalized_line[j-1] = 0;
            end
        end
    end

    // Comparison logic
    always @(posedge clk) begin
        if (current_state == COMPARE) begin
            reg match0, match1;
            match0 = (normalized_line == repo_line_0) && repo_valid[0];
            match1 = (normalized_line == repo_line_1) && repo_valid[1];

            // Update match counters
            if (match0 && fragment_active[repo_index]) begin
                match_count[repo_index] <= match_count[repo_index] + 1;
            end else if (!match0 && fragment_active[repo_index]) begin
                if (match_count[repo_index] > current_max) begin
                    current_max <= match_count[repo_index];
                end
                match_count[repo_index] <= 0;
            end

            if (match1 && fragment_active[repo_index+1]) begin
                match_count[repo_index+1] <= match_count[repo_index+1] + 1;
            end else if (!match1 && fragment_active[repo_index+1]) begin
                if (match_count[repo_index+1] > current_max) begin
                    current_max <= match_count[repo_index+1];
                end
                match_count[repo_index+1] <= 0;
            end
        end
    end

    // Update state logic
    always @(posedge clk) begin
        if (current_state == UPDATE_STATE) begin
            if (fragment_end) begin
                // Finalize current fragment
                if (match_count[fragment_idx] > current_max) begin
                    current_max <= match_count[fragment_idx];
                end
                fragment_idx <= fragment_idx + 1;
            end

            if (snippet_end) begin
                // Compute final results
                reg [7:0] max_val = current_max;
                reg [255:0] filenames = 0;
                reg [7:0] ptr = 0;
                reg any_match = 0;

                for (int i = 0; i < MAX_FRAGMENTS; i++) begin
                    if (fragment_active[i] && match_count[i] == max_val) begin
                        any_match = 1;
                        // Add filename to buffer (simplified - in real design would need filename storage)
                        if (ptr + MAX_FILENAME_LEN + 1 <= 255) begin
                            filenames[ptr + MAX_FILENAME_LEN - 1:ptr] = "fragment"; // Placeholder
                            filenames[ptr + MAX_FILENAME_LEN] = " ";
                            ptr <= ptr + MAX_FILENAME_LEN + 1;
                        end
                    end
                end

                max_match_length <= max_val;
                matching_filenames <= filenames;
                done <= 1;
                match_found <= any_match;
            end
        end
    end

    // Fragment activation logic
    always @(posedge clk) begin
        if (current_state == READ_FRAGMENT && line_valid) begin
            if (repo_valid[0] && !fragment_active[repo_index]) begin
                fragment_active[repo_index] <= 1;
                active_fragments <= active_fragments + 1;
            end
            if (repo_valid[1] && !fragment_active[repo_index+1]) begin
                fragment_active[repo_index+1] <= 1;
                active_fragments <= active_fragments + 1;
            end
        end
    end

endmodule