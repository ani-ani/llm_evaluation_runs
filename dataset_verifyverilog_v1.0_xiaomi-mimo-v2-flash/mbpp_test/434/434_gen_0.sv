module PatternScanner (
    input clk,
    input rst_n,
    input start,
    input [127:0] str_data,
    input [3:0] str_len,
    output reg match_found,
    output reg done
);
    // State definitions
    localparam [1:0] S_IDLE = 2'd0;
    localparam [1:0] S_SCAN = 2'd1;
    localparam [1:0] S_DONE = 2'd2;

    // ASCII constants
    localparam [7:0] ASCII_A = 8'h61;
    localparam [7:0] ASCII_B = 8'h62;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] index, next_index;
    reg found_a, next_found_a;
    reg next_match_found;
    reg next_done;

    // Combinational next state logic
    always @(*) begin
        next_state = state;
        next_index = index;
        next_found_a = found_a;
        next_match_found = match_found;
        next_done = 1'b0;

        case (state)
            S_IDLE: begin
                if (start) begin
                    next_state = S_SCAN;
                    next_index = 4'd0;
                    next_found_a = 1'b0;
                end
            end

            S_SCAN: begin
                if (index < str_len) begin
                    // Extract current character
                    // Use bit slicing for compatibility
                    reg [7:0] current_char;
                    current_char = str_data[7 + (index * 8) : (index * 8)];

                    if (current_char == ASCII_A) begin
                        next_found_a = 1'b1;
                    end else if (found_a && current_char == ASCII_B) begin
                        next_match_found = 1'b1;
                    end else if (found_a && current_char != ASCII_B) begin
                        // Character is neither 'a' nor 'b' after 'a', reset found_a
                        next_found_a = 1'b0;
                    end
                    // If not found_a and character is not 'a', remain in IDLE mode (found_a stays 0)

                    next_index = index + 4'd1;
                end else begin
                    // Scan complete
                    next_state = S_DONE;
                    next_done = 1'b1;
                end
            end

            S_DONE: begin
                next_state = S_IDLE;
            end

            default: begin
                next_state = S_IDLE;
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            index <= 4'd0;
            found_a <= 1'b0;
            match_found <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            index <= next_index;
            found_a <= next_found_a;
            match_found <= next_match_found;
            done <= next_done;
        end
    end
endmodule