module wool_sequence_counter(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] m,
    output reg [31:0] result,
    output reg done
);

    localparam [31:0] MOD = 32'd1000000009;

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [3:0] i;
    reg [31:0] pow2m;
    reg [31:0] product;
    reg [31:0] factor;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 4'd0;
            pow2m <= 32'd0;
            product <= 32'd1;
            factor <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
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
                    next_state = COMPUTE;
                    i = 4'd0;
                    pow2m = 1 << m;
                    product = 32'd1;
                    cycle_count = 8'd0;
                end
            end

            COMPUTE: begin
                if (i < n) begin
                    if (pow2m >= i) begin
                        factor = pow2m - i;
                    end else begin
                        factor = MOD - (i - pow2m);
                    end
                    product = (product * factor) % MOD;
                    i = i + 4'd1;
                    cycle_count = cycle_count + 8'd1;
                end else begin
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                result = product;
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule