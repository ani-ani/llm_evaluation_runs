module tsp_solver (
  input clk,
  input rst_n,
  input start,
  input [2:0] city_distance_0_1, city_distance_0_2, city_distance_0_3,
         city_distance_1_2, city_distance_1_3,
         city_distance_2_3,
  output reg [15:0] min_cost,
  output reg done
);

// Internal signals
reg [4:0] counter;
reg [15:0] min_cost_reg;
reg [1:0] state;

// Permutation and position
reg [1:0] perm [3:0];
reg [1:0] pos [3:0];

// Combinational signals
wire [2:0] get_distance_output;
wire [15:0] total_cost;
wire valid;

// Function for distance
function [2:0] get_distance;
input [1:0] x, y;
begin
  case ({x,y})
    4'd0: 3'b000;
    4'd1: city_distance_0_1;
    4'd2: city_distance_0_2;
    4'd3: city_distance_0_3;
    4'd4: city_distance_0_1;
    4'd5: 3'b000;
    4'd6: city_distance_1_2;
    4'd7: city_distance_1_3;
    4'd8: city_distance_0_2;
    4'd9: city_distance_1_2;
    4'd10:3'b000;
    4'd11:city_distance_2_3;
    4'd12:city_distance_0_3;
    4'd13:city_distance_1_3;
    4'd14:city_distance_2_3;
    4'd15:3'b000;
    default: 3'b000;
  endcase
endfunction

// Generate permutation from counter
always @(*) begin
  case (counter)
    0: perm = 'd0, 'd1, 'd2, 'd3;
    1: perm = 'd0, 'd1, 'd3, 'd2;
    2: perm = 'd0, 'd2, 'd1, 'd3;
    3: perm = 'd0, 'd2, 'd3, 'd1;
    4: perm = 'd0, 'd3, 'd1, 'd2;
    5: perm = 'd0, 'd3, 'd2, 'd1;
    6: perm = 'd1, 'd0, 'd2, 'd3;
    7: perm = 'd1, 'd0, 'd3, 'd2;
    8: perm = 'd1, 'd2, 'd0, 'd3;
    9: perm = 'd1, 'd2, 'd3, 'd0;
    10: perm = 'd1, 'd3, 'd0, 'd2;
    11: perm = 'd1, 'd3, 'd2, 'd0;
    12: perm = 'd2, 'd0, 'd1, 'd3;
    13: perm = 'd2, 'd0, 'd3, 'd1;
    14: perm = 'd2, 'd1, 'd0, 'd3;
    15: perm = 'd2, 'd1, 'd3, 'd0;
    16: perm = 'd2, 'd3, 'd0, 'd1;
    17: perm = 'd2, 'd3, 'd1, 'd0;
    18: perm = 'd3, 'd0, 'd1, 'd2;
    19: perm = 'd3, 'd0, 'd2, 'd1;
    20: perm = 'd3, 'd1, 'd0, 'd2;
    21: perm = 'd3, 'd1, 'd2, 'd0;
    22: perm = 'd3, 'd2, 'd0, 'd1;
    23: perm = 'd3, 'd2, 'd1, 'd0;
    default: perm = 'd0, 'd0, 'd0, 'd0;
  endcase
end

// Compute positions
always @(*) begin
  pos[0] = 4'd4; pos[1] = 4'd4; pos[2] = 4'd4; pos[3] = 4'd4;
  case (perm[0])
    0: pos[0] = 0;
    1: pos[1] = 0;
    2: pos[2] = 0;
    3: pos[3] = 0;
  endcase
  case (perm[1])
    0: pos[0] = 1;
    1: pos[1] = 1;
    2: pos[2] = 1;
    3: pos[3] = 1;
  endcase
  case (perm[2])
    0: pos[0] = 2;
    1: pos[1] = 2;
    2: pos[2] = 2;
    3: pos[3] = 2;
  endcase
  case (perm[3])
    0: pos[0] = 3;
    1: pos[1] = 3;
    2: pos[2] = 3;
    3: pos[3] = 3;
  endcase
end

// Compute validity
wire valid_k1 = 1'b1;
wire cond_k2 = (pos[0] < pos[2]) == (pos[1] < pos[2]);
wire valid_k2 = cond_k2;
wire cond_k3_0_1 = (pos[0] < pos[3]) == (pos[1] < pos[3]);
wire cond_k3_0_2 = (pos[0] < pos[3]) == (pos[2] < pos[3]);
wire valid_k3 = cond_k3_0_1 && cond_k3_0_2;
wire valid = valid_k2 && valid_k3;

// Compute total cost
total_cost = get_distance(perm[0], perm[1]) + get_distance(perm[1], perm[2]) + get_distance(perm[2], perm[3]);

// State machine
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= 2'd0;
    counter <= 0;
    min_cost_reg <= 10000;
    done <= 0;
  end else begin
    if (state == 2'd0) begin // IDLE
      if (start) state <= 2'd1;
    end else if (state == 2'd1) begin // INIT
      min_cost_reg <= 10000;
      counter <= 0;
      state <= 2'd2;
    end else if (state == 2'd2) begin // CHECK_PERM
      if (valid) begin
        if (total_cost < min_cost_reg) min_cost_reg <= total_cost;
      end
      counter <= counter + 1;
      if (counter == 24) begin
        state <= 2'd3;
        done <= 1;
      end else begin
        state <= 2'd2;
      end
    end else if (state == 2'd3) begin // DONE
      state <= 2'd3;
      done <= 1;
    end
  end
end

// Output assignments
assign min_cost = min_cost_reg;
assign done = done;

endmodule