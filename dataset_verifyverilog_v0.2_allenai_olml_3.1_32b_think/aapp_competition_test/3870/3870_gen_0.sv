module card_game_solver (
input clk,
input rst_n,
input start,
input [1:0] jatk_en,
input [1:0][7:0] jatk_str,
input [1:0] jdef_en,
input [1:0][7:0] jdef_str,
input [7:0][7:0] ciel_str,
output reg [15:0] result,
output reg done
);

localparam N_ATK = 2
localparam N_DEF = 2
localparam M = 8

localparam IDLE = 3'd0
localparam LOAD = 3'd1
localparam SORT = 3'd2
localparam STRATEGY1_CHECK = 3'd3
localparam STRATEGY1_MATCH_DEF = 3'd4
localparam STRATEGY1_MATCH_ATK = 3'd5
localparam STRATEGY1_DIRECT = 3'd6
localparam STRATEGY2_MATCH = 3'd7
localparam STORE_RESULT = 3'd8
localparam DONE = 3'd9

reg [3:0] state, next_state;
reg [15:0] result_reg;
reg [7:0] ciel_sorted [7:0];
reg [7:0] used_ciel [7:0];
reg [1:0] def_matched;
reg [1:0] atk_matched;
reg [15:0] strategy1_damage;
reg [15:0] strategy2_damage;
reg [2:0] sort_pass, sort_pos;
reg [15:0] sum_remaining;
reg [15:0] sum_atk;
reg [3:0] count;

reg [1:0] jatk_en_reg, jdef_en_reg;
reg [1:0][7:0] jatk_str_reg, jdef_str_reg;
reg [7:0][7:0] ciel_str_reg;

always @(*) begin
  ciel_sorted[7:0] = 8'b0;
  used_ciel = 8'b0;
  def_matched = 2'b00;
  atk_matched = 2'b00;
  strategy1_damage = 16'b0;
  strategy2_damage = 16'b0;
  result_reg = 16'b0;
  done = 1'b0;
  sort_pass = 3'b0;
  sort_pos = 3'b0;
end

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    jatk_en_reg <= 2'b0;
    jdef_en_reg <= 2'b0;
    jatk_str_reg <= 2'b0;
    jdef_str_reg <= 2'b0;
    ciel_str_reg <= 8'b0;
  end else begin
    state <= next_state;
    case (state)
      IDLE: begin
        if (start == 1'b1) next_state <= LOAD; end
      end
      LOAD: begin
        jatk_en_reg <= jatk_en;
        jdef_en_reg <= jdef_en;
        jatk_str_reg <= jatk_str;
        jdef_str_reg <= jdef_str;
        ciel_str_reg <= ciel_str;
        next_state <= SORT;
      end
      SORT: begin
        if (sort_pos < 8) begin
          sort_pos <= sort_pos + 1;
        end else begin
          next_state <= STRATEGY1_CHECK;
        end
      end
      STRATEGY1_CHECK: next_state <= STRATEGY1_MATCH_DEF;
      STRATEGY1_MATCH_DEF: next_state <= STRATEGY1_MATCH_ATK;
      STRATEGY1_MATCH_ATK: next_state <= STRATEGY1_DIRECT;
      STRATEGY1_DIRECT: next_state <= STRATEGY2_MATCH;
      STRATEGY2_MATCH: next_state <= STORE_RESULT;
      STORE_RESULT: begin
        if (strategy1_damage > strategy2_damage) begin
          result_reg <= strategy1_damage;
        end else begin
          result_reg <= strategy2_damage;
        end
        next_state <= DONE;
      end
      DONE: done <= 1'b1;
    endcase
  end
end

assign result = result_reg;
assign done = (state == DONE);

endmodule