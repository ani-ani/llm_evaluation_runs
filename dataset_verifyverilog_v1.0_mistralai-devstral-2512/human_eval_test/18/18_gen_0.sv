module substring_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] string_data,
    input wire [127:0] substring_data,
    input wire [3:0] string_len,
    input wire [3:0] substring_len,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    reg [1:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    reg [3:0] string_pos;
    reg [3:0] char_pos;
    reg [7:0] match_count;
    reg char_match;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            string_pos <= 4'd0;
            char_pos <= 4'd0;
            match_count <= 8'd0;
            char_match <= 1'b1;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        done = 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPARE;
                    string_pos = 4'd0;
                    char_pos = 4'd0;
                    match_count = 8'd0;
                    char_match = 1'b1;
                    cycle_count = 8'd0;
                end
            end

            COMPARE: begin
                // Check if we've processed all positions
                if (string_pos + substring_len > string_len) begin
                    next_state = FINISH;
                    result = match_count;
                end else begin
                    // Compare current character
                    if (string_data[(string_pos + char_pos) * 8 +: 8] != substring_data[char_pos * 8 +: 8]) begin
                        char_match = 1'b0;
                    end

                    // Move to next character or next position
                    if (char_pos == substring_len - 1) begin
                        if (char_match) begin
                            match_count = match_count + 8'd1;
                        end
                        string_pos = string_pos + 4'd1;
                        char_pos = 4'd0;
                        char_match = 1'b1;
                    end else begin
                        char_pos = char_pos + 4'd1;
                    end

                    cycle_count = cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state = FINISH;
                        result = match_count;
                    end
                end
            end

            FINISH: begin
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule