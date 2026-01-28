module SeriesSum(
    input clk,
    input rst_n,
    input start,
    input [7:0] n_in,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [7:0] current_term;
    reg [15:0] current_sum;
    reg [3:0] iteration_count;
    localparam [3:0] MAX_ITERATIONS = 4'd16;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            current_term <= 8'd0;
            current_sum <= 16'd0;
            iteration_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        current_term <= n_in;
                        current_sum <= 16'd0;
                        iteration_count <= 4'd0;
                    end
                end

                COMPUTE: begin
                    iteration_count <= iteration_count + 4'd1;

                    // Update sum and term
                    if (current_term > 8'd0) begin
                        current_sum <= current_sum + current_term;
                        current_term <= current_term - 8'd2;
                    end

                    // Check completion condition
                    if (current_term <= 8'd0 || iteration_count >= MAX_ITERATIONS) begin
                        state <= COMPLETE;
                    end
                end

                COMPLETE: begin
                    result <= current_sum;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule