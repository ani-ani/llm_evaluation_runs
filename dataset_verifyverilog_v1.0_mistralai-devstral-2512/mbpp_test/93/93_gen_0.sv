module power_calc(
    input clk,
    input rst_n,
    input start,
    input [7:0] a,
    input [3:0] b,
    output reg [15:0] result,
    output reg done,
    output reg overflow
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALCULATING = 2'd1;
    localparam [1:0] DONE = 2'd2;

    // Registers
    reg [1:0] state_r;
    reg [3:0] counter_r;
    reg [7:0] base_r;
    reg [15:0] result_r;
    reg [3:0] exp_r;
    reg overflow_r;

    // Multiplication and overflow detection
    wire [15:0] mult_result;
    wire overflow_detected;

    assign mult_result = result_r * base_r;
    assign overflow_detected = (mult_result > 16'd65535) || (result_r > 16'd8191 && base_r > 8'd1);

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_r <= IDLE;
            counter_r <= 4'd0;
            base_r <= 8'd0;
            result_r <= 16'd0;
            exp_r <= 4'd0;
            overflow_r <= 1'b0;
            result <= 16'd0;
            done <= 1'b0;
            overflow <= 1'b0;
        end else begin
            case (state_r)
                IDLE: begin
                    done <= 1'b0;
                    overflow <= 1'b0;
                    if (start) begin
                        base_r <= a;
                        exp_r <= b;
                        if (b == 4'd0) begin
                            result_r <= 16'd1;
                            state_r <= DONE;
                        end else if (a == 8'd0) begin
                            result_r <= 16'd0;
                            state_r <= DONE;
                        end else begin
                            result_r <= 16'd1;
                            counter_r <= 4'd0;
                            state_r <= CALCULATING;
                        end
                    end
                end

                CALCULATING: begin
                    if (overflow_detected) begin
                        overflow_r <= 1'b1;
                        result_r <= 16'd65535;
                        state_r <= DONE;
                    end else if (counter_r == exp_r - 4'd1) begin
                        result_r <= mult_result;
                        state_r <= DONE;
                    end else begin
                        result_r <= mult_result;
                        counter_r <= counter_r + 4'd1;
                    end
                end

                DONE: begin
                    result <= result_r;
                    done <= 1'b1;
                    overflow <= overflow_r;
                    state_r <= IDLE;
                end

                default: state_r <= IDLE;
            endcase
        end
    end

endmodule