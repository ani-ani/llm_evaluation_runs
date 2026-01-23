module sorted_list_sum (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_strings,
    input [7:0] string_data [0:7][0:7],
    output reg [2:0] result_count,
    output reg [7:0] result_strings [0:7][0:7],
    output reg done
);

    // FSM States
    localparam IDLE = 3'b000;
    localparam FILTER = 3'b001;
    localparam SORT_COMPARE = 3'b010;
    localparam SORT_SWAP = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state;
    
    // Filter variables
    reg [2:0] filter_idx;
    reg [2:0] filter_out_idx;
    reg [2:0] str_len;
    reg [2:0] len_idx;
    
    // Sorting variables
    reg [2:0] sort_outer;
    reg [2:0] sort_inner;
    
    // Working registers
    reg [7:0] temp_strings [0:7][0:7];
    reg [2:0] valid_count;
    
    // Comparison helper signals
    wire swap_needed;
    wire [2:0] len_a;
    wire [2:0] len_b;

    integer i, j;

    // --- Combinational Logic for Sorting Comparison ---
    // Calculate lengths of current strings being compared
    assign len_a = (sort_inner < valid_count) ? get_len(temp_strings[sort_inner]) : 0;
    assign len_b = (sort_inner + 1 < valid_count) ? get_len(temp_strings[sort_inner+1]) : 0;
    
    // Determine if swap is needed (Bubble sort: A > B => swap for ascending)
    assign swap_needed = compare_strings(temp_strings[sort_inner], temp_strings[sort_inner+1], len_a, len_b);

    // Helper function for length (combinational)
    function automatic [2:0] get_len;
        input [7:0] str [0:7];
        integer k;
        begin
            get_len = 0;
            for (k = 0; k < 8; k++) begin
                if (str[k] == 8'h00) begin
                    get_len = k;
                    return;
                end
            end
            get_len = 8;
        end
    endfunction

    // Helper function for comparison: returns 1 if A > B (needs swap)
    function automatic logic compare_strings;
        input [7:0] a [0:7];
        input [7:0] b [0:7];
        input [2:0] len_a_in;
        input [2:0] len_b_in;
        integer m;
        begin
            compare_strings = 0;
            // Primary sort: length
            if (len_a_in > len_b_in) begin
                compare_strings = 1;
            end else if (len_a_in == len_b_in) begin
                // Secondary sort: alphabetical
                for (m = 0; m < 8; m++) begin
                    if (m < len_a_in) begin
                        if (a[m] > b[m]) begin
                            compare_strings = 1;
                            break;
                        end else if (a[m] < b[m]) begin
                            compare_strings = 0;
                            break;
                        end
                    end
                end
            end
        end
    endfunction

    // --- Sequential Logic (FSM) ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_count <= 0;
            done <= 0;
            // Clear arrays
            for (i = 0; i < 8; i = i + 1) begin
                result_strings[i] <= 8'h0;
                temp_strings[i] <= 8'h0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= FILTER;
                        filter_idx <= 0;
                        filter_out_idx <= 0;
                        valid_count <= 0;
                        len_idx <= 0;
                        str_len <= 0;
                    end
                end

                FILTER: begin
                    // Determine length of current string
                    if (len_idx < 8) begin
                        // Check current char and next char to find null termination
                        // Simplified logic: scan forward
                        if (len_idx == 0) str_len <= 0;
                        
                        // Check for null terminator
                        if (string_data[filter_idx][len_idx] == 8'h00 && str_len == 0) begin
                            str_len <= len_idx;
                        end else if (len_idx == 7) begin
                            // Reached end of max length
                            if (string_data[filter_idx][7] != 8'h00) str_len <= 8;
                            else if (str_len == 0) str_len <= 7; // Should have caught earlier, but safety
                        end
                        
                        len_idx <= len_idx + 1;
                    end else begin
                        // Length determined, check parity
                        // Keep if even length and valid count not exceeded
                        if (str_len[0] == 1'b0 && filter_out_idx < 8) begin
                            // Copy string to temp buffer
                            for (j = 0; j < 8; j = j + 1) begin
                                temp_strings[filter_out_idx][j] <= string_data[filter_idx][j];
                            end
                            filter_out_idx <= filter_out_idx + 1;
                            valid_count <= valid_count + 1;
                        end
                        
                        // Next input string
                        filter_idx <= filter_idx + 1;
                        len_idx <= 0;
                        str_len <= 0;
                        
                        // Check if done filtering
                        if (filter_idx + 1 >= num_strings || filter_out_idx >= 8) begin
                            state <= (valid_count > 1 || (filter_idx + 1 >= num_strings && valid_count > 0)) ? SORT_COMPARE : DONE;
                            sort_outer <= 0;
                            sort_inner <= 0;
                            // If we finished filtering and have 0 or 1 strings, go to DONE
                            if (valid_count <= 1 && (filter_idx + 1 >= num_strings || filter_out_idx >= 8)) begin
                                state <= DONE;
                            end else begin
                                state <= SORT_COMPARE;
                            end
                        end
                    end
                end

                SORT_COMPARE: begin
                    // Check if sorting is complete
                    if (sort_outer >= valid_count - 1) begin
                        state <= DONE;
                    end else if (sort_inner >= valid_count - sort_outer - 1) begin
                        // End of inner loop
                        sort_outer <= sort_outer + 1;
                        sort_inner <= 0;
                        // Loop back to check outer condition next cycle
                    end else begin
                        // Comparison result is available via swap_needed wire
                        // We proceed to SWAP state immediately
                        state <= SORT_SWAP;
                    end
                end

                SORT_SWAP: begin
                    // Perform swap if needed
                    if (swap_needed) begin
                        // Swap temp_strings[sort_inner] and temp_strings[sort_inner+1]
                        for (j = 0; j < 8; j = j + 1) begin
                            temp_strings[sort_inner][j] <= temp_strings[sort_inner+1][j];
                            temp_strings[sort_inner+1][j] <= temp_strings[sort_inner][j];
                        end
                    end
                    
                    // Increment inner index
                    sort_inner <= sort_inner + 1;
                    
                    // Return to compare to check loop conditions
                    state <= SORT_COMPARE;
                end

                DONE: begin
                    done <= 1;
                    result_count <= valid_count;
                    // Copy temp to output
                    for (j = 0; j < 8; j = j + 1) begin
                        if (j < valid_count)
                            result_strings[j] <= temp_strings[j];
                        else
                            result_strings[j] <= 8'h0;
                    end
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule