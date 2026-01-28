module rounded_avg(
    input clk,
    input rst_n,
    input start,
    input [15:0] n,
    input [15:0] m,
    output reg [15:0] result,
    output reg error,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE  = 2'd0;
    localparam [1:0] CHECK = 2'd1;
    localparam [1:0] CALC  = 2'd2;
    localparam [1:0] DONE  = 2'd3;

    reg [1:0] state;
    reg [16:0] sum;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            error <= 1'b0;
            done <= 1'b0;
            sum <= 17'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    if (start) begin
                        state <= CHECK;
                    end
                end

                CHECK: begin
                    if (n > m) begin
                        error <= 1'b1;
                        result <= 16'd0;
                        state <= DONE;
                    end else begin
                        error <= 1'b0;
                        state <= CALC;
                    end
                end

                CALC: begin
                    sum <= 17'd0 + n + m;
                    result <= sum[16:1];
                    if (sum[0]) begin
                        result <= result + 16'd1;
                    end
                    state <= DONE;
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