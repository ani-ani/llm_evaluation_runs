module triangle_ways (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] a,
    input wire [4:0] b,
    input wire [4:0] c,
    input wire [4:0] l,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_TOTAL = 3'd1;
    localparam [2:0] COMPUTE_A = 3'd2;
    localparam [2:0] COMPUTE_B = 3'd3;
    localparam [2:0] COMPUTE_C = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    reg [2:0] state;
    reg [4:0] x;
    reg [15:0] total;
    reg [15:0] count_invalid_a;
    reg [15:0] count_invalid_b;
    reg [15:0] count_invalid_c;
    reg [4:0] delta_a;
    reg [4:0] delta_b;
    reg [4:0] delta_c;
    reg [4:0] M;
    reg [15:0] term;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            x <= 5'd0;
            total <= 16'd0;
            count_invalid_a <= 16'd0;
            count_invalid_b <= 16'd0;
            count_invalid_c <= 16'd0;
            delta_a <= 5'd0;
            delta_b <= 5'd0;
            delta_c <= 5'd0;
            M <= 5'd0;
            term <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE_TOTAL;
                    end
                end

                COMPUTE_TOTAL: begin
                    // Compute total = (l+3)*(l+2)*(l+1)/6
                    total <= ((l + 5'd3) * (l + 5'd2) * (l + 5'd1)) / 6'd6;
                    delta_a <= a - b - c;
                    delta_b <= b - a - c;
                    delta_c <= c - a - b;
                    state <= COMPUTE_A;
                end

                COMPUTE_A: begin
                    if (x <= l) begin
                        if (x >= delta_a) begin
                            M <= (l - x) < (x - delta_a) ? (l - x) : (x - delta_a);
                            term <= (M + 5'd1) * (M + 5'd2) / 2'd2;
                            count_invalid_a <= count_invalid_a + term;
                        end
                        x <= x + 5'd1;
                    end else begin
                        x <= 5'd0;
                        state <= COMPUTE_B;
                    end
                end

                COMPUTE_B: begin
                    if (x <= l) begin
                        if (x >= delta_b) begin
                            M <= (l - x) < (x - delta_b) ? (l - x) : (x - delta_b);
                            term <= (M + 5'd1) * (M + 5'd2) / 2'd2;
                            count_invalid_b <= count_invalid_b + term;
                        end
                        x <= x + 5'd1;
                    end else begin
                        x <= 5'd0;
                        state <= COMPUTE_C;
                    end
                end

                COMPUTE_C: begin
                    if (x <= l) begin
                        if (x >= delta_c) begin
                            M <= (l - x) < (x - delta_c) ? (l - x) : (x - delta_c);
                            term <= (M + 5'd1) * (M + 5'd2) / 2'd2;
                            count_invalid_c <= count_invalid_c + term;
                        end
                        x <= x + 5'd1;
                    end else begin
                        result <= total - count_invalid_a - count_invalid_b - count_invalid_c;
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule