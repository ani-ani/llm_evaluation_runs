module UniqueTupleCounter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] tuple_arr [0:15][0:1],
    input wire [3:0] len,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SORT_TUPLES = 3'd1;
    localparam [2:0] COMPARE_TUPLES = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Sorted tuples storage
    reg [7:0] sorted_tuples [0:15][0:1];
    reg [3:0] sort_idx;
    reg [3:0] compare_i, compare_j;
    reg [7:0] unique_count;
    reg [7:0] temp_tuple0, temp_tuple1;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            sort_idx <= 4'd0;
            compare_i <= 4'd0;
            compare_j <= 4'd0;
            unique_count <= 8'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SORT_TUPLES;
                    sort_idx = 4'd0;
                    cycle_count = 8'd0;
                end
            end

            SORT_TUPLES: begin
                if (sort_idx == len - 1) begin
                    next_state = COMPARE_TUPLES;
                    compare_i = 4'd0;
                    compare_j = 4'd0;
                    unique_count = 8'd0;
                end else begin
                    sort_idx = sort_idx + 4'd1;
                end
            end

            COMPARE_TUPLES: begin
                if (compare_i == len - 1) begin
                    next_state = DONE_STATE;
                end else if (compare_j == compare_i) begin
                    compare_j = compare_j + 4'd1;
                end else if (compare_j == len - 1) begin
                    compare_i = compare_i + 4'd1;
                    compare_j = 4'd0;
                end else begin
                    compare_j = compare_j + 4'd1;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Sorting logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                sorted_tuples[i][0] <= 8'd0;
                sorted_tuples[i][1] <= 8'd0;
            end
        end else if (state == SORT_TUPLES) begin
            if (tuple_arr[sort_idx][0] > tuple_arr[sort_idx][1]) begin
                sorted_tuples[sort_idx][0] <= tuple_arr[sort_idx][1];
                sorted_tuples[sort_idx][1] <= tuple_arr[sort_idx][0];
            end else begin
                sorted_tuples[sort_idx][0] <= tuple_arr[sort_idx][0];
                sorted_tuples[sort_idx][1] <= tuple_arr[sort_idx][1];
            end
        end
    end

    // Comparison logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 8'd0;
        end else if (state == COMPARE_TUPLES) begin
            if (compare_j == 4'd0) begin
                unique_count <= unique_count + 8'd1;
            end else if (sorted_tuples[compare_i][0] == sorted_tuples[compare_j][0] &&
                        sorted_tuples[compare_i][1] == sorted_tuples[compare_j][1]) begin
                unique_count <= unique_count - 8'd1;
            end
        end else if (state == DONE_STATE) begin
            result <= unique_count;
        end
    end

    // Done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else if (state == DONE_STATE) begin
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule