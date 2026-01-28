module pattern_matcher(
    input clk,
    input rst_n,
    input start,
    input [7:0] str [0:15],
    input [3:0] valid_len,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SCAN = 2'd1;
    localparam [1:0] COUNT_B = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state, next_state;
    reg [3:0] index;
    reg [1:0] b_count;
    reg [7:0] current_char;
    reg [7:0] next_char;
    reg found;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            b_count <= 2'd0;
            current_char <= 8'd0;
            next_char <= 8'd0;
            found <= 1'b0;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            index <= index + 4'd1;
            current_char <= next_char;
            cycle_count <= cycle_count + 8'd1;

            if (state == SCAN) begin
                if (index < valid_len) begin
                    next_char <= str[index];
                end else begin
                    next_char <= 8'd0;
                end
            end

            if (state == COUNT_B) begin
                if (index < valid_len) begin
                    next_char <= str[index];
                end else begin
                    next_char <= 8'd0;
                end
            end
        end
    end

    always @(*) begin
        next_state = state;
        done = 1'b0;
        result = 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SCAN;
                    index = 4'd0;
                    b_count = 2'd0;
                    current_char = 8'd0;
                    next_char = 8'd0;
                    found = 1'b0;
                    cycle_count = 8'd0;
                end
            end

            SCAN: begin
                if (index >= valid_len) begin
                    next_state = DONE_STATE;
                end else begin
                    if (current_char == 8'd97) begin
                        if (next_char == 8'd98) begin
                            next_state = COUNT_B;
                            b_count = 2'd1;
                        end
                    end
                end
            end

            COUNT_B: begin
                if (index >= valid_len) begin
                    next_state = DONE_STATE;
                end else begin
                    if (next_char == 8'd98) begin
                        b_count = b_count + 2'd1;
                        if (b_count == 2'd2 || b_count == 2'd3) begin
                            found = 1'b1;
                        end
                    end else begin
                        next_state = SCAN;
                        if (found) begin
                            next_state = DONE_STATE;
                        end
                    end
                end
            end

            DONE_STATE: begin
                result = found;
                done = 1'b1;
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule