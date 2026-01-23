module arpa_food_solver (
    input [3:0] pair0_boy_chair,
    input [3:0] pair0_girl_chair,
    input [3:0] pair1_boy_chair,
    input [3:0] pair1_girl_chair,
    input [3:0] pair2_boy_chair,
    input [3:0] pair2_girl_chair,
    input [3:0] pair3_boy_chair,
    input [3:0] pair3_girl_chair,
    output [1:0] pair0_food,
    output [1:0] pair1_food,
    output [1:0] pair2_food,
    output [1:0] pair3_food,
    output valid
);

    reg [7:0] food_assignment;
    reg [1:0] pair0_food_reg;
    reg [1:0] pair1_food_reg;
    reg [1:0] pair2_food_reg;
    reg [1:0] pair3_food_reg;
    reg valid_reg;

    integer i;
    reg [7:0] current_assignment;
    reg valid_assignment;
    reg [1:0] pair0_food_temp;
    reg [1:0] pair1_food_temp;
    reg [1:0] pair2_food_temp;
    reg [1:0] pair3_food_temp;

    always @* begin
        valid_reg = 0;
        pair0_food_reg = 0;
        pair1_food_reg = 0;
        pair2_food_reg = 0;
        pair3_food_reg = 0;

        for (i = 0; i < 256; i = i + 1) begin
            current_assignment = i;
            valid_assignment = 1;

            // Check pair constraints
            if (current_assignment[pair0_boy_chair - 1] == current_assignment[pair0_girl_chair - 1]) begin
                valid_assignment = 0;
            end
            if (current_assignment[pair1_boy_chair - 1] == current_assignment[pair1_girl_chair - 1]) begin
                valid_assignment = 0;
            end
            if (current_assignment[pair2_boy_chair - 1] == current_assignment[pair2_girl_chair - 1]) begin
                valid_assignment = 0;
            end
            if (current_assignment[pair3_boy_chair - 1] == current_assignment[pair3_girl_chair - 1]) begin
                valid_assignment = 0;
            end

            // Check consecutive chairs constraint
            if (valid_assignment) begin
                for (integer j = 0; j < 8; j = j + 1) begin
                    if (current_assignment[j] == current_assignment[(j + 1) % 8] && current_assignment[j] == current_assignment[(j + 2) % 8]) begin
                        valid_assignment = 0;
                    end
                end
            end

            if (valid_assignment) begin
                valid_reg = 1;
                pair0_food_temp = {current_assignment[pair0_boy_chair - 1], current_assignment[pair0_girl_chair - 1]};
                pair1_food_temp = {current_assignment[pair1_boy_chair - 1], current_assignment[pair1_girl_chair - 1]};
                pair2_food_temp = {current_assignment[pair2_boy_chair - 1], current_assignment[pair2_girl_chair - 1]};
                pair3_food_temp = {current_assignment[pair3_boy_chair - 1], current_assignment[pair3_girl_chair - 1]};
                pair0_food_reg = pair0_food_temp;
                pair1_food_reg = pair1_food_temp;
                pair2_food_reg = pair2_food_temp;
                pair3_food_reg = pair3_food_temp;
            end
        end
    end

    assign pair0_food = pair0_food_reg;
    assign pair1_food = pair1_food_reg;
    assign pair2_food = pair2_food_reg;
    assign pair3_food = pair3_food_reg;
    assign valid = valid_reg;

endmodule