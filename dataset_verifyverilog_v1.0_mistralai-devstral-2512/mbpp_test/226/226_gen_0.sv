module odd_index_filter (
    input clk,
    input rst_n,
    input start,
    input [3:0] len,
    input [7:0] input_str [0:15],
    output reg [7:0] result [0:7],
    output reg [3:0] output_len,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [3:0] index;
    reg [3:0] result_index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            result_index <= 4'd0;
            output_len <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            // Initialize result array
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                result[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESSING;
                    index = 4'd0;
                    result_index = 4'd0;
                    output_len = 4'd0;
                    done = 1'b0;
                    cycle_count = 8'd0;
                end
            end
            PROCESSING: begin
                if (index < len) begin
                    if (index[0] == 1'b0) begin  // Even index (LSB = 0)
                        result[result_index] = input_str[index];
                        result_index = result_index + 4'd1;
                    end
                    index = index + 4'd1;
                    cycle_count = cycle_count + 8'd1;
                    if (index >= len || cycle_count >= MAX_CYCLES) begin
                        next_state = DONE_STATE;
                        output_len = result_index;
                    end
                end else begin
                    next_state = DONE_STATE;
                    output_len = result_index;
                end
            end
            DONE_STATE: begin
                next_state = IDLE;
                done = 1'b1;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule