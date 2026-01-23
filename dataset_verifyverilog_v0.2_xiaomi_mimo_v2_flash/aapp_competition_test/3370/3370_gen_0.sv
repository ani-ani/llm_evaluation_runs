module eagleton_solver (
    input clk,
    input rst_n,
    input start,
    input [31:0] k,
    input [31:0] h_0,
    output reg [31:0] max_height,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam CALC = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state;
    reg [2:0] count; // Counts 0 to 7 (8 cycles total, 7 additions)
    reg [31:0] accumulator;
    reg [31:0] k_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_height <= 32'd0;
            done <= 1'b0;
            count <= 3'd0;
            accumulator <= 32'd0;
            k_reg <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= CALC;
                        accumulator <= h_0;
                        k_reg <= k;
                        count <= 3'd0;
                    end
                end

                CALC: begin
                    // We need to perform 7 additions to get h_0 + 7*k
                    // We start adding from count=0 up to count=6 (7 iterations)
                    // When count reaches 7, we are done adding.
                    if (count < 3'd7) begin
                        accumulator <= accumulator + k_reg;
                        count <= count + 1'b1;
                    end else begin
                        state <= DONE;
                        max_height <= accumulator;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule