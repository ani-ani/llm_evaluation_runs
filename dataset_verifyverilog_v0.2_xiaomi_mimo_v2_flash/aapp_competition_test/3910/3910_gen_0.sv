module arpa_food_solver(
    input [3:0] pair0_boy_chair,
    input [3:0] pair0_girl_chair,
    input [3:0] pair1_boy_chair,
    input [3:0] pair1_girl_chair,
    input [3:0] pair2_boy_chair,
    input [3:0] pair2_girl_chair,
    input [3:0] pair3_boy_chair,
    input [3:0] pair3_girl_chair,
    output reg [1:0] pair0_food,
    output reg [1:0] pair1_food,
    output reg [1:0] pair2_food,
    output reg [1:0] pair3_food,
    output reg valid
);

    integer i;
    reg [7:0] food;
    reg [3:0] b_idx [3:0];
    reg [3:0] g_idx [3:0];
    reg [2:0] f0, f1, f2, f3, f4, f5, f6, f7;
    reg v;
    reg [1:0] p0, p1, p2, p3;

    always @(*) begin
        b_idx[0] = pair0_boy_chair;
        g_idx[0] = pair0_girl_chair;
        b_idx[1] = pair1_boy_chair;
        g_idx[1] = pair1_girl_chair;
        b_idx[2] = pair2_boy_chair;
        g_idx[2] = pair2_girl_chair;
        b_idx[3] = pair3_boy_chair;
        g_idx[3] = pair3_girl_chair;

        v = 0;
        p0 = 2'b00; p1 = 2'b00; p2 = 2'b00; p3 = 2'b00;

        for (i = 0; i < 256; i = i + 1) begin
            if (!v) begin
                food = i[7:0];
                f0 = {1'b0, food[0]};
                f1 = {1'b0, food[1]};
                f2 = {1'b0, food[2]};
                f3 = {1'b0, food[3]};
                f4 = {1'b0, food[4]};
                f5 = {1'b0, food[5]};
                f6 = {1'b0, food[6]};
                f7 = {1'b0, food[7]};

                if ((f0 != f1 && f1 != f2 && f0 != f2) || (f1 != f2 && f2 != f3 && f1 != f3) ||
                    (f2 != f3 && f3 != f4 && f2 != f4) || (f3 != f4 && f4 != f5 && f3 != f5) ||
                    (f4 != f5 && f5 != f6 && f4 != f6) || (f5 != f6 && f6 != f7 && f5 != f7) ||
                    (f6 != f7 && f7 != f0 && f6 != f0) || (f7 != f0 && f0 != f1 && f7 != f1)) begin
                end else begin
                    v = 1;
                    p0 = (food[b_idx[0]] ? 2'b10 : 2'b01);
                    p0 = (food[g_idx[0]] ? {p0[1], 1'b0} : {p0[1], 1'b1});
                    p1 = (food[b_idx[1]] ? 2'b10 : 2'b01);
                    p1 = (food[g_idx[1]] ? {p1[1], 1'b0} : {p1[1], 1'b1});
                    p2 = (food[b_idx[2]] ? 2'b10 : 2'b01);
                    p2 = (food[g_idx[2]] ? {p2[1], 1'b0} : {p2[1], 1'b1});
                    p3 = (food[b_idx[3]] ? 2'b10 : 2'b01);
                    p3 = (food[g_idx[3]] ? {p3[1], 1'b0} : {p3[1], 1'b1});
                end
            end
        end
        
        valid = v;
        pair0_food = p0;
        pair1_food = p1;
        pair2_food = p2;
        pair3_food = p3;
    end

endmodule
