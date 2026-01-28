module largest_prime_factor(
    input clk,
    input rst_n,
    input start,
    input [31:0] n,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE       = 4'd0;
    localparam [3:0] SETUP      = 4'd1;
    localparam [3:0] LOOP_START = 4'd2;
    localparam [3:0] CHECK_DIV  = 4'd3;
    localparam [3:0] DIVIDE     = 4'd4;
    localparam [3:0] INCR       = 4'd5;
    localparam [3:0] FINALIZE   = 4'd6;
    localparam [3:0] DONE_STATE = 4'd7;

    reg [3:0] state;
    reg [31:0] temp_n;
    reg [31:0] factor;
    reg [31:0] max_factor;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            temp_n <= 32'd0;
            factor <= 32'd0;
            max_factor <= 32'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= SETUP;
                    end
                end

                SETUP: begin
                    temp_n <= n;
                    factor <= 32'd2;
                    max_factor <= 32'd1;
                    cycle_count <= 8'd0;
                    state <= LOOP_START;
                end

                LOOP_START: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (factor * factor > temp_n || cycle_count >= MAX_CYCLES) begin
                        state <= FINALIZE;
                    end else begin
                        state <= CHECK_DIV;
                    end
                end

                CHECK_DIV: begin
                    if (temp_n % factor == 0) begin
                        state <= DIVIDE;
                    end else begin
                        state <= INCR;
                    end
                end

                DIVIDE: begin
                    temp_n <= temp_n / factor;
                    max_factor <= factor;
                    state <= CHECK_DIV;
                end

                INCR: begin
                    factor <= factor + 32'd1;
                    state <= LOOP_START;
                end

                FINALIZE: begin
                    if (temp_n > 1) begin
                        result <= temp_n;
                    end else begin
                        result <= max_factor;
                    end
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    if (start) begin
                        state <= SETUP;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule