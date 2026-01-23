module fibfib(
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CHECK_BASE = 3'd1;
    localparam [2:0] INIT_LOOP  = 3'd2;
    localparam [2:0] ITERATE    = 3'd3;
    localparam [2:0] FINISHED   = 3'd4;

    reg [2:0] state;
    reg [31:0] f0, f1, f2;
    reg [4:0] counter;
    reg [31:0] next_f;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            f0 <= 32'd0;
            f1 <= 32'd0;
            f2 <= 32'd1;
            counter <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= CHECK_BASE;
                    end
                end

                CHECK_BASE: begin
                    if (n == 5'd0 || n == 5'd1) begin
                        result <= 32'd0;
                        state <= FINISHED;
                    end else if (n == 5'd2) begin
                        result <= 32'd1;
                        state <= FINISHED;
                    end else begin
                        state <= INIT_LOOP;
                    end
                end

                INIT_LOOP: begin
                    f0 <= 32'd0;
                    f1 <= 32'd0;
                    f2 <= 32'd1;
                    counter <= 5'd3;
                    state <= ITERATE;
                end

                ITERATE: begin
                    if (counter == n) begin
                        result <= f2;
                        state <= FINISHED;
                    end else begin
                        next_f <= f0 + f1 + f2;
                        f0 <= f1;
                        f1 <= f2;
                        f2 <= next_f;
                        counter <= counter + 5'd1;
                    end
                end

                FINISHED: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule