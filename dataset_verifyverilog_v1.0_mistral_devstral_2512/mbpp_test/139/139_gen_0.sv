module circle_circumference (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] radius,
    output wire [31:0] circumference,
    output wire done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALC1 = 2'd1;
    localparam [1:0] CALC2 = 2'd2;
    localparam [1:0] DONE = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg [31:0] result_reg;
    reg done_reg;
    reg [31:0] mult1_result;
    reg [31:0] mult2_result;

    // Constants (Q16.16 format)
    localparam [31:0] PI_FIXED = 32'd205887;  // 3.141592653589793 * 65536
    localparam [31:0] TWO_FIXED = 32'd131072; // 2.0 * 65536

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_reg <= 32'd0;
            done_reg <= 1'b0;
            mult1_result <= 32'd0;
            mult2_result <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done_reg <= 1'b0;
                    if (start) begin
                        state <= CALC1;
                        mult1_result <= TWO_FIXED * PI_FIXED;
                    end
                end

                CALC1: begin
                    state <= CALC2;
                    mult2_result <= mult1_result * (radius << 8);
                end

                CALC2: begin
                    state <= DONE;
                    result_reg <= mult2_result >> 16;
                end

                DONE: begin
                    done_reg <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Assign outputs
    assign done = done_reg;
    assign circumference = result_reg;

endmodule