module LanguagePairing (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [3:0] M,
    input wire [3:0] lang1_0, lang2_0,
    input wire [3:0] lang1_1, lang2_1,
    input wire [3:0] lang1_2, lang2_2,
    input wire [3:0] lang1_3, lang2_3,
    output reg [3:0] pair1_tr1, pair1_tr2,
    output reg [3:0] pair2_tr1, pair2_tr2,
    output reg valid,
    output reg impossible
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_M = 3'd1;
    localparam [2:0] M2_CHECK = 3'd2;
    localparam [2:0] M4_CHECK1 = 3'd3;
    localparam [2:0] M4_CHECK2 = 3'd4;
    localparam [2:0] M4_CHECK3 = 3'd5;
    localparam [2:0] ODD_M = 3'd6;

    reg [2:0] state;

    function automatic logic share_language(
        input [3:0] a1, a2,
        input [3:0] b1, b2
    );
        share_language = (a1 == b1) || (a1 == b2) || (a2 == b1) || (a2 == b2);
    endfunction

    logic m2_share;
    assign m2_share = share_language(lang1_0, lang2_0, lang1_1, lang2_1);

    logic pair1_share_1, pair2_share_1;
    assign pair1_share_1 = share_language(lang1_0, lang2_0, lang1_1, lang2_1);
    assign pair2_share_1 = share_language(lang1_2, lang2_2, lang1_3, lang2_3);

    logic pair1_share_2, pair2_share_2;
    assign pair1_share_2 = share_language(lang1_0, lang2_0, lang1_2, lang2_2);
    assign pair2_share_2 = share_language(lang1_1, lang2_1, lang1_3, lang2_3);

    logic pair1_share_3, pair2_share_3;
    assign pair1_share_3 = share_language(lang1_0, lang2_0, lang1_3, lang2_3);
    assign pair2_share_3 = share_language(lang1_1, lang2_1, lang1_2, lang2_2);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 1'b0;
            impossible <= 1'b0;
            pair1_tr1 <= 4'd0;
            pair1_tr2 <= 4'd0;
            pair2_tr1 <= 4'd0;
            pair2_tr2 <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    impossible <= 1'b0;
                    if (start) begin
                        state <= CHECK_M;
                    end
                end
                CHECK_M: begin
                    if (M[0]) begin
                        state <= ODD_M;
                    end else if (M == 4'd2) begin
                        state <= M2_CHECK;
                    end else if (M == 4'd4) begin
                        state <= M4_CHECK1;
                    end else begin
                        state <= ODD_M;
                    end
                end
                M2_CHECK: begin
                    if (m2_share) begin
                        pair1_tr1 <= 4'd0;
                        pair1_tr2 <= 4'd1;
                        valid <= 1'b1;
                    end else begin
                        impossible <= 1'b1;
                    end
                    state <= IDLE;
                end
                M4_CHECK1: begin
                    if (pair1_share_1 && pair2_share_1) begin
                        pair1_tr1 <= 4'd0;
                        pair1_tr2 <= 4'd1;
                        pair2_tr1 <= 4'd2;
                        pair2_tr2 <= 4'd3;
                        valid <= 1'b1;
                    end
                    state <= M4_CHECK2;
                end
                M4_CHECK2: begin
                    if (pair1_share_2 && pair2_share_2) begin
                        pair1_tr1 <= 4'd0;
                        pair1_tr2 <= 4'd2;
                        pair2_tr1 <= 4'd1;
                        pair2_tr2 <= 4'd3;
                        valid <= 1'b1;
                    end
                    state <= M4_CHECK3;
                end
                M4_CHECK3: begin
                    if (pair1_share_3 && pair2_share_3) begin
                        pair1_tr1 <= 4'd0;
                        pair1_tr2 <= 4'd3;
                        pair2_tr1 <= 4'd1;
                        pair2_tr2 <= 4'd2;
                        valid <= 1'b1;
                    end else begin
                        impossible <= 1'b1;
                    end
                    state <= IDLE;
                end
                ODD_M: begin
                    impossible <= 1'b1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end

endmodule