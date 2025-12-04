module harmonic_sum(
    input clk,
    input rst_n,
    input start,
    input [3:0] n_in,
    output reg [15:0] sum,
    output reg done
);

    typedef enum logic {IDLE, CALC} state_t;
    state_t state, next_state;
    reg [3:0] clamped_n, k;
    wire [15:0] recip;

    always_comb begin
        case(k)
            4'd1:  recip = 16'h0100;
            4'd2:  recip = 16'h0080;
            4'd3:  recip = 16'h0055;
            4'd4:  recip = 16'h0040;
            4'd5:  recip = 16'h0033;
            4'd6:  recip = 16'h002B;
            4'd7:  recip = 16'h0025;
            4'd8:  recip = 16'h0020;
            4'd9:  recip = 16'h001C;
            4'd10: recip = 16'h001A;
            4'd11: recip = 16'h0017;
            4'd12: recip = 16'h0015;
            4'd13: recip = 16'h0014;
            4'd14: recip = 16'h0012;
            4'd15: recip = 16'h0011;
            default: recip = 16'h0000;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sum <= 16'd0;
            done <= 1'b0;
            clamped_n <= 4'd2;
            k <= 4'd1;
        end else begin
            case(state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        clamped_n <= (n_in < 4'd2) ? 4'd2 : n_in;
                        k <= 4'd1;
                        sum <= 16'd0;
                        state <= CALC;
                    end
                end

                CALC: begin
                    sum <= sum + recip;
                    k <= k + 4'd1;
                    if (k + 1 == clamped_n) begin
                        state <= IDLE;
                        done <= 1'b1;
                    end
                end
            endcase
        end
    end
endmodule