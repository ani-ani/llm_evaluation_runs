module is_nested(
    input clk,
    input rst_n,
    input start,
    input [7:0] str [0:15],
    input [3:0] str_len,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [3:0] index;
    reg [3:0] depth;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd20;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            depth <= 4'd0;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 4'd0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done = 1'b0;
                result = 1'b0;
                index = 4'd0;
                depth = 4'd0;
                cycle_count = 4'd0;
                if (start) begin
                    next_state = PROCESSING;
                end
            end

            PROCESSING: begin
                cycle_count = cycle_count + 4'd1;
                if (index < str_len) begin
                    if (str[index] == 8'd91) begin  // '['
                        if (depth > 0) begin
                            result = 1'b1;
                        end
                        depth = depth + 4'd1;
                    end else if (str[index] == 8'd93) begin  // ']'
                        depth = depth - 4'd1;
                    end
                    index = index + 4'd1;
                end else begin
                    next_state = DONE_STATE;
                end
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule