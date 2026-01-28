module obfuscation_check (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] char_0,
    input wire [4:0] char_1,
    input wire [4:0] char_2,
    input wire [4:0] char_3,
    input wire [4:0] char_4,
    input wire [4:0] char_5,
    input wire [4:0] char_6,
    input wire [4:0] char_7,
    input wire [3:0] len,
    output reg result,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROC = 2'd1;
    localparam [1:0] DONE = 2'd2;

    reg [1:0] state, next_state;
    reg [2:0] index, next_index;
    reg [7:0] seen, next_seen;
    reg [2:0] next_expected, next_next_expected;
    reg next_result, next_done;

    wire [4:0] current_char;
    assign current_char = (index == 3'd0) ? char_0 :
                          (index == 3'd1) ? char_1 :
                          (index == 3'd2) ? char_2 :
                          (index == 3'd3) ? char_3 :
                          (index == 3'd4) ? char_4 :
                          (index == 3'd5) ? char_5 :
                          (index == 3'd6) ? char_6 :
                          char_7;

    always @(*) begin
        next_state = state;
        next_index = index;
        next_seen = seen;
        next_next_expected = next_expected;
        next_result = result;
        next_done = 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROC;
                    next_index = 3'd0;
                    next_seen = 8'd0;
                    next_next_expected = 3'd0;
                    next_result = 1'b1;
                end
            end

            PROC: begin
                if (index < len) begin
                    if (seen[current_char[2:0]]) begin
                        next_index = index + 1'b1;
                    end else begin
                        if (current_char[2:0] == next_expected) begin
                            next_seen = seen | (1'b1 << current_char[2:0]);
                            next_next_expected = next_expected + 1'b1;
                            next_index = index + 1'b1;
                        end else begin
                            next_result = 1'b0;
                            next_state = DONE;
                            next_done = 1'b1;
                        end
                    end
                end else begin
                    next_state = DONE;
                    next_done = 1'b1;
                end
            end

            DONE: begin
                next_state = IDLE;
                next_done = 1'b0;
            end

            default: begin
                next_state = IDLE;
                next_index = 3'd0;
                next_seen = 8'd0;
                next_next_expected = 3'd0;
                next_result = 1'b0;
                next_done = 1'b0;
            end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 3'd0;
            seen <= 8'd0;
            next_expected <= 3'd0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            index <= next_index;
            seen <= next_seen;
            next_expected <= next_next_expected;
            result <= next_result;
            done <= next_done;
        end
    end

endmodule