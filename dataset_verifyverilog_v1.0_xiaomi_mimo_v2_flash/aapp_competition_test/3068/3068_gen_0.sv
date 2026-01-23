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
reg [3:0] p1_mask_0;
reg [3:0] p2_mask_0;
reg [3:0] p1_mask_1;
reg [3:0] p2_mask_1;
reg [3:0] p1_mask_2;
reg [3:0] p2_mask_2;
reg [3:0] p1_mask_3;
reg [3:0] p2_mask_3;
reg [3:0] p1_mask_4;
reg [3:0] p2_mask_4;
reg [3:0] p1_mask_5;
reg [3:0] p2_mask_5;
reg [3:0] p1_mask_6;
reg [3:0] p2_mask_6;
reg [3:0] p1_mask_7;
reg [3:0] p2_mask_7;

always @(*) begin
    // Assignment 0: x=A, p=0 -> P1: A, P2: none
    p1_mask_0 = 4'b0001;
    p2_mask_0 = 4'b0000;
    // Assignment 1: x=A, p=1 -> P1: none, P2: A
    p1_mask_1 = 4'b0000;
    p2_mask_1 = 4'b0001;
    // Assignment 2: x=B, p=0 -> P1: B, P2: none
    p1_mask_2 = 4'b0010;
    p2_mask_2 = 4'b0000;
    // Assignment 3: x=B, p=1 -> P1: none, P2: B
    p1_mask_3 = 4'b0000;
    p2_mask_3 = 4'b0010;
    // Assignment 4: x=C, p=0 -> P1: C, P2: none
    p1_mask_4 = 4'b0100;
    p2_mask_4 = 4'b0000;
    // Assignment 5: x=C, p=1 -> P1: none, P2: C
    p1_mask_5 = 4'b0000;
    p2_mask_5 = 4'b0100;
    // Assignment 6: x=D, p=0 -> P1: D, P2: none
    p1_mask_6 = 4'b1000;
    p2_mask_6 = 4'b0000;
    // Assignment 7: x=D, p=1 -> P1: none, P2: D
    p1_mask_7 = 4'b0000;
    p2_mask_7 = 4'b1000;
end

// Decode investigations
wire [1:0] letter1_0;
wire [1:0] letter2_0;
wire player_0;
wire [1:0] reply_0;

wire [1:0] letter1_1;
wire [1:0] letter2_1;
wire player_1;
wire [1:0] reply_1;

wire [1:0] letter1_2;
wire [1:0] letter2_2;
wire player_2;
wire [1:0] reply_2;

wire [1:0] letter1_3;
wire [1:0] letter2_3;
wire player_3;
wire [1:0] reply_3;

wire [1:0] letter1_4;
wire [1:0] letter2_4;
wire player_4;
wire [1:0] reply_4;

assign letter1_0 = inv0[6:5];
assign letter2_0 = inv0[4:3];
assign player_0 = inv0[2];
assign reply_0 = inv0[1:0];

assign letter1_1 = inv1[6:5];
assign letter2_1 = inv1[4:3];
assign player_1 = inv1[2];
assign reply_1 = inv1[1:0];

assign letter1_2 = inv2[6:5];
assign letter2_2 = inv2[4:3];
assign player_2 = inv2[2];
assign reply_2 = inv2[1:0];

assign letter1_3 = inv3[6:5];
assign letter2_3 = inv3[4:3];
assign player_3 = inv3[2];
assign reply_3 = inv3[1:0];

assign letter1_4 = inv4[6:5];
assign letter2_4 = inv4[4:3];
assign player_4 = inv4[2];
assign reply_4 = inv4[1:0];

// For each assignment, compute valid flag
reg valid_0;
reg valid_1;
reg valid_2;
reg valid_3;
reg valid_4;
reg valid_5;
reg valid_6;
reg valid_7;

always @(*) begin
    // Assignment 0 check
    valid_0 = 1'b1;
    if (n > 3'd0) begin
        valid_0 = check_assignment(1'b0, letter1_0, letter2_0, reply_0, p1_mask_0, p2_mask_0);
    end
    if (n > 3'd1 && valid_0) begin
        valid_0 = check_assignment(player_1, letter1_1, letter2_1, reply_1, p1_mask_0, p2_mask_0);
    end
    if (n > 3'd2 && valid_0) begin
        valid_0 = check_assignment(player_2, letter1_2, letter2_2, reply_2, p1_mask_0, p2_mask_0);
    end
    if (n > 3'd3 && valid_0) begin
        valid_0 = check_assignment(player_3, letter1_3, letter2_3, reply_3, p1_mask_0, p2_mask_0);
    end
    if (n > 3'd4 && valid_0) begin
        valid_0 = check_assignment(player_4, letter1_4, letter2_4, reply_4, p1_mask_0, p2_mask_0);
    end

    // Assignment 1 check
    valid_1 = 1'b1;
    if (n > 3'd0) begin
        valid_1 = check_assignment(1'b0, letter1_0, letter2_0, reply_0, p1_mask_1, p2_mask_1);
    end
    if (n > 3'd1 && valid_1) begin
        valid_1 = check_assignment(player_1, letter1_1, letter2_1, reply_1, p1_mask_1, p2_mask_1);
    end
    if (n > 3'd2 && valid_1) begin
        valid_1 = check_assignment(player_2, letter1_2, letter2_2, reply_2, p1_mask_1, p2_mask_1);
    end
    if (n > 3'd3 && valid_1) begin
        valid_1 = check_assignment(player_3, letter1_3, letter2_3, reply_3, p1_mask_1, p2_mask_1);
    end
    if (n > 3'd4 && valid_1) begin
        valid_1 = check_assignment(player_4, letter1_4, letter2_4, reply_4, p1_mask_1, p2_mask_1);
    end

    // Assignment 2 check
    valid_2 = 1'b1;
    if (n > 3'd0) begin
        valid_2 = check_assignment(1'b0, letter1_0, letter2_0, reply_0, p1_mask_2, p2_mask_2);
    end
    if (n > 3'd1 && valid_2) begin
        valid_2 = check_assignment(player_1, letter1_1, letter2_1, reply_1, p1_mask_2, p2_mask_2);
    end
    if (n > 3'd2 && valid_2) begin
        valid_2 = check_assignment(player_2, letter1_2, letter2_2, reply_2, p1_mask_2, p2_mask_2);
    end
    if (n > 3'd3 && valid_2) begin
        valid_2 = check_assignment(player_3, letter1_3, letter2_3, reply_3, p1_mask_2, p2_mask_2);
    end
    if (n > 3'd4 && valid_2) begin
        valid_2 = check_assignment(player_4, letter1_4, letter2_4, reply_4, p1_mask_2, p2_mask_2);
    end

    // Assignment 3 check
    valid_3 = 1'b1;
    if (n > 3'd0) begin
        valid_3 = check_assignment(1'b0, letter1_0, letter2_0, reply_0, p1_mask_3, p2_mask_3);
    end
    if (n > 3'd1 && valid_3) begin
        valid_3 = check_assignment(player_1, letter1_1, letter2_1, reply_1, p1_mask_3, p2_mask_3);
    end
    if (n > 3'd2 && valid_3) begin
        valid_3 = check_assignment(player_2, letter1_2, letter2_2, reply_2, p1_mask_3, p2_mask_3);
    end
    if (n > 3'd3 && valid_3) begin
        valid_3 = check_assignment(player_3, letter1_3, letter2_3, reply_3, p1_mask_3, p2_mask_3);
    end
    if (n > 3'd4 && valid_3) begin
        valid_3 = check_assignment(player_4, letter1_4, letter2_4, reply_4, p1_mask_3, p2_mask_3);
    end

    // Assignment 4 check
    valid_4 = 1'b1;
    if (n > 3'd0) begin
        valid_4 = check_assignment(1'b0, letter1_0, letter2_0, reply_0, p1_mask_4, p2_mask_4);
    end
    if (n > 3'd1 && valid_4) begin
        valid_4 = check_assignment(player_1, letter1_1, letter2_1, reply_1, p1_mask_4, p2_mask_4);
    end
    if (n > 3'd2 && valid_4) begin
        valid_4 = check_assignment(player_2, letter1_2, letter2_2, reply_2, p1_mask_4, p2_mask_4);
    end
    if (n > 3'd3 && valid_4) begin
        valid_4 = check_assignment(player_3, letter1_3, letter2_3, reply_3, p1_mask_4, p2_mask_4);
    end
    if (n > 3'd4 && valid_4) begin
        valid_4 = check_assignment(player_4, letter1_4, letter2_4, reply_4, p1_mask_4, p2_mask_4);
    end

    // Assignment 5 check
    valid_5 = 1'b1;
    if (n > 3'd0) begin
        valid_5 = check_assignment(1'b0, letter1_0, letter2_0, reply_0, p1_mask_5, p2_mask_5);
    end
    if (n > 3'd1 && valid_5) begin
        valid_5 = check_assignment(player_1, letter1_1, letter2_1, reply_1, p1_mask_5, p2_mask_5);
    end
    if (n > 3'd2 && valid_5) begin
        valid_5 = check_assignment(player_2, letter1_2, letter2_2, reply_2, p1_mask_5, p2_mask_5);
    end
    if (n > 3'd3 && valid_5) begin
        valid_5 = check_assignment(player_3, letter1_3, letter2_3, reply_3, p1_mask_5, p2_mask_5);
    end
    if (n > 3'd4 && valid_5) begin
        valid_5 = check_assignment(player_4, letter1_4, letter2_4, reply_4, p1_mask_5, p2_mask_5);
    end

    // Assignment 6 check
    valid_6 = 1'b1;
    if (n > 3'd0) begin
        valid_6 = check_assignment(1'b0, letter1_0, letter2_0, reply_0, p1_mask_6, p2_mask_6);
    end
    if (n > 3'd1 && valid_6) begin
        valid_6 = check_assignment(player_1, letter1_1, letter2_1, reply_1, p1_mask_6, p2_mask_6);
    end
    if (n > 3'd2 && valid_6) begin
        valid_6 = check_assignment(player_2, letter1_2, letter2_2, reply_2, p1_mask_6, p2_mask_6);
    end
    if (n > 3'd3 && valid_6) begin
        valid_6 = check_assignment(player_3, letter1_3, letter2_3, reply_3, p1_mask_6, p2_mask_6);
    end
    if (n > 3'd4 && valid_6) begin
        valid_6 = check_assignment(player_4, letter1_4, letter2_4, reply_4, p1_mask_6, p2_mask_6);
    end

    // Assignment 7 check
    valid_7 = 1'b1;
    if (n > 3'd0) begin
        valid_7 = check_assignment(1'b0, letter1_0, letter2_0, reply_0, p1_mask_7, p2_mask_7);
    end
    if (n > 3'd1 && valid_7) begin
        valid_7 = check_assignment(player_1, letter1_1, letter2_1, reply_1, p1_mask_7, p2_mask_7);
    end
    if (n > 3'd2 && valid_7) begin
        valid_7 = check_assignment(player_2, letter1_2, letter2_2, reply_2, p1_mask_7, p2_mask_7);
    end
    if (n > 3'd3 && valid_7) begin
        valid_7 = check_assignment(player_3, letter1_3, letter2_3, reply_3, p1_mask_7, p2_mask_7);
    end
    if (n > 3'd4 && valid_7) begin
        valid_7 = check_assignment(player_4, letter1_4, letter2_4, reply_4, p1_mask_7, p2_mask_7);
    end
end

// Count the number of valid assignments
always @(*) begin
    count = 3'd0;
    if (valid_0) count = count + 3'd1;
    if (valid_1) count = count + 3'd1;
    if (valid_2) count = count + 3'd1;
    if (valid_3) count = count + 3'd1;
    if (valid_4) count = count + 3'd1;
    if (valid_5) count = count + 3'd1;
    if (valid_6) count = count + 3'd1;
    if (valid_7) count = count + 3'd1;
end

// Helper function to check if an investigation matches
function automatic check_assignment(
    input player_val,
    input [1:0] letter1_val,
    input [1:0] letter2_val,
    input [1:0] reply_val,
    input [3:0] p1_mask,
    input [3:0] p2_mask
);
    reg [1:0] count_val;
    reg match;
    begin
        // Determine mask based on player
        match = 1'b0;
        if (player_val == 1'b0) begin
            // Player 1 check
            count_val = 2'd0;
            if (p1_mask[letter1_val]) count_val = count_val + 2'd1;
            if (p1_mask[letter2_val]) count_val = count_val + 2'd1;
            match = (count_val == reply_val);
        end else begin
            // Player 2 check
            count_val = 2'd0;
            if (p2_mask[letter1_val]) count_val = count_val + 2'd1;
            if (p2_mask[letter2_val]) count_val = count_val + 2'd1;
            match = (count_val == reply_val);
        end
        check_assignment = match;
    end
endfunction

endmodule