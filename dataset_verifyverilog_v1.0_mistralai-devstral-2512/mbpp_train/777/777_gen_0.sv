module sum_non_repeated(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    input [3:0] len,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK = 3'd1;
    localparam [2:0] SUM = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    reg [2:0] state, next_state;
    reg [7:0] current_element;
    reg [7:0] count;
    reg [3:0] outer_index;
    reg [3:0] inner_index;
    reg [15:0] sum;
    reg [7:0] element_to_check;
    reg element_found;
    reg [7:0] temp_count;
    reg [3:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            outer_index <= 4'd0;
            inner_index <= 4'd0;
            sum <= 16'd0;
            count <= 8'd0;
            current_element <= 8'd0;
            element_to_check <= 8'd0;
            element_found <= 1'b0;
            temp_count <= 8'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    next_state = CHECK;
                    outer_index = 4'd0;
                    sum = 16'd0;
                    cycle_count = 8'd0;
                end
            end

            CHECK: begin
                if (outer_index < len) begin
                    element_to_check = arr[outer_index];
                    temp_count = 8'd0;
                    inner_index = 4'd0;
                    next_state = SUM;
                end else begin
                    next_state = DONE_STATE;
                end
            end

            SUM: begin
                if (inner_index < len) begin
                    if (arr[inner_index] == element_to_check) begin
                        temp_count = temp_count + 8'd1;
                    end
                    inner_index = inner_index + 4'd1;
                end else begin
                    if (temp_count == 8'd1) begin
                        sum = sum + element_to_check;
                    end
                    outer_index = outer_index + 4'd1;
                    next_state = CHECK;
                end
            end

            DONE_STATE: begin
                done = 1'b1;
                result = sum;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule