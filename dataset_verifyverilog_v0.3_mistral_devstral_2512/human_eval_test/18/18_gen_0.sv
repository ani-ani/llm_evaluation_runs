module substring_matcher(
    input clk,
    input rst_n,
    input start,
    input [7:0] main_str [0:7],
    input [7:0] sub_str [0:7],
    input [3:0] main_len,
    input [3:0] sub_len,
    output reg [3:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [3:0] position;  // Current position in main_str
    reg [3:0] match_count;  // Temporary match counter
    reg [3:0] char_index;  // Character index for comparison
    reg match;  // Current character match flag

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            position <= 4'd0;
            match_count <= 4'd0;
            char_index <= 4'd0;
            match <= 1'b1;
        end else begin
            state <= next_state;
        end
    end

    // Next state and datapath logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    next_state = PROCESSING;
                    position = 4'd0;
                    match_count = 4'd0;
                    char_index = 4'd0;
                    match = 1'b1;
                end
            end

            PROCESSING: begin
                // Character comparison
                if (char_index < sub_len) begin
                    if (main_str[position + char_index] != sub_str[char_index]) begin
                        match = 1'b0;
                    end
                    char_index = char_index + 4'd1;
                end
                // End of substring comparison
                else begin
                    if (match) begin
                        match_count = match_count + 4'd1;
                    end
                    // Move to next position
                    position = position + 4'd1;
                    char_index = 4'd0;
                    match = 1'b1;
                    
                    // Check if all positions processed
                    if (position > (main_len - sub_len)) begin
                        next_state = DONE_STATE;
                    end
                end
            end

            DONE_STATE: begin
                result = match_count;
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule