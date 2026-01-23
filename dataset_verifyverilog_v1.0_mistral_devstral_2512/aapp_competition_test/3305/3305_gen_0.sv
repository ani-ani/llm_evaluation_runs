module CountAlmostPalindromicSubstrings(
    input clk,
    input rst_n,
    input start,
    input [4:0] char_in [0:3],
    output reg [3:0] count,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE   = 3'd0;
    localparam [2:0] EXTRACT = 3'd1;
    localparam [2:0] CHECK  = 3'd2;
    localparam [2:0] NEXT   = 3'd3;
    localparam [2:0] DONE   = 3'd4;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Substring tracking
    reg [1:0] start_idx;
    reg [1:0] length;
    reg [4:0] substring [0:3];
    reg [3:0] temp_count;

    // Almost palindrome check function
    function automatic [0:0] is_almost_palindrome;
        input [4:0] s [0:3];
        input [1:0] len;
        reg [4:0] temp [0:3];
        integer i, j;

        // Copy to temp array
        for (i = 0; i < 4; i = i + 1) begin
            temp[i] = s[i];
        end

        // Check if already palindrome
        case (len)
            2'd1: is_almost_palindrome = 1'b1;
            2'd2: is_almost_palindrome = (temp[0] == temp[1]);
            2'd3: is_almost_palindrome = (temp[0] == temp[2]);
            2'd4: is_almost_palindrome = (temp[0] == temp[3] && temp[1] == temp[2]);
            default: is_almost_palindrome = 1'b0;
        endcase

        if (is_almost_palindrome) begin
            return 1'b1;
        end

        // Try all possible swaps for non-palindromes
        case (len)
            2'd3: begin
                // Swap 0 and 1
                temp[0] = s[1];
                temp[1] = s[0];
                if (temp[0] == temp[2]) begin
                    is_almost_palindrome = 1'b1;
                    return 1'b1;
                end
                // Swap 0 and 2
                temp[0] = s[2];
                temp[2] = s[0];
                if (temp[0] == temp[2]) begin
                    is_almost_palindrome = 1'b1;
                    return 1'b1;
                end
                // Swap 1 and 2
                temp[1] = s[2];
                temp[2] = s[1];
                if (temp[0] == temp[2]) begin
                    is_almost_palindrome = 1'b1;
                    return 1'b1;
                end
            end
            2'd4: begin
                // Swap 0 and 1
                temp[0] = s[1];
                temp[1] = s[0];
                if (temp[0] == temp[3] && temp[1] == temp[2]) begin
                    is_almost_palindrome = 1'b1;
                    return 1'b1;
                end
                // Swap 0 and 2
                temp[0] = s[2];
                temp[2] = s[0];
                if (temp[0] == temp[3] && temp[1] == temp[2]) begin
                    is_almost_palindrome = 1'b1;
                    return 1'b1;
                end
                // Swap 0 and 3
                temp[0] = s[3];
                temp[3] = s[0];
                if (temp[0] == temp[3] && temp[1] == temp[2]) begin
                    is_almost_palindrome = 1'b1;
                    return 1'b1;
                end
                // Swap 1 and 2
                temp[1] = s[2];
                temp[2] = s[1];
                if (temp[0] == temp[3] && temp[1] == temp[2]) begin
                    is_almost_palindrome = 1'b1;
                    return 1'b1;
                end
                // Swap 1 and 3
                temp[1] = s[3];
                temp[3] = s[1];
                if (temp[0] == temp[3] && temp[1] == temp[2]) begin
                    is_almost_palindrome = 1'b1;
                    return 1'b1;
                end
                // Swap 2 and 3
                temp[2] = s[3];
                temp[3] = s[2];
                if (temp[0] == temp[3] && temp[1] == temp[2]) begin
                    is_almost_palindrome = 1'b1;
                    return 1'b1;
                end
            end
        endcase

        is_almost_palindrome = 1'b0;
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            start_idx <= 2'd0;
            length <= 2'd0;
            temp_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= EXTRACT;
                        start_idx <= 2'd0;
                        length <= 2'd1;
                        temp_count <= 4'd0;
                    end
                end
                
                EXTRACT: begin
                    // Extract substring
                    substring[0] = char_in[start_idx];
                    if (length > 1'b1) begin
                        substring[1] = char_in[start_idx + 1'b1];
                    end
                    if (length > 2'b10) begin
                        substring[2] = char_in[start_idx + 2'b10];
                    end
                    if (length > 2'b11) begin
                        substring[3] = char_in[start_idx + 2'b11];
                    end
                    state <= CHECK;
                end
                
                CHECK: begin
                    if (is_almost_palindrome(substring, length)) begin
                        temp_count <= temp_count + 4'd1;
                    end
                    state <= NEXT;
                end
                
                NEXT: begin
                    // Move to next substring
                    if (length < (4'b100 - start_idx)) begin
                        length <= length + 1'b1;
                        state <= EXTRACT;
                    end else if (start_idx < 2'b11) begin
                        start_idx <= start_idx + 1'b1;
                        length <= 2'd1;
                        state <= EXTRACT;
                    end else begin
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

            // Safety counter
            if (cycle_count >= MAX_CYCLES) begin
                state <= IDLE;
                done <= 1'b0;
                count <= 4'd0;
            end else begin
                cycle_count <= cycle_count + 8'd1;
            end
        end
    end
endmodule