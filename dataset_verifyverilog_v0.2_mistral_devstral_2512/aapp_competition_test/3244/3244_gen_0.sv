module ring_reconstruct (
    input clk,
    input rst_n,
    input start,
    input [2:0] valid_count,
    input [31:0] b0, b1, b2, b3, b4, b5, b6, b7,
    output reg [31:0] a0, a1, a2, a3, a4, a5, a6, a7,
    output reg done,
    output reg error
);

    parameter N = 8;
    parameter WIDTH = 32;

    typedef enum logic [2:0] {
        IDLE,
        INIT,
        CHECK,
        ADJUST,
        OUTPUT
    } state_t;

    state_t state;
    reg [WIDTH-1:0] a0_temp, a1_temp, a2_temp, a3_temp, a4_temp, a5_temp, a6_temp, a7_temp;
    reg [WIDTH-1:0] d, k;
    reg [3:0] cycle_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 0;
            done <= 0;
            error <= 0;
            a0 <= 0; a1 <= 0; a2 <= 0; a3 <= 0; a4 <= 0; a5 <= 0; a6 <= 0; a7 <= 0;
            a0_temp <= 0; a1_temp <= 0; a2_temp <= 0; a3_temp <= 0; a4_temp <= 0; a5_temp <= 0; a6_temp <= 0; a7_temp <= 0;
            d <= 0;
            k <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= INIT;
                        cycle_count <= 1;
                        done <= 0;
                        error <= 0;
                    end
                end
                INIT: begin
                    if (cycle_count == 1) begin
                        a0_temp <= 0;
                        a1_temp <= b0 - a0_temp;
                        a2_temp <= b1 - a1_temp - a0_temp;
                        a3_temp <= b2 - a2_temp - a1_temp;
                        a4_temp <= b3 - a3_temp - a2_temp;
                        a5_temp <= b4 - a4_temp - a3_temp;
                        a6_temp <= b5 - a5_temp - a4_temp;
                        a7_temp <= b6 - a6_temp - a5_temp;
                        cycle_count <= cycle_count + 1;
                    end else if (cycle_count == 2) begin
                        state <= CHECK;
                        cycle_count <= 3;
                    end
                end
                CHECK: begin
                    if (cycle_count == 3) begin
                        d <= (a7_temp + a0_temp + a1_temp - b7);
                        cycle_count <= cycle_count + 1;
                    end else if (cycle_count == 4) begin
                        if (N % 2 == 0) begin
                            k <= d / (N/2);
                        end else begin
                            k <= 0;
                        end
                        cycle_count <= cycle_count + 1;
                    end else if (cycle_count == 5) begin
                        state <= ADJUST;
                        cycle_count <= 6;
                    end
                end
                ADJUST: begin
                    if (cycle_count == 6) begin
                        a0_temp <= a0_temp + k;
                        a1_temp <= a1_temp - k;
                        a2_temp <= a2_temp + k;
                        a3_temp <= a3_temp - k;
                        a4_temp <= a4_temp + k;
                        a5_temp <= a5_temp - k;
                        a6_temp <= a6_temp + k;
                        a7_temp <= a7_temp - k;
                        cycle_count <= cycle_count + 1;
                    end else if (cycle_count == 7) begin
                        if (a0_temp[WIDTH-1] || a1_temp[WIDTH-1] || a2_temp[WIDTH-1] || a3_temp[WIDTH-1] || 
                            a4_temp[WIDTH-1] || a5_temp[WIDTH-1] || a6_temp[WIDTH-1] || a7_temp[WIDTH-1]) begin
                            error <= 1;
                        end
                        cycle_count <= cycle_count + 1;
                    end else if (cycle_count == 10) begin
                        state <= OUTPUT;
                        cycle_count <= 11;
                    end else begin
                        cycle_count <= cycle_count + 1;
                    end
                end
                OUTPUT: begin
                    if (cycle_count == 11) begin
                        a0 <= a0_temp;
                        a1 <= a1_temp;
                        a2 <= a2_temp;
                        a3 <= a3_temp;
                        a4 <= a4_temp;
                        a5 <= a5_temp;
                        a6 <= a6_temp;
                        a7 <= a7_temp;
                        done <= 1;
                        cycle_count <= cycle_count + 1;
                    end else if (cycle_count == 15) begin
                        state <= IDLE;
                        cycle_count <= 0;
                        done <= 0;
                    end else begin
                        cycle_count <= cycle_count + 1;
                    end
                end
            endcase
        end
    end

endmodule