module CountAlmostPalindromicSubstrings (
    input clk,
    input rst_n,
    input start,
    input [4:0] char_in [0:3],
    output reg [3:0] count,
    output reg done
);

    // FSM State definitions
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] EXTRACT  = 3'd1;
    localparam [2:0] CHECK    = 3'd2;
    localparam [2:0] NEXT     = 3'd3;
    localparam [2:0] DONE     = 3'd4;

    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [1:0] start_idx;      // 0 to 3
    reg [1:0] length;         // 1 to 4
    reg [3:0] temp_count;
    reg [4:0] substr_chars [0:3]; // Stores extracted characters
    reg [2:0] active_len;     // Tracks actual length of substring
    reg [7:0] cycle_count;    // Prevents infinite loops
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Combinational outputs for Check block
    reg is_almost_pal;
    
    // Check logic for substring in substr_chars of length active_len
    always @(*) begin
        integer i, j;
        reg mismatch_found;
        reg [4:0] char_a, char_b;
        reg [1:0] mis_idx0, mis_idx1;
        reg [1:0] mis_cnt;
        reg swap_valid;
        
        // Default
        is_almost_pal = 1'b0;
        mismatch_found = 1'b0;
        mis_cnt = 2'd0;
        
        if (active_len == 3'd1) begin
            is_almost_pal = 1'b1;
        end else if (active_len == 3'd2) begin
            if (substr_chars[0] == substr_chars[1]) is_almost_pal = 1'b1;
        end else if (active_len == 3'd3) begin
            // Check palindrome
            if (substr_chars[0] == substr_chars[2]) is_almost_pal = 1'b1;
            else begin
                // Check all swaps (3 pairs)
                // Swap (0,1)
                if (substr_chars[1] == substr_chars[2]) is_almost_pal = 1'b1;
                // Swap (0,2)
                else if (substr_chars[2] == substr_chars[0]) is_almost_pal = 1'b1;
                // Swap (1,2)
                else if (substr_chars[0] == substr_chars[1]) is_almost_pal = 1'b1;
            end
        end else if (active_len == 3'd4) begin
            // Check palindrome
            if ((substr_chars[0] == substr_chars[3]) && (substr_chars[1] == substr_chars[2])) begin
                is_almost_pal = 1'b1;
            end else begin
                // Check all 6 swaps for palindrome
                // Swap (0,1)
                if ((substr_chars[1] == substr_chars[3]) && (substr_chars[0] == substr_chars[2])) is_almost_pal = 1'b1;
                // Swap (0,2)
                else if ((substr_chars[2] == substr_chars[3]) && (substr_chars[1] == substr_chars[0])) is_almost_pal = 1'b1;
                // Swap (0,3)
                else if ((substr_chars[3] == substr_chars[1]) && (substr_chars[0] == substr_chars[2])) is_almost_pal = 1'b1;
                // Swap (1,2)
                else if ((substr_chars[0] == substr_chars[3]) && (substr_chars[2] == substr_chars[1])) is_almost_pal = 1'b1;
                // Swap (1,3)
                else if ((substr_chars[0] == substr_chars[2]) && (substr_chars[3] == substr_chars[1])) is_almost_pal = 1'b1;
                // Swap (2,3)
                else if ((substr_chars[0] == substr_chars[3]) && (substr_chars[1] == substr_chars[0])) is_almost_pal = 1'b1;
            end
        end
    end

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            start_idx <= 2'd0;
            length <= 2'd1;
            count <= 4'd0;
            temp_count <= 4'd0;
            active_len <= 3'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            // Initialize substr_chars array
            substr_chars[0] <= 5'd0;
            substr_chars[1] <= 5'd0;
            substr_chars[2] <= 5'd0;
            substr_chars[3] <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    temp_count <= 4'd0;
                    start_idx <= 2'd0;
                    length <= 2'd1;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= EXTRACT;
                    end
                end

                EXTRACT: begin
                    // Extract current substring based on start_idx and length
                    active_len <= length;
                    case (length)
                        2'd1: begin
                            substr_chars[0] <= char_in[start_idx];
                        end
                        2'd2: begin
                            substr_chars[0] <= char_in[start_idx];
                            substr_chars[1] <= char_in[start_idx + 2'd1];
                        end
                        2'd3: begin
                            substr_chars[0] <= char_in[start_idx];
                            substr_chars[1] <= char_in[start_idx + 2'd1];
                            substr_chars[2] <= char_in[start_idx + 2'd2];
                        end
                        default: begin // length 4
                            substr_chars[0] <= char_in[start_idx];
                            substr_chars[1] <= char_in[start_idx + 2'd1];
                            substr_chars[2] <= char_in[start_idx + 2'd2];
                            substr_chars[3] <= char_in[start_idx + 2'd3];
                        end
                    endcase
                    state <= CHECK;
                end

                CHECK: begin
                    // Check if substring is almost palindromic
                    if (is_almost_pal) begin
                        temp_count <= temp_count + 4'd1;
                    end
                    state <= NEXT;
                end

                NEXT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Update indices for next substring
                    // Logic: 
                    // 1. If length < 4 and start_idx + length < 4, increment length
                    // 2. Else, increment start_idx and reset length
                    
                    if (length < 2'd4 && (start_idx + length < 2'd3)) begin
                        // Keep start_idx, increase length (within bound)
                        length <= length + 2'd1;
                        state <= EXTRACT;
                    end else begin
                        // Try to increment start_idx
                        if (start_idx < 2'd3) begin
                            start_idx <= start_idx + 2'd1;
                            length <= 2'd1; // Reset length for new start
                            state <= EXTRACT;
                        end else begin
                            // Exhausted all combinations
                            state <= DONE;
                        end
                    end

                    // Safety timeout
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    count <= temp_count;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule