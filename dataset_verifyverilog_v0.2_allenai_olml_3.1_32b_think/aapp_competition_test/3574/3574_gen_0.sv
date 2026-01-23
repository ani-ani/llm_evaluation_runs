module magical_subarray (
    input clk,
    input rst_n,
    input start,
    input [7:0] array_data [0:7],
    input [2:0] query_L,
    input [2:0] query_R,
    output reg [3:0] result,
    output reg done
);

    reg [2:0] i, j;
    reg [7:0] current_min, current_max;
    reg [3:0] max_len;
    reg [2:0] state;

    localparam S_IDLE = 3'b000;
    localparam S_INIT = 3'b001;
    localparam S_INNER_PROCESS = 3'b010;
    localparam S_OUTER_INCREMENT = 3'b011;
    localparam S_DONE = 3'b100;

    reg [3:0] next_state;

    always @(*) begin
        i <= 3'b000;
        j <= 3'b000;
        current_min <= 8'b00000000;
        current_max <= 8'b00000000;
        max_len <= 4'b0000;
        state <= S_IDLE;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i <= 3'b000;
            j <= 3'b000;
            current_min <= 8'b00000000;
            current_max <= 8'b00000000;
            max_len <= 4'b0000;
            done <= 1'b0;
            result <= 4'b0000;
            state <= S_IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE: begin
                if (start) next_state = S_INIT;
                else next_state = S_IDLE;
            end
            S_INIT: begin
                i <= query_L;
                if (i > query_R) begin
                    max_len <= 4'b0000;
                    done <= 1'b1;
                    next_state = S_DONE;
                end else begin
                    j <= i;
                    current_min <= array_data[i];
                    current_max <= array_data[i];
                    max_len <= 4'b0001;
                    next_state = S_INNER_PROCESS;
                end
            end
            S_INNER_PROCESS: begin
                if (j - i + 1 > max_len) max_len <= j - i + 1;
                if (j < query_R) begin
                    j <= j + 1;
                    if (array_data[j] < current_min) current_min <= array_data[j];
                    if (array_data[j] > current_max) current_max <= array_data[j];
                    next_state = S_INNER_PROCESS;
                end else begin
                    next_state = S_OUTER_INCREMENT;
                end
            end
            S_OUTER_INCREMENT: begin
                i <= i + 1;
                if (i <= query_R) begin
                    j <= i;
                    current_min <= array_data[i];
                    current_max <= array_data[i];
                    if (1 > max_len) max_len <= 1;
                    next_state = S_INNER_PROCESS;
                end else begin
                    done <= 1'b1;
                    result <= max_len;
                    next_state = S_DONE;
                end
            end
            S_DONE: begin
                result <= max_len;
                done <= 1'b1;
                next_state = S_DONE;
            end
            default: next_state = S_IDLE;
        endcase
    end

endmodule