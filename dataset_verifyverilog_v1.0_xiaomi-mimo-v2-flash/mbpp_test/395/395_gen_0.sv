module first_non_repeated_char(
    input clk,
    input rst_n,
    input start,
    input [7:0] str [0:15],
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE         = 2'd0;
    localparam [1:0] COUNT_PASS   = 2'd1;
    localparam [1:0] SEARCH_PASS  = 2'd2;
    localparam [1:0] DONE_STATE   = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg [4:0] index;          // 0-15 for string iteration
    reg [1:0] count_reg [0:15]; // 2-bit counter for each character position
    reg [7:0] result_reg;
    reg found;
    reg [4:0] loop_counter;   // For cycle limiting

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 8'd0;
            result_reg <= 8'd0;
            done <= 1'b0;
            index <= 5'd0;
            found <= 1'b0;
            loop_counter <= 5'd0;
            // Initialize count array
            for (i = 0; i < 16; i = i + 1) begin
                count_reg[i] <= 2'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    found <= 1'b0;
                    index <= 5'd0;
                    loop_counter <= 5'd0;
                    // Clear count array for next operation
                    for (i = 0; i < 16; i = i + 1) begin
                        count_reg[i] <= 2'd0;
                    end
                    
                    if (start) begin
                        state <= COUNT_PASS;
                    end
                end

                COUNT_PASS: begin
                    // First pass: count occurrences
                    if (index < 16) begin
                        // Compare current character with all previous characters
                        // Increment count for matching characters
                        for (i = 0; i < 16; i = i + 1) begin
                            if (str[index] == str[i]) begin
                                count_reg[i] <= (count_reg[i] < 2'd3) ? (count_reg[i] + 2'd1) : 2'd3;
                            end
                        end
                        index <= index + 5'd1;
                    end else begin
                        // Finished counting, move to search
                        index <= 5'd0;
                        state <= SEARCH_PASS;
                    end
                end

                SEARCH_PASS: begin
                    // Second pass: search for first character with count == 1
                    if (index < 16) begin
                        if (!found && count_reg[index] == 2'd1) begin
                            result_reg <= str[index];
                            found <= 1'b1;
                        end
                        index <= index + 5'd1;
                    end else begin
                        // Finished searching
                        result <= (found) ? result_reg : 8'd0;
                        done <= 1'b1;
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule