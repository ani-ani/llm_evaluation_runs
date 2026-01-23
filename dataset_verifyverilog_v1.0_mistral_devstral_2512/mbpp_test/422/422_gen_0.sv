module average_of_cube (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] n,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] ACCUMULATE = 2'd1;
    localparam [1:0] DIVIDE = 2'd2;
    localparam [1:0] COMPLETE = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg [2:0] counter;
    reg [31:0] accumulator;
    reg [2:0] divisor;
    reg [4:0] div_counter;
    reg [47:0] dividend;
    reg [31:0] quotient;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 3'd0;
            accumulator <= 32'd0;
            divisor <= 3'd0;
            div_counter <= 5'd0;
            dividend <= 48'd0;
            quotient <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start && n >= 3'd1) begin
                        counter <= 3'd1;
                        accumulator <= 32'd0;
                        divisor <= n;
                        state <= ACCUMULATE;
                    end
                end

                ACCUMULATE: begin
                    if (counter <= divisor) begin
                        accumulator <= accumulator + (counter * counter * counter);
                        counter <= counter + 3'd1;
                    end else begin
                        dividend <= {accumulator, 16'd0};
                        quotient <= 32'd0;
                        div_counter <= 5'd0;
                        state <= DIVIDE;
                    end
                end

                DIVIDE: begin
                    if (div_counter < 5'd16) begin
                        quotient <= quotient << 1;
                        dividend <= dividend << 1;
                        if (dividend[47:16] >= {29'd0, divisor}) begin
                            dividend[47:16] <= dividend[47:16] - {29'd0, divisor};
                            quotient <= quotient + 32'd1;
                        end
                        div_counter <= div_counter + 5'd1;
                    end else begin
                        result <= quotient;
                        state <= COMPLETE;
                    end
                end

                COMPLETE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule