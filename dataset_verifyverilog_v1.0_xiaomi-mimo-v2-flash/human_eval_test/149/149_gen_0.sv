module FilterAndSortStrings(
    input clk,
    input rst_n,
    input start,
    input [127:0] strings [0:7],
    input [2:0] valid_count,
    output reg [127:0] result [0:7],
    output reg [2:0] result_count,
    output reg done
);

    // Parameters
    localparam [7:0] STRING_WIDTH = 8'd128;
    localparam [7:0] MAX_STRINGS = 8'd8;
    localparam [7:0] MAX_CYCLES = 8'd255;
    
    // State definitions
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] FILTER   = 3'd1;
    localparam [2:0] SORT     = 3'd2;
    localparam [2:0] OUTPUT   = 3'd3;
    localparam [2:0] FINISH   = 3'd4;
    
    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] cycle_count;
    
    // Storage for strings
    reg [127:0] temp_strings [0:7];
    reg [2:0] temp_count;
    
    // Filter and sort variables
    reg [2:0] i, j;
    reg [7:0] len_i, len_j;
    reg [127:0] swap_temp;
    reg swap_needed;
    reg [7:0] char_idx;
    reg [7:0] char_i, char_j;
    reg diff_found;
    reg [2:0] pass_count;
    
    // Helper function to compute string length (up to 16 or first null)
    function automatic [7:0] compute_length(input [127:0] str);
        integer k;
        reg [7:0] len;
        reg [7:0] byte_val;
        begin
            len = 8'd0;
            for (k = 0; k < 16; k = k + 1) begin
                byte_val = str[(k*8)+:8];
                if (byte_val == 8'd0 || k == 15) begin
                    if (byte_val != 8'd0) begin
                        len = 8'd16;
                    end
                    compute_length = len;
                    disable compute_length;
                end
            end
            compute_length = 8'd16;
        end
    endfunction
    
    // Helper function to compare strings for sorting
    function automatic [0:0] should_swap(input [127:0] str_a, input [7:0] len_a, input [127:0] str_b, input [7:0] len_b);
        integer k;
        reg [7:0] char_a, char_b;
        reg [0:0] result;
        begin
            // First compare by length
            if (len_a > len_b) begin
                should_swap = 1'b1;  // Swap if A is longer (B should come first)
                disable should_swap;
            end
            if (len_a < len_b) begin
                should_swap = 1'b0;
                disable should_swap;
            end
            
            // If lengths equal, compare lexicographically
            for (k = 0; k < 16; k = k + 1) begin
                char_a = str_a[(k*8)+:8];
                char_b = str_b[(k*8)+:8];
                if (char_a != char_b) begin
                    should_swap = (char_a > char_b);  // Swap if A > B
                    disable should_swap;
                end
            end
            // Strings are identical
            should_swap = 1'b0;
        end
    endfunction
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_count <= 3'd0;
            cycle_count <= 8'd0;
            temp_count <= 3'd0;
            i <= 3'd0;
            j <= 3'd0;
            char_idx <= 8'd0;
            pass_count <= 3'd0;
            len_i <= 8'd0;
            len_j <= 8'd0;
            // Initialize result array
            result[0] <= 128'd0;
            result[1] <= 128'd0;
            result[2] <= 128'd0;
            result[3] <= 128'd0;
            result[4] <= 128'd0;
            result[5] <= 128'd0;
            result[6] <= 128'd0;
            result[7] <= 128'd0;
            // Initialize temp storage
            temp_strings[0] <= 128'd0;
            temp_strings[1] <= 128'd0;
            temp_strings[2] <= 128'd0;
            temp_strings[3] <= 128'd0;
            temp_strings[4] <= 128'd0;
            temp_strings[5] <= 128'd0;
            temp_strings[6] <= 128'd0;
            temp_strings[7] <= 128'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    temp_count <= 3'd0;
                    i <= 3'd0;
                    j <= 3'd0;
                    pass_count <= 3'd0;
                    if (start) begin
                        // Initialize result array to zeros
                        result[0] <= 128'd0;
                        result[1] <= 128'd0;
                        result[2] <= 128'd0;
                        result[3] <= 128'd0;
                        result[4] <= 128'd0;
                        result[5] <= 128'd0;
                        result[6] <= 128'd0;
                        result[7] <= 128'd0;
                        result_count <= 3'd0;
                    end
                end
                
                FILTER: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Check if current string has even length
                    if (i < valid_count) begin
                        if (compute_length(strings[i]) % 2 == 0) begin
                            temp_strings[temp_count] <= strings[i];
                            temp_count <= temp_count + 3'd1;
                        end
                        i <= i + 3'd1;
                    end
                end
                
                SORT: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Bubble sort
                    if (pass_count < temp_count) begin
                        if (j < temp_count - 3'd1 - pass_count) begin
                            len_i <= compute_length(temp_strings[j]);
                            len_j <= compute_length(temp_strings[j+3'd1]);
                            // Perform comparison and swap if needed
                            if (should_swap(temp_strings[j], len_i, temp_strings[j+3'd1], len_j)) begin
                                temp_strings[j] <= temp_strings[j+3'd1];
                                temp_strings[j+3'd1] <= temp_strings[j];
                            end
                            j <= j + 3'd1;
                        end else begin
                            j <= 3'd0;
                            pass_count <= pass_count + 3'd1;
                        end
                    end
                end
                
                OUTPUT: begin
                    // Copy filtered and sorted strings to output
                    if (i < temp_count) begin
                        result[i] <= temp_strings[i];
                        i <= i + 3'd1;
                    end
                    result_count <= temp_count;
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Combinational next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = FILTER;
                end
            end
            
            FILTER: begin
                if (i >= valid_count) begin
                    next_state = SORT;
                end
            end
            
            SORT: begin
                if (pass_count >= temp_count) begin
                    next_state = OUTPUT;
                end
            end
            
            OUTPUT: begin
                if (i >= temp_count) begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
        
        // Safety: prevent infinite loops
        if (cycle_count >= MAX_CYCLES && state != IDLE) begin
            next_state = IDLE;
        end
    end

endmodule