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
output reg [15:0] min_cost);
localparam INT_MAX = 1<<20;
always @(*) begin
min_cost = INT_MAX;
for (int atk_p=0; atk_p <= 100; atk_p++) begin
for (int def_p=0; def_p <= 100; def_p++) begin
if (yang_atk_initial + atk_p > monster_def) begin
int damage_per_sec = yang_atk_initial + atk_p - monster_def;
int seconds = (monster_hp + damage_per_sec - 1) / damage_per_sec;
int damage_taken_per_sec = monster_atk - (yang_def_initial + def_p);
if (damage_taken_per_sec < 0) damage_taken_per_sec = 0;
int total_damage = seconds * damage_taken_per_sec;
int required_hp = total_damage + 1 - yang_hp_initial;
if (required_hp < 0) required_hp = 0;
int cost_candidate = atk_p * cost_atk + def_p * cost_def + required_hp * cost_hp;
if (cost_candidate < min_cost)
min_cost = cost_candidate;
end
end
end
endmodule