module optimize_friends (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [15:0] p0, p1, p2, p3, p4, p5, p6, p7,
    output reg [31:0] result,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK = 3'd1;
    localparam [2:0] SORT = 3'd2;
    localparam [2:0] INIT = 3'd3;
    localparam [2:0] LOOP = 3'd4;
    localparam [2:0] DONE = 3'd5;

    reg [2:0] state;
    reg [31:0] prob [0:7];
    wire [31:0] one = 32'hFFFFFFFF;
    reg [31:0] s, p, a;
    reg [2:0] i, j, k;

    wire [63:0] product1 = s * (one - a);
    wire [63:0] product2 = a * p;
    wire [63:0] product3 = p * (one - a);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            i <= 3'd0;
            j <= 3'd0;
            k <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= CHECK;
                        prob[0] <= {p0, 16'd0};
                        prob[1] <= {p1, 16'd0};
                        prob[2] <= {p2, 16'd0};
                        prob[3] <= {p3, 16'd0};
                        prob[4] <= {p4, 16'd0};
                        prob[5] <= {p5, 16'd0};
                        prob[6] <= {p6, 16'd0};
                        prob[7] <= {p7, 16'd0};
                    end
                end
                CHECK: begin
                    if (p0 == 16'hFFFF || p1 == 16'hFFFF || p2 == 16'hFFFF || p3 == 16'hFFFF ||
                        p4 == 16'hFFFF || p5 == 16'hFFFF || p6 == 16'hFFFF || p7 == 16'hFFFF) begin
                        result <= 32'hFFFFFFFF;
                        done <= 1'b1;
                        state <= IDLE;
                    end else begin
                        state <= SORT;
                        j <= 3'd0;
                        k <= 3'd0;
                    end
                end
                SORT: begin
                    if (j < n) begin
                        if (k < n - j - 1) begin
                            if (prob[k] < prob[k+1]) begin
                                prob[k] <= prob[k+1];
                                prob[k+1] <= prob[k];
                            end
                            k <= k + 3'd1;
                        end else begin
                            k <= 3'd0;
                            j <= j + 3'd1;
                        end
                    end else begin
                        state <= INIT;
                        i <= n - 3'd2;
                    end
                end
                INIT: begin
                    s <= prob[n-1];
                    p <= one - prob[n-1];
                    state <= LOOP;
                end
                LOOP: begin
                    if (i >= 0) begin
                        a <= prob[i];
                        if (((product1 + product2) >> 32) > s) begin
                            s <= (product1 + product2) >> 32;
                            p <= product3 >> 32;
                        end
                        i <= i - 3'd1;
                    end else begin
                        state <= DONE;
                        result <= s;
                        done <= 1'b1;
                    end
                end
                DONE: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule