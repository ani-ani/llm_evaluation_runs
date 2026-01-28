module first_repeated_char (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] str [0:15],
    input wire [3:0] len,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] LOAD       = 3'd1;
    localparam [2:0] COMPARE    = 3'd2;
    localparam [2:0] CHECK_NEXT = 3'd3;
    localparam [2:0] FINISH     = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] i, i_next;      // Outer loop index (0 to len-1)
    reg [3:0] j, j_next;      // Inner loop index (0 to i-1)
    reg [7:0] current_char, current_char_next;
    reg [7:0] result_reg, result_next;
    reg found_match, found_match_next;
    reg [7:0] str_reg [0:15]; // Store input string locally

    integer k;

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 4'd0;
            j <= 4'd0;
            current_char <= 8'd0;
            result_reg <= 8'd0;
            found_match <= 1'b0;
            done <= 1'b0;
            result <= 8'd0;
            // Initialize str_reg to avoid X values
            for (k = 0; k < 16; k = k + 1) begin
                str_reg[k] <= 8'd0;
            end
        end else begin
            state <= next_state;
            i <= i_next;
            j <= j_next;
            current_char <= current_char_next;
            result_reg <= result_next;
            found_match <= found_match_next;
            done <= (state == FINISH); // Pulse done when in FINISH state
            if (state == FINISH) begin
                result <= result_next;
            end
        end
    end

    // Next state logic
    always @(*) begin
        // Default assignments
        next_state = state;
        i_next = i;
        j_next = j;
        current_char_next = current_char;
        result_next = result_reg;
        found_match_next = found_match;

        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    next_state = LOAD;
                    i_next = 4'd0;
                    j_next = 4'd0;
                    result_next = 8'd0;
                    found_match_next = 1'b0;
                    // Capture input string
                    for (k = 0; k < 16; k = k + 1) begin
                        str_reg[k] = str[k];
                    end
                end
            end

            LOAD: begin
                if (i < len) begin
                    current_char_next = str_reg[i];
                    j_next = 4'd0;
                    next_state = COMPARE;
                end else begin
                    // No repeats found in entire string
                    result_next = 8'd0;
                    next_state = FINISH;
                end
            end

            COMPARE: begin
                if (j < i) begin
                    if (current_char == str_reg[j]) begin
                        // Match found
                        result_next = current_char;
                        found_match_next = 1'b1;
                        next_state = FINISH;
                    end else begin
                        j_next = j + 4'd1;
                        next_state = COMPARE;
                    end
                end else begin
                    // Inner loop done, no match for current char
                    i_next = i + 4'd1;
                    next_state = LOAD;
                end
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule