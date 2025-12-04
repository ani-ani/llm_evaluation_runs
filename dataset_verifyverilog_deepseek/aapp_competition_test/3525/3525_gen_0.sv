module badge_path_counter(
  input clk,
  input rst_n,
  input start,
  input [1:0] S,
  input [1:0] D,
  input [1:0] lock_src[0:4],
  input [1:0] lock_dst[0:4],
  input [3:0] lock_min[0:4],
  input [3:0] lock_max[0:4],
  output reg [3:0] result,
  output reg done
);

typedef enum logic [2:0] {
  IDLE,
  INIT,
  CHECK_INIT,
  BFS1,
  BFS2,
  BFS3,
  COUNT,
  FINISH
} state_t;

state_t state;
reg [3:0] badge_counter;
reg [3:0] current_badge_id;
reg [3:0] valid_count;
reg path_found;
reg [3:0] visited;
reg [3:0] current_rooms;
wire [3:0] next_rooms_computed;
wire path_found_in_step;

// Next rooms combinational logic
always_comb begin
  next_rooms_computed = 4'd0;
  path_found_in_step = 1'b0;
  for (int room = 0; room < 4; room++) begin
    if (current_rooms[room]) begin
      for (int i = 0; i < 5; i++) begin
        if (lock_src[i] == room && current_badge_id >= lock_min[i] && 
            current_badge_id <= lock_max[i] && !visited[lock_dst[i]]) begin
          next_rooms_computed[lock_dst[i]] = 1'b1;
          if (lock_dst[i] == D) path_found_in_step = 1'b1;
        end
      end
    end
  end
end

// State machine
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    badge_counter <= 4'd0;
    valid_count <= 4'd0;
    done <= 1'b0;
    current_badge_id <= 4'd0;
    visited <= 4'd0;
    path_found <= 1'b0;
    current_rooms <= 4'd0;
    result <= 4'd0;
  end else begin
    case (state)
      IDLE: begin
        done <= 1'b0;
        if (start) state <= INIT;
      end
      
      INIT: begin
        badge_counter <= 4'd1;
        valid_count <= 4'd0;
        state <= CHECK_INIT;
      end
      
      CHECK_INIT: begin
        current_badge_id <= badge_counter;
        visited <= (1 << S);
        current_rooms <= (1 << S);
        path_found <= (S == D);
        state <= BFS1;
      end
      
      BFS1: begin
        current_rooms <= next_rooms_computed;
        visited <= visited | next_rooms_computed;
        path_found <= path_found || path_found_in_step;
        state <= BFS2;
      end
      
      BFS2: begin
        current_rooms <= next_rooms_computed;
        visited <= visited | next_rooms_computed;
        path_found <= path_found || path_found_in_step;
        state <= BFS3;
      end
      
      BFS3: begin
        current_rooms <= next_rooms_computed;
        visited <= visited | next_rooms_computed;
        path_found <= path_found || path_found_in_step;
        state <= COUNT;
      end
      
      COUNT: begin
        if (path_found) valid_count <= valid_count + 4'd1;
        badge_counter <= badge_counter + 4'd1;
        path_found <= 1'b0;
        if (badge_counter == 4'd10) state <= FINISH;
        else state <= CHECK_INIT;
      end
      
      FINISH: begin
        result <= valid_count;
        done <= 1'b1;
        state <= IDLE;
      end
      
      default: state <= IDLE;
    endcase
  end
end

endmodule