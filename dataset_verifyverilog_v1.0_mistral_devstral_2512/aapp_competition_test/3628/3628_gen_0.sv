module find_permutations(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [7:0] a_0,
    input [7:0] a_1,
    input [7:0] a_2,
    input [7:0] a_3,
    input [7:0] a_4,
    input [7:0] a_5,
    input [7:0] a_6,
    input [7:0] a_7,
    output reg [7:0] pi_0,
    output reg [7:0] pi_1,
    output reg [7:0] pi_2,
    output reg [7:0] pi_3,
    output reg [7:0] pi_4,
    output reg [7:0] pi_5,
    output reg [7:0] pi_6,
    output reg [7:0] pi_7,
    output reg [7:0] sigma_0,
    output reg [7:0] sigma_1,
    output reg [7:0] sigma_2,
    output reg [7:0] sigma_3,
    output reg [7:0] sigma_4,
    output reg [7:0] sigma_5,
    output reg [7:0] sigma_6,
    output reg [7:0] sigma_7,
    output reg done,
    output reg impossible
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SEARCH = 3'd1;
    localparam [2:0] DONE = 3'd2;
    localparam [2:0] IMPOSSIBLE = 3'd3;

    reg [2:0] state;
    reg [3:0] depth;
    reg [7:0] used_pi;
    reg [7:0] used_sigma;
    reg [7:0] next_candidate;
    reg [7:0] pi_reg [0:7];
    reg [7:0] sigma_reg [0:7];
    reg [7:0] c [0:7];
    reg [7:0] a_reg [0:7];
    reg [3:0] n_reg;
    reg found;
    reg [7:0] i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            depth <= 4'd0;
            used_pi <= 8'd0;
            used_sigma <= 8'd0;
            next_candidate <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                pi_reg[i] <= 8'd0;
                sigma_reg[i] <= 8'd0;
                c[i] <= 8'd0;
                a_reg[i] <= 8'd0;
            end
            n_reg <= 4'd0;
            found <= 1'b0;
            done <= 1'b0;
            impossible <= 1'b0;
            pi_0 <= 8'd0;
            pi_1 <= 8'd0;
            pi_2 <= 8'd0;
            pi_3 <= 8'd0;
            pi_4 <= 8'd0;
            pi_5 <= 8'd0;
            pi_6 <= 8'd0;
            pi_7 <= 8'd0;
            sigma_0 <= 8'd0;
            sigma_1 <= 8'd0;
            sigma_2 <= 8'd0;
            sigma_3 <= 8'd0;
            sigma_4 <= 8'd0;
            sigma_5 <= 8'd0;
            sigma_6 <= 8'd0;
            sigma_7 <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    impossible <= 1'b0;
                    if (start) begin
                        n_reg <= n;
                        a_reg[0] <= a_0;
                        a_reg[1] <= a_1;
                        a_reg[2] <= a_2;
                        a_reg[3] <= a_3;
                        a_reg[4] <= a_4;
                        a_reg[5] <= a_5;
                        a_reg[6] <= a_6;
                        a_reg[7] <= a_7;
                        for (i = 0; i < 8; i = i + 1) begin
                            if (a_reg[i] == 1) begin
                                c[i] <= n_reg - 1;
                            end else begin
                                c[i] <= a_reg[i] - 2;
                            end
                        end
                        depth <= 4'd0;
                        used_pi <= 8'd0;
                        used_sigma <= 8'd0;
                        next_candidate <= 8'd0;
                        found <= 1'b0;
                        state <= SEARCH;
                    end
                end

                SEARCH: begin
                    if (depth == n_reg) begin
                        found <= 1'b1;
                        state <= DONE;
                    end else begin
                        if (next_candidate == n_reg) begin
                            if (depth == 4'd0) begin
                                state <= IMPOSSIBLE;
                            end else begin
                                depth <= depth - 4'd1;
                                used_pi <= used_pi - {7'd0, pi_reg[depth]};
                                used_sigma <= used_sigma - {7'd0, sigma_reg[depth]};
                                next_candidate <= pi_reg[depth] + 8'd1;
                            end
                        end else begin
                            if (!(used_pi[next_candidate])) begin
                                pi_reg[depth] <= next_candidate;
                                sigma_reg[depth] <= (c[depth] - next_candidate) % n_reg;
                                if (!(used_sigma[sigma_reg[depth]])) begin
                                    used_pi <= used_pi | {7'd0, next_candidate};
                                    used_sigma <= used_sigma | {7'd0, sigma_reg[depth]};
                                    depth <= depth + 4'd1;
                                    next_candidate <= 8'd0;
                                end else begin
                                    next_candidate <= next_candidate + 8'd1;
                                end
                            end else begin
                                next_candidate <= next_candidate + 8'd1;
                            end
                        end
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    impossible <= 1'b0;
                    pi_0 <= pi_reg[0];
                    pi_1 <= pi_reg[1];
                    pi_2 <= pi_reg[2];
                    pi_3 <= pi_reg[3];
                    pi_4 <= pi_reg[4];
                    pi_5 <= pi_reg[5];
                    pi_6 <= pi_reg[6];
                    pi_7 <= pi_reg[7];
                    sigma_0 <= sigma_reg[0];
                    sigma_1 <= sigma_reg[1];
                    sigma_2 <= sigma_reg[2];
                    sigma_3 <= sigma_reg[3];
                    sigma_4 <= sigma_reg[4];
                    sigma_5 <= sigma_reg[5];
                    sigma_6 <= sigma_reg[6];
                    sigma_7 <= sigma_reg[7];
                    state <= IDLE;
                end

                IMPOSSIBLE: begin
                    done <= 1'b1;
                    impossible <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule