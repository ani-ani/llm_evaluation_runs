module StringStartEndCheck(
    input clk,
    input rst_n,
    input start,
    input [7:0] string_data [0:7],
    input [2:0] string_len,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] FETCH_FIRST = 2'd1;
    localparam [1:0] COMPARE_LAST = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state, next_state;
    reg [7:0] first_char;
    reg [7:0] last_char;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            first_char <= 8'd0;
            last_char <= 8'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state = FETCH_FIRST;
                    end else begin
                        next_state = IDLE;
                    end
                end

                FETCH_FIRST: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (string_len == 3'd0) begin
                        result <= 1'b0;
                        next_state = DONE_STATE;
                    end else begin
                        first_char <= string_data[0];
                        next_state = COMPARE_LAST;
                    end
                end

                COMPARE_LAST: begin
                    cycle_count <= cycle_count + 8'd1;
                    last_char <= string_data[string_len - 1];
                    if (first_char == last_char) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                    next_state = DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state = IDLE;
                end

                default: next_state = IDLE;
            endcase
        end
    end
endmodule