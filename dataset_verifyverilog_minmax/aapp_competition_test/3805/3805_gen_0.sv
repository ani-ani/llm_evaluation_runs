module wire_untangle (
    input clk,
    input rst_n,
    input start,
    input [15:0] data,
    output reg done,
    output reg result
);

reg [1:0] state;
reg [3:0] cycle_count;
reg [3:0] stack_ptr;
reg [7:0] stack;

localparam IDLE = 0, PROCESSING = 1, DONE = 2;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        cycle_count <= 0;
        stack_ptr <= 0;
        stack <= 0;
        done <= 0;
        result <= 0;
    end else begin
        case (state)
            IDLE: begin
                done <= 0;
                result <= 0;
                if (start) begin
                    state <= PROCESSING;
                    cycle_count <= 0;
                    stack_ptr <= 0;
                    stack <= 0;
                end
            end
            PROCESSING: begin
                if (stack_ptr == 0) begin
                    stack[0] <= data[2 * cycle_count];
                    stack_ptr <= 1;
                end else begin
                    if (stack[stack_ptr-1] == data[2 * cycle_count]) begin
                        stack_ptr <= stack_ptr - 1;
                    end else begin
                        stack[stack_ptr] <= data[2 * cycle_count];
                        stack_ptr <= stack_ptr + 1;
                    end
                end

                if (cycle_count == 7) begin
                    state <= DONE;
                    done <= 1;
                    result <= (stack_ptr == 0);
                end else begin
                    state <= PROCESSING;
                    cycle_count <= cycle_count + 1;
                end
            end
            DONE: begin
                if (start) begin
                    state <= DONE;
                end else begin
                    state <= IDLE;
                end
            end
        endcase
    end
end

endmodule