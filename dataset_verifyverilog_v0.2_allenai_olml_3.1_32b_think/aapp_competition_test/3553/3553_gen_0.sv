module shortest_subarray_solver (
    input clk,
    input rst_n,
    input start,
    input [1:0] query_type,
    input [4:0] pos,
    input [1:0] new_value,
    output reg result_valid,
    output reg [5:0] shortest_length,
    output reg processing_done
);

reg [1:0] array [15:0];
reg [1:0] captured_query_type;
reg [4:0] captured_pos;
reg [1:0] captured_new_value;
reg [5:0] min_len;
reg [2:0] state;
localparam IDLE = 3'd0, INIT_SCAN = 3'd1, OUTER_LOOP = 3'd2, INNER_LOOP = 3'd3, DONE = 3'd4;
reg [3:0] current_start, current_end;
reg [1:0] count [1:4];

always @(posedge clk) begin
    if (!rst_n) begin
        array <= {16{2'b01}};
        min_len <= 6'b111111;
        state <= IDLE;
        current_start <= 4'd0;
        current_end <= 4'd0;
        count <= {4{2'b00}};
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    captured_query_type <= query_type;
                    captured_pos <= pos;
                    captured_new_value <= new_value;
                    if (captured_query_type == 0) begin
                        array[captured_pos] <= captured_new_value;
                        processing_done <= 1;
                        result_valid <= 0;
                    end else begin
                        state <= INIT_SCAN;
                    end
                end
            end
            INIT_SCAN: begin
                min_len <= 6'b111111;
                count <= {4{2'b00}};
                current_start <= 4'd0;
                current_end <= 4'd0;
                state <= OUTER_LOOP;
            end
            OUTER_LOOP: begin
                if (current_start < 16) begin
                    count <= {4{2'b00}};
                    current_end <= current_start;
                    state <= INNER_LOOP;
                end else begin
                    state <= DONE;
                end
            end
            INNER_LOOP: begin
                integer val;
                val = array[current_end];
                if (val >= 1 && val <= 3) begin
                    count[val] <= count[val] + 1;
                end
                if (count[1] >= 1 && count[2] >= 1 && count[3] >= 1 && count[4] >= 1) begin
                    integer length;
                    length = current_end - current_start + 1;
                    if (length < min_len) begin
                        min_len <= length;
                    end
                end
                if (current_end < 15) begin
                    current_end <= current_end + 1;
                    state <= INNER_LOOP;
                end else begin
                    current_start <= current_start + 1;
                    if (current_start < 16) begin
                        count <= {4{2'b00}};
                        current_end <= current_start;
                        state <= INNER_LOOP;
                    end else begin
                        state <= DONE;
                    end
                end
            end
            DONE: begin
                result_valid <= 1;
                shortest_length <= min_len;
                processing_done <= 1;
                state <= IDLE;
            end
        endcase
    end
endmodule