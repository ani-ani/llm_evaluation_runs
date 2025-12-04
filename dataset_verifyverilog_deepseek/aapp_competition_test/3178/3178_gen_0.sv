module city_decoration (
  input clk,
  input rst_n,
  input start,
  input [5:0][1:0] edges,
  input [2:0] m_actual,
  output reg [4:0] min_cost,
  output reg done
);

  localparam IDLE = 0;
  localparam INIT = 1;
  localparam SEARCH = 2;
  localparam DONE_ST = 3;

  reg [1:0] state;
  reg [9:0] counter;
  wire [1:0] deco [0:5];
  wire [5:0] active_road;
  wire constraint_ok;
  wire [4:0] current_cost;

  genvar i;
  generate
    for (i=0; i<6; i=i+1) begin : gen_active_road
      assign active_road[i] = (edges[i] != 0);
    end
  endgenerate

  assign deco[0] = counter % 3;
  assign deco[1] = (counter / 3) % 3;
  assign deco[2] = (counter / 9) % 3;
  assign deco[3] = (counter / 27) % 3;
  assign deco[4] = (counter / 81) % 3;
  assign deco[5] = (counter / 243) % 3;

  wire node0_0 = active_road[0] && active_road[1] && ((deco[0] + deco[1]) % 3 == 1);
  wire node0_1 = active_road[0] && active_road[2] && ((deco[0] + deco[2]) % 3 == 1);
  wire node0_2 = active_road[1] && active_road[2] && ((deco[1] + deco[2]) % 3 == 1);
  
  wire node1_0 = active_road[0] && active_road[3] && ((deco[0] + deco[3]) % 3 == 1);
  wire node1_1 = active_road[0] && active_road[4] && ((deco[0] + deco[4]) % 3 == 1);
  wire node1_2 = active_road[3] && active_road[4] && ((deco[3] + deco[4]) % 3 == 1);
  
  wire node2_0 = active_road[1] && active_road[3] && ((deco[1] + deco[3]) % 3 == 1);
  wire node2_1 = active_road[1] && active_road[5] && ((deco[1] + deco[5]) % 3 == 1);
  wire node2_2 = active_road[3] && active_road[5] && ((deco[3] + deco[5]) % 3 == 1);
  
  wire node3_0 = active_road[2] && active_road[4] && ((deco[2] + deco[4]) % 3 == 1);
  wire node3_1 = active_road[2] && active_road[5] && ((deco[2] + deco[5]) % 3 == 1);
  wire node3_2 = active_road[4] && active_road[5] && ((deco[4] + deco[5]) % 3 == 1);
  
  wire adjacent_violation = node0_0 | node0_1 | node0_2 | node1_0 | node1_1 | node1_2 | node2_0 | node2_1 | node2_2 | node3_0 | node3_1 | node3_2;
  
  wire cycle0_active = active_road[0] && active_road[1] && active_road[3];
  wire cycle0_ok = !cycle0_active || ((deco[0] + deco[1] + deco[3]) % 2 == 1);
  
  wire cycle1_active = active_road[0] && active_road[2] && active_road[4];
  wire cycle1_ok = !cycle1_active || ((deco[0] + deco[2] + deco[4]) % 2 == 1);
  
  wire cycle2_active = active_road[3] && active_road[4] && active_road[5];
  wire cycle2_ok = !cycle2_active || ((deco[3] + deco[4] + deco[5]) % 2 == 1);
  
  wire cycle3_active = active_road[1] && active_road[2] && active_road[5];
  wire cycle3_ok = !cycle3_active || ((deco[1] + deco[2] + deco[5]) % 2 == 1);
  
  wire cycles_ok = cycle0_ok && cycle1_ok && cycle2_ok && cycle3_ok;
  
  assign constraint_ok = !adjacent_violation && cycles_ok;

  wire [4:0] cost_road [0:5];
  assign cost_road[0] = active_road[0] ? deco[0] : 0;
  assign cost_road[1] = active_road[1] ? deco[1] : 0;
  assign cost_road[2] = active_road[2] ? deco[2] : 0;
  assign cost_road[3] = active_road[3] ? deco[3] : 0;
  assign cost_road[4] = active_road[4] ? deco[4] : 0;
  assign cost_road[5] = active_road[5] ? deco[5] : 0;
  assign current_cost = cost_road[0] + cost_road[1] + cost_road[2] + cost_road[3] + cost_road[4] + cost_road[5];

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      min_cost <= 13;
      counter <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start)
            state <= INIT;
        end
        
        INIT: begin
          min_cost <= 13;
          counter <= 0;
          state <= SEARCH;
        end
        
        SEARCH: begin
          if (constraint_ok && (current_cost < min_cost))
            min_cost <= current_cost;
          
          if (counter == 729) begin
            state <= DONE_ST;
          end else begin
            counter <= counter + 1;
          end
        end
        
        DONE_ST: begin
          done <= 1;
          if (min_cost == 13)
            min_cost <= -1;
          state <= IDLE;
        end
      endcase
    end
  end

endmodule