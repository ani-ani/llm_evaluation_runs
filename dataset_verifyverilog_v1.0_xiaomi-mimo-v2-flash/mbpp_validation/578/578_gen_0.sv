module interleave_lists (
    input clk,
    input rst_n,
    input start,
    input [7:0] list1 [0:7],
    input [7:0] list2 [0:7],
    input [7:0] list3 [0:7],
    input [3:0] length,
    output reg [7:0] result,
    output reg done,
    output reg ready
);

    // State declarations
    localparam [2:0] IDLE           = 3'd0;
    localparam [2:0] FETCH_LIST1    = 3'd1;
    localparam [2:0] FETCH_LIST2    = 3'd2;
    localparam [2:0] FETCH_LIST3    = 3'd3;
    localparam [2:0] DONE_STATE     = 3'd4;

    reg [2:0] state, next_state;
    reg [3:0] index_reg;
    reg [3:0] next_index;
    reg [7:0] result_reg;
    reg done_reg;
    reg ready_reg;

    // FSM State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index_reg <= 4'd0;
            result_reg <= 8'd0;
            done_reg <= 1'b0;
            ready_reg <= 1'b1;
        end else begin
            state <= next_state;
            index_reg <= next_index;
            result <= result_reg;
            done <= done_reg;
            ready <= ready_reg;
        end
    end

    // Combinational Next State Logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_index = index_reg;
        result_reg = 8'd0;
        done_reg = 1'b0;
        ready_reg = 1'b0;

        case (state)
            IDLE: begin
                ready_reg = 1'b1;
                next_index = 4'd0;
                if (start && length > 4'd0) begin
                    next_state = FETCH_LIST1;
                    ready_reg = 1'b0;
                end
            end

            FETCH_LIST1: begin
                if (index_reg < length) begin
                    result_reg = list1[index_reg];
                    next_state = FETCH_LIST2;
                end else begin
                    next_state = DONE_STATE;
                end
            end

            FETCH_LIST2: begin
                if (index_reg < length) begin
                    result_reg = list2[index_reg];
                    next_state = FETCH_LIST3;
                end else begin
                    next_state = DONE_STATE;
                end
            end

            FETCH_LIST3: begin
                if (index_reg < length) begin
                    result_reg = list3[index_reg];
                    // Check if this was the last element to process
                    if (index_reg == (length - 4'd1)) begin
                        next_state = DONE_STATE;
                    end else begin
                        next_state = FETCH_LIST1;
                        next_index = index_reg + 4'd1;
                    end
                end else begin
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                done_reg = 1'b1;
                ready_reg = 1'b1;
                next_state = IDLE;
                next_index = 4'd0;
            end

            default: begin
                next_state = IDLE;
                next_index = 4'd0;
            end
        endcase
    end

endmodule