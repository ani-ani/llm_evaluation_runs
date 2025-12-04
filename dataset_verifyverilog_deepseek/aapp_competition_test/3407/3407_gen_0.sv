module tree_coordinate_placement (
  input clk,
  input rst_n,
  input start,
  input [2:0] node_count,
  input [7:0][7:0] adj_matrix,
  output reg [15:0] x_coords [0:7],
  output reg [15:0] y_coords [0:7],
  output reg done
);

localparam IDLE = 3'd0;
localparam INIT = 3'd1;
localparam FETCH = 3'd2;
localparam CHECK_CHILD = 3'd3;
localparam CALC_COORD = 3'd4;
localparam NEXT = 3'd5;
localparam DONE_ST = 3'd6;

reg [2:0] state = IDLE;
reg [2:0] queue [0:7];
reg [2:0] q_front = 0;
reg [2:0] q_rear = 0;
reg [7:0] visited;
reg [2:0] current_node;
reg [2:0] current_child;
reg [2:0] current_dir;

wire q_empty = (q_front == q_rear);
wire signed [15:0] offsets[0:7];
assign offsets[0] = 16'h0100;  // 0°
assign offsets[1] = 16'h00B5;  // 45° x/y
assign offsets[2] = 16'h0100;  // 90°
assign offsets[3] = -16'h00B5; // 135° x, 45° y
assign offsets[4] = -16'h0100; // 180°
assign offsets[5] = -16'h00B5; // 225° x/y
assign offsets[6] = -16'h0100; // 270°
assign offsets[7] = 16'h00B5;  // 315° x

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    done <= 0;
    q_front <= 0;
    q_rear <= 0;
    visited <= 0;
    for (int i = 0; i < 8; i++) begin
      x_coords[i] <= '0;
      y_coords[i] <= '0;
    end
  end else begin
    case (state)
      IDLE: begin
        done <= 0;
        if (start) state <= INIT;
      end
      INIT: begin
        visited <= 8'b1;
        x_coords[0] <= 0;
        y_coords[0] <= 0;
        q_front <= 0;
        q_rear <= 1;
        queue[0] <= 0;
        current_dir <= 0;
        state <= FETCH;
      end
      FETCH: begin
        if (!q_empty && q_front < node_count && q_front < 8) begin
          current_node <= queue[q_front];
          q_front <= q_front + 1;
          current_child <= 0;
          state <= CHECK_CHILD;
        end else if (q_empty) state <= DONE_ST;
      end
      CHECK_CHILD: begin
        if (current_child < node_count) begin
          if (adj_matrix[current_node][current_child] && !visited[current_child]) begin
            state <= CALC_COORD;
          end else begin
            current_child <= current_child + 1;
          end
        } else begin
          state <= FETCH;
        end
      end
      CALC_COORD: begin
        x_coords[current_child] <= x_coords[current_node] + ((current_dir[1]^current_dir[0]) ? (current_dir[2] ? -offsets[1] : offsets[1]) :
                                   (current_dir[0] ? 16'h0 :
                                   (current_dir[1:0] == 2'b10 ? -offsets[0] : offsets[0])));
        y_coords[current_child] <= y_coords[current_node] + ((current_dir[1]^~current_dir[0]) ? (current_dir[2] ? -offsets[1] : offsets[1]) :
                                   (current_dir[0] ? (current_dir[1] ? -offsets[2] : offsets[2]) :
                                   16'h0));
        visited[current_child] <= 1'b1;
        queue[q_rear] <= current_child;
        q_rear <= q_rear + 1;
        current_dir <= (current_dir == 3'd7) ? 3'd0 : current_dir + 1;
        current_child <= current_child + 1;
        state <= NEXT;
      end
      NEXT: begin
        state <= CHECK_CHILD;
      end
      DONE_ST: begin
        done <= 1;
        if (!start) state <= IDLE;
      end
    endcase
  end
end

endmodule