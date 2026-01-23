module monster_battle (
    input [7:0] yang_hp_initial,
    input [7:0] yang_atk_initial,
    input [7:0] yang_def_initial,
    input [7:0] monster_hp,
    input [7:0] monster_atk,
    input [7:0] monster_def,
    input [7:0] cost_hp,
    input [7:0] cost_atk,
    input [7:0] cost_def,
    output [15:0] min_cost
);

    reg [15:0] min_cost_reg = 16'hFFFF;
    integer i, j;
    reg [7:0] atk_purchased, def_purchased;
    reg [7:0] yang_atk, yang_def;
    reg [7:0] damage_per_second, seconds_to_kill;
    reg [7:0] damage_taken_per_second, total_damage_taken;
    reg [7:0] required_hp, total_cost;
    reg valid_config;

    always @* begin
        min_cost_reg = 16'hFFFF;
        for (i = 0; i <= 100; i = i + 1) begin
            atk_purchased = i;
            yang_atk = yang_atk_initial + atk_purchased;
            if (yang_atk > monster_def) begin
                damage_per_second = yang_atk - monster_def;
                if (monster_hp % damage_per_second == 0) begin
                    seconds_to_kill = monster_hp / damage_per_second;
                end else begin
                    seconds_to_kill = (monster_hp / damage_per_second) + 1;
                end
                for (j = 0; j <= 100; j = j + 1) begin
                    def_purchased = j;
                    yang_def = yang_def_initial + def_purchased;
                    if (monster_atk > yang_def) begin
                        damage_taken_per_second = monster_atk - yang_def;
                    end else begin
                        damage_taken_per_second = 0;
                    end
                    total_damage_taken = seconds_to_kill * damage_taken_per_second;
                    if (yang_hp_initial > total_damage_taken) begin
                        required_hp = 0;
                    end else begin
                        required_hp = total_damage_taken - yang_hp_initial + 1;
                    end
                    total_cost = (atk_purchased * cost_atk) + (def_purchased * cost_def) + (required_hp * cost_hp);
                    if (total_cost < min_cost_reg) begin
                        min_cost_reg = total_cost;
                    end
                end
            end
        end
        if (min_cost_reg == 16'hFFFF) begin
            min_cost = 16'hFFFF;
        end else begin
            min_cost = min_cost_reg;
        end
    end

endmodule