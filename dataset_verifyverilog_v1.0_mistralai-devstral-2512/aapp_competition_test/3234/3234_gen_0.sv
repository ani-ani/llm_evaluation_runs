module min_empty_squares(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] N,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    // Internal registers
    reg [2:0] state, next_state;
    reg [31:0] min_empty;
    reg [31:0] current_H;
    reg [31:0] current_W;
    reg [31:0] current_empty;
    reg [31:0] W_start;
    reg [31:0] W_max;
    reg [31:0] cycle_count;
    localparam [31:0] MAX_CYCLES = 32'd2048;
    localparam [31:0] MAX_H = 32'd1024;

    // Ceiling division function
    function [31:0] ceil_div;
        input [31:0] a, b;
        begin
            if (b == 0) begin
                ceil_div = 32'd0;
            end else begin
                ceil_div = (a + b - 1) / b;
            end
        end
    endfunction

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end else begin
                    next_state = IDLE;
                end
            end

            INIT: begin
                next_state = COMPUTE;
            end

            COMPUTE: begin
                if (cycle_count >= MAX_CYCLES || current_H >= MAX_H) begin
                    next_state = FINISH;
                end else begin
                    next_state = COMPUTE;
                end
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // State register and main logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            min_empty <= 32'd0;
            current_H <= 32'd0;
            current_W <= 32'd0;
            current_empty <= 32'd0;
            W_start <= 32'd0;
            W_max <= 32'd0;
            cycle_count <= 32'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 32'd0;
                end

                INIT: begin
                    min_empty <= 32'd0;
                    current_H <= 32'd1;
                    cycle_count <= 32'd0;
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 32'd1;

                    // Calculate W_start and W_max
                    W_start = ceil_div(N, current_H);
                    if (W_start < ceil_div(current_H, 2)) begin
                        W_start = ceil_div(current_H, 2);
                    end
                    W_max = current_H * 2;

                    // Calculate current_empty if valid
                    if (W_start <= W_max) begin
                        current_empty = W_start * current_H - N;
                        if (min_empty == 32'd0 || current_empty < min_empty) begin
                            min_empty = current_empty;
                        end
                    end

                    // Move to next H
                    current_H <= current_H + 32'd1;

                    // Check if we've found a solution or reached max cycles
                    if (current_H >= MAX_H || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= min_empty;
                    done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule