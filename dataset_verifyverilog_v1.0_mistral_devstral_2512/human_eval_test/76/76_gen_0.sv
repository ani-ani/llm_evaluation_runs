module is_simple_power(
    input clk,
    input rst_n,
    input start,
    input [7:0] x,
    input [7:0] n,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE   = 2'd0;
    localparam [1:0] CHECK  = 2'd1;
    localparam [1:0] DIVIDE = 2'd2;
    localparam [1:0] DONE   = 2'd3;

    reg [1:0] state;
    reg [7:0] current_x;
    reg [7:0] current_n;
    reg [3:0] iteration_count;
    localparam [3:0] MAX_ITERATIONS = 4'd8;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            current_x <= 8'd0;
            current_n <= 8'd0;
            iteration_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        current_x <= x;
                        current_n <= n;
                        iteration_count <= 4'd0;
                        state <= CHECK;
                    end
                end

                CHECK: begin
                    if (current_x == 8'd1) begin
                        result <= 1'b1;
                        state <= DONE;
                    end else if (current_n == 8'd1) begin
                        result <= 1'b0;
                        state <= DONE;
                    end else if (current_n == 8'd0) begin
                        if (current_x == 8'd1 || current_x == 8'd0) begin
                            result <= 1'b1;
                        end else begin
                            result <= 1'b0;
                        end
                        state <= DONE;
                    end else if (current_x % current_n == 8'd0) begin
                        state <= DIVIDE;
                    end else begin
                        result <= 1'b0;
                        state <= DONE;
                    end
                end

                DIVIDE: begin
                    current_x <= current_x / current_n;
                    iteration_count <= iteration_count + 4'd1;
                    if (iteration_count >= MAX_ITERATIONS) begin
                        result <= 1'b0;
                        state <= DONE;
                    end else begin
                        state <= CHECK;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule