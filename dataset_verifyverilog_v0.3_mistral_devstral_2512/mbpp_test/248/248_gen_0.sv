module harmonic_sum (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALC_START = 3'd1;
    localparam [2:0] DIVIDE = 3'd2;
    localparam [2:0] ACCUMULATE = 3'd3;
    localparam [2:0] COMPLETE = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [7:0] counter;
    reg [15:0] accumulator;
    reg [15:0] divisor;
    reg [7:0] iterations_remaining;
    reg division_done;

    // Precomputed reciprocal lookup table (Q8.8 format)
    reg [15:0] reciprocal_lut [0:255];

    // Initialize LUT
    integer i;
    initial begin
        reciprocal_lut[0] = 16'hFFFF;
        reciprocal_lut[1] = 16'h0100;
        reciprocal_lut[2] = 16'h0080;
        reciprocal_lut[3] = 16'h0055;
        reciprocal_lut[4] = 16'h0040;
        reciprocal_lut[5] = 16'h0033;
        reciprocal_lut[6] = 16'h002A;
        reciprocal_lut[7] = 16'h0024;
        reciprocal_lut[8] = 16'h0020;
        reciprocal_lut[9] = 16'h001C;
        reciprocal_lut[10] = 16'h0019;
        for (i = 11; i <= 255; i = i + 1) begin
            reciprocal_lut[i] = (256 * 256) / i;
        end
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            accumulator <= 16'd0;
            counter <= 8'd0;
            divisor <= 16'd0;
            iterations_remaining <= 8'd0;
            division_done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        accumulator <= 16'd0;
                        counter <= n;
                        state <= CALC_START;
                    end
                end

                CALC_START: begin
                    if (counter >= 8'd2) begin
                        divisor <= reciprocal_lut[counter];
                        iterations_remaining <= 120;
                        division_done <= 1'b0;
                        state <= DIVIDE;
                    end else begin
                        accumulator <= accumulator + 16'h0100;
                        state <= COMPLETE;
                    end
                end

                DIVIDE: begin
                    if (iterations_remaining > 8'd0) begin
                        iterations_remaining <= iterations_remaining - 8'd1;
                        division_done <= 1'b0;
                    end else begin
                        division_done <= 1'b1;
                    end

                    if (division_done) begin
                        state <= ACCUMULATE;
                    end
                end

                ACCUMULATE: begin
                    accumulator <= accumulator + divisor;
                    counter <= counter - 8'd1;
                    state <= CALC_START;
                end

                COMPLETE: begin
                    result <= accumulator;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule