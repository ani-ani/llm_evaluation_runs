module zero_ratio (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    input wire [3:0] len,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COUNT   = 2'd1;
    localparam [1:0] DIVIDE  = 2'd2;
    localparam [1:0] DONE_ST = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg [3:0] zero_cnt;
    reg [3:0] nonzero_cnt;
    reg [3:0] index;
    reg [31:0] dividend;
    reg [31:0] divisor;
    reg [31:0] quotient;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            zero_cnt <= 4'd0;
            nonzero_cnt <= 4'd0;
            index <= 4'd0;
            dividend <= 32'd0;
            divisor <= 32'd0;
            quotient <= 32'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COUNT;
                        zero_cnt <= 4'd0;
                        nonzero_cnt <= 4'd0;
                        index <= 4'd0;
                    end
                end

                COUNT: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (index < len) begin
                        if (arr[index] == 8'd0) begin
                            zero_cnt <= zero_cnt + 4'd1;
                        end else begin
                            nonzero_cnt <= nonzero_cnt + 4'd1;
                        end
                        index <= index + 4'd1;
                    end else begin
                        state <= DIVIDE;
                        dividend <= {16'd0, zero_cnt};
                        divisor <= {16'd0, nonzero_cnt};
                        quotient <= 32'd0;
                    end
                end

                DIVIDE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (divisor == 32'd0) begin
                        quotient <= 32'd0;
                        state <= DONE_ST;
                    end else begin
                        if (dividend >= divisor) begin
                            dividend <= dividend - divisor;
                            quotient <= quotient + 32'd1;
                        end else begin
                            state <= DONE_ST;
                            result <= quotient;
                        end
                    end
                end

                DONE_ST: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule