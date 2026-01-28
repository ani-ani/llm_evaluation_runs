module sum_common_divisors(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] a,
    input wire [15:0] b,
    input wire [11:0] max_iter,
    output reg [23:0] result,
    output reg done,
    output reg busy
);

    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] INIT    = 2'd1;
    localparam [1:0] CHECK   = 2'd2;
    localparam [1:0] MODULO  = 2'd3;
    localparam [1:0] ACCUM   = 2'd4;
    localparam [1:0] INCREMENT = 2'd5;
    localparam [1:0] FINISH  = 2'd6;

    localparam MIN_WIDTH = 16;
    localparam ITER_WIDTH = 12;
    localparam RESULT_WIDTH = 24;

    reg [1:0] state;
    reg [15:0] min_val;
    reg [11:0] counter;
    reg [23:0] sum;
    reg [15:0] a_mod;
    reg [15:0] b_mod;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 24'd0;
            done <= 1'b0;
            busy <= 1'b0;
            min_val <= 16'd0;
            counter <= 12'd0;
            sum <= 24'd0;
            a_mod <= 16'd0;
            b_mod <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                        busy <= 1'b1;
                    end
                end

                INIT: begin
                    min_val <= (a < b) ? a : b;
                    counter <= 12'd1;
                    sum <= 24'd0;
                    state <= CHECK;
                end

                CHECK: begin
                    if (counter >= min_val || counter >= max_iter) begin
                        state <= FINISH;
                    end else begin
                        state <= MODULO;
                    end
                end

                MODULO: begin
                    a_mod <= a % counter;
                    b_mod <= b % counter;
                    state <= ACCUM;
                end

                ACCUM: begin
                    if (a_mod == 16'd0 && b_mod == 16'd0) begin
                        sum <= sum + counter;
                    end
                    state <= INCREMENT;
                end

                INCREMENT: begin
                    counter <= counter + 12'd1;
                    state <= CHECK;
                end

                FINISH: begin
                    result <= sum;
                    done <= 1'b1;
                    busy <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule