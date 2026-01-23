module monster_battle(
    input [7:0] yang_hp_initial,
    input [7:0] yang_atk_initial,
    input [7:0] yang_def_initial,
    input [7:0] monster_hp,
    input [7:0] monster_atk,
    input [7:0] monster_def,
    input [7:0] cost_hp,
    input [7:0] cost_atk,
    input [7:0] cost_def,
    output reg [15:0] min_cost
);

    function [7:0] ceil_div;
        input [7:0] num;
        input [7:0] den;
        begin
            ceil_div = (num + den - 1) / den;
        end
    endfunction

    integer atk_i, def_i;
    reg [7:0] y_atk, y_def, dmg_m, turns, dmg_y_per, dmg_y_tot, req_hp;
    reg [15:0] c_atk, c_def, c_hp, cost;

    always @(*) begin
        min_cost = 16'hFFFF;
        for (atk_i = 0; atk_i <= 100; atk_i = atk_i + 1) begin
            for (def_i = 0; def_i <= 100; def_i = def_i + 1) begin
                y_atk = yang_atk_initial + atk_i;
                y_def = yang_def_initial + def_i;
                
                if (y_atk > monster_def) begin
                    dmg_m = y_atk - monster_def;
                    turns = ceil_div(monster_hp, dmg_m);
                    
                    if (monster_atk > y_def)
                        dmg_y_per = monster_atk - y_def;
                    else
                        dmg_y_per = 0;
                    
                    dmg_y_tot = turns * dmg_y_per;
                    
                    if (yang_hp_initial > dmg_y_tot)
                        req_hp = yang_hp_initial - dmg_y_tot + 1;
                    else
                        req_hp = 1;

                    c_atk = atk_i * cost_atk;
                    c_def = def_i * cost_def;
                    c_hp = req_hp * cost_hp;
                    cost = c_atk + c_def + c_hp;
                    
                    if (yang_hp_initial + req_hp > dmg_y_tot) begin
                        if (cost < min_cost)
                            min_cost = cost;
                    end
                end
            end
        end
    end
endmodule