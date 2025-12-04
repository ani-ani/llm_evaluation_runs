module pillar_collapse(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [15:0] b [0:7],
  output reg [3:0] max_damage,
  output reg [3:0] pillar_idx,
  output reg done
);

typedef enum {IDLE, RUN} state_e;
state_e state, next_state;
reg [3:0] j, i, count;
reg [3:0] next_j, next_i, next_count;
reg [3:0] next_max_damage, next_pillar_idx;
reg next_done;

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    j <= 0;
    i <= 0;
    count <= 0;
    max_damage <= 0;
    pillar_idx <= 0;
    done <= 0;
  end
  else begin
    state <= next_state;
    j <= next_j;
    i <= next_i;
    count <= next_count;
    max_damage <= next_max_damage;
    pillar_idx <= next_pillar_idx;
    done <= next_done;
  end
end

always_comb begin
  next_state = state;
  next_j = j;
  next_i = i;
  next_count = count;
  next_max_damage = max_damage;
  next_pillar_idx = pillar_idx;
  next_done = done;

  case (state)
    IDLE: begin
      if (start) begin
        next_state = RUN;
        next_j = 4'd0;
        next_i = 4'd0;
        next_count = 4'd0;
        next_max_damage = 4'd0;
        next_pillar_idx = 4'd0;
        next_done = 1'b0;
      end
    end
    RUN: begin
      if (i == n) begin
        if (count > max_damage) begin
          next_max_damage = count;
          next_pillar_idx = j;
        end
        next_j = j + 1;
        if (j == n-1) begin
          next_state = IDLE;
          next_done = 1'b1;
        end
        else begin
          next_i = 4'd0;
          next_count = 4'd0;
        end
      end
      else begin
        if (i == j) begin
          next_i = i + 1;
        end
        else begin
          if (j == 4'd0) begin
            if (i == 4'd1) begin
              if (16'd2000 > b[i])
                next_count = count + 1;
              else
                next_count = count;
            end
            else begin
              if (16'd1000 > b[i])
                next_count = count + 1;
              else
                next_count = count;
            end
          end
          else if (j == n-1) begin
            if (i == n-2) begin
              if (16'd2000 > b[i])
                next_count = count + 1;
              else
                next_count = count;
            end
            else begin
              if (16'd1000 > b[i])
                next_count = count + 1;
              else
                next_count = count;
            end
          end
          else begin
            if (i == j-1 || i == j+1) begin
              if (16'd1500 > b[i])
                next_count = count + 1;
              else
                next_count = count;
            end
            else begin
              if (16'd1000 > b[i])
                next_count = count + 1;
              else
                next_count = count;
            end
          end
          next_i = i + 1;
        end
      end
    end
  endcase
end

endmodule