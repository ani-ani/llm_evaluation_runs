module colon_tuplex(
    input clk,
    input rst_n,
    input start,
    input [2:0] m,
    input [7:0] n,
    input [7:0] tuplex_0,
    input [7:0] tuplex_1,
    input [7:0] tuplex_2,
    input [7:0] tuplex_3,
    output reg [7:0] result_0,
    output reg [7:0] result_1,
    output reg [7:0] result_2,
    output reg [7:0] result_3,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    reg [1:0] cycle_cnt, next_cycle_cnt;
    reg [7:0] next_result_0, next_result_1, next_result_2, next_result_3;
    reg next_done;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_cnt <= 2'b00;
            result_0 <= 8'b0;
            result_1 <= 8'b0;
            result_2 <= 8'b0;
            result_3 <= 8'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            cycle_cnt <= next_cycle_cnt;
            result_0 <= next_result_0;
            result_1 <= next_result_1;
            result_2 <= next_result_2;
            result_3 <= next_result_3;
            done <= next_done;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        next_cycle_cnt = cycle_cnt;
        next_result_0 = result_0;
        next_result_1 = result_1;
        next_result_2 = result_2;
        next_result_3 = result_3;
        next_done = done;

        case (state)
            IDLE: begin
                next_done = 1'b0;
                next_cycle_cnt = 2'b00;
                if (start) begin
                    next_state = PROCESSING;
                    next_cycle_cnt = 2'b01;
                end else begin
                    next_state = IDLE;
                end
            end
            
            PROCESSING: begin
                next_cycle_cnt = cycle_cnt + 1;
                if (cycle_cnt == 2'b01) begin
                    next_state = DONE;
                    case (m)
                        3'd0: next_result_0 = n;
                        3'd1: next_result_1 = n;
                        3'd2: next_result_2 = n;
                        3'd3: next_result_3 = n;
                        default: begin
                            next_result_0 = result_0;
                            next_result_1 = result_1;
                            next_result_2 = result_2;
                            next_result_3 = result_3;
                        end
                    endcase
                end else begin
                    next_state = PROCESSING;
                end
            end

            DONE: begin
                next_state = DONE;
                next_cycle_cnt = 2'b00;
                if (start) begin
                    next_state = PROCESSING;
                    next_cycle_cnt = 2'b01;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule
