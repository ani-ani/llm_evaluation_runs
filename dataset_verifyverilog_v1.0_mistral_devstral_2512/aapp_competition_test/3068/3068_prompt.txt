module black_vienna_solver(
    input wire [2:0] n,
    input wire [6:0] inv0,
    input wire [6:0] inv1,
    input wire [6:0] inv2,
    input wire [6:0] inv3,
    input wire [6:0] inv4,
    output reg [2:0] count
);

// Precomputed masks for 4 suspects (A=0, B=1, C=2, D=3) and 8 assignments
reg [3:0] p1_mask [0:7];
reg [3:0] p2_mask [0:7];

initial begin
    // Assignment 0: x=A, p=0 -> P1: A, P2: none
    p1_mask[0] = 4'b0001; p2_mask[0] = 4'b0000;
    // Assignment 1: x=A, p=1 -> P1: none, P2: A
    p1_mask[1] = 4'b0000; p2_mask[1] = 4'b0001;
    // Assignment 2: x=B, p=0 -> P1: B, P2: none
    p1_mask[2] = 4'b0010; p2_mask[2] = 4'b0000;
    // Assignment 3: x=B, p=1 -> P1: none, P2: B
    p1_mask[3] = 4'b0000; p2_mask[3] = 4'b0010;
    // Assignment 4: x=C, p=0 -> P1: C, P2: none
    p1_mask[4] = 4'b0100; p2_mask[4] = 4'b0000;
    // Assignment 5: x=C, p=1 -> P1: none, P2: C
    p1_mask[5] = 4'b0000; p2_mask[5] = 4'b0100;
    // Assignment 6: x=D, p=0 -> P1: D, P2: none
    p1_mask[6] = 4'b1000; p2_mask[6] = 4'b0000;
    // Assignment 7: x=D, p=1 -> P1: none, P2: D
    p1_mask[7] = 4'b0000; p2_mask[7] = 4'b1000;
end

// Decode investigations
wire [1:0] letter1 [0:4];
wire [1:0] letter2 [0:4];
wire player [0:4];
wire [1:0] reply [0:4];

assign letter1[0] = inv0[6:5];
assign letter2[0] = inv0[4:3];
assign player[0] = inv0[2];
assign reply[0] = inv0[1:0];

assign letter1[1] = inv1[6:5];
assign letter2[1] = inv1[4:3];
assign player[1] = inv1[2];
assign reply[1] = inv1[1:0];

assign letter1[2] = inv2[6:5];
assign letter2[2] = inv2[4:3];
assign player[2] = inv2[2];
assign reply[2] = inv2[1:0];

assign letter1[3] = inv3[6:5];
assign letter2[3] = inv3[4:3];
assign player[3] = inv3[2];
assign reply[3] = inv3[1:0];

assign letter1[4] = inv4[6:5];
assign letter2[4] = inv4[4:3];
assign player[4] = inv4[2];
assign reply[4] = inv4[1:0];

// For each assignment, compute valid flag
reg valid [0:7];

integer a, i;
reg [3:0] mask;
reg [1:0] count_val;
reg cond_i;

always @(*) begin
    for (a = 0; a < 8; a = a + 1) begin
        valid[a] = 1'b1;
        for (i = 0; i < 5; i = i + 1) begin
            if (i < n) begin
                // Determine mask based on player
                if (player[i] == 1'b0) begin
                    mask = p1_mask[a];
                end else begin
                    mask = p2_mask[a];
                end
                // Count how many of the two letters are in the mask
                count_val = 0;
                if (mask[letter1[i]]) count_val = count_val + 1;
                if (mask[letter2[i]]) count_val = count_val + 1;
                cond_i = (count_val == reply[i]);
                if (!cond_i) begin
                    valid[a] = 1'b0;
                end
            end
        end
    end
end

// Count the number of valid assignments
always @(*) begin
    count = 0;
    for (a = 0; a < 8; a = a + 1) begin
        if (valid[a]) begin
            count = count + 1;
        end
    end
end

endmodule