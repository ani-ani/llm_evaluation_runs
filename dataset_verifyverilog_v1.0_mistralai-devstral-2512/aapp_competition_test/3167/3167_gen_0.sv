module RangeSumModule(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [9:0] L,
    input wire [9:0] R,
    input wire [0:1023] counts,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE_PREFIX = 2'd1;
    localparam [1:0] OUTPUT_RESULT = 2'd2;

    reg [1:0] state;
    reg [9:0] index;
    reg [15:0] prefix_sum;
    reg [15:0] ps [0:1024];
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1500;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 10'd0;
            prefix_sum <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE_PREFIX;
                        index <= 10'd0;
                        prefix_sum <= 16'd0;
                    end
                end

                COMPUTE_PREFIX: begin
                    cycle_count <= cycle_count + 8'd1;
                    ps[index] <= prefix_sum;
                    prefix_sum <= prefix_sum + counts[index];
                    index <= index + 10'd1;

                    if (index == 10'd1024 || cycle_count >= MAX_CYCLES) begin
                        ps[10'd1024] <= prefix_sum;
                        state <= OUTPUT_RESULT;
                    end
                end

                OUTPUT_RESULT: begin
                    result <= ps[R + 10'd1] - ps[L];
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule