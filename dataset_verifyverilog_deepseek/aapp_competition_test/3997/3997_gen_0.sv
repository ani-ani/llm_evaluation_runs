module vertex_controller(
  input clk,
  input rst_n,
  input start,
  input [31:0] vertex_vals [0:7],
  input [31:0] edge_weights [0:6],
  output reg [3:0] control_counts [0:7],
  output reg done
);

  typedef enum logic [2:0] {
    IDLE,
    COMP_DIST_1,
    COMP_DIST_2,
    COMP_DIST_3,
    COMPARE,
    UPDATE,
    DONE
  } state_t;

  state_t state;
  reg [2:0] v_reg, u_reg;
  reg [2:0] current_node;
  reg [31:0] current_distance;
  reg descendant_found;

  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state <= IDLE;
      done <= 0;
      foreach (control_counts[i]) control_counts[i] <= 4'd0;
      v_reg <= 0;
      u_reg <= 0;
      current_node <= 0;
      current_distance <= 0;
      descendant_found <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= COMP_DIST_1;
            v_reg <= 0;
            u_reg <= 0;
            current_node <= 0;
            current_distance <= 0;
            descendant_found <= 0;
            done <= 0;
            foreach (control_counts[i]) control_counts[i] <= 4'd0;
          end
        end

        COMP_DIST_1: begin
          if (current_node == v_reg) begin
            descendant_found <= 1'b1;
            state <= COMPARE;
          end else if (current_node == 0) begin
            descendant_found <= 1'b0;
            state <= COMPARE;
          end else begin
            current_node <= (current_node - 3'd1) >> 1;
            current_distance <= current_distance + edge_weights[current_node - 1];
            state <= COMP_DIST_2;
          end
        end

        COMP_DIST_2: begin
          if (current_node == v_reg) begin
            descendant_found <= 1'b1;
            state <= COMPARE;
          end else if (current_node == 0) begin
            descendant_found <= 1'b0;
            state <= COMPARE;
          end else begin
            current_node <= (current_node - 3'd1) >> 1;
            current_distance <= current_distance + edge_weights[current_node - 1];
            state <= COMP_DIST_3;
          end
        end

        COMP_DIST_3: begin
          if (current_node == v_reg) begin
            descendant_found <= 1'b1;
          end else begin
            descendant_found <= 1'b0;
          end
          state <= COMPARE;
        end

        COMPARE: begin
          if (descendant_found && (current_distance <= vertex_vals[u_reg])) begin
            control_counts[v_reg] <= control_counts[v_reg] + 4'd1; 
          end
          state <= UPDATE;
        end

        UPDATE: begin
          if (u_reg < 3'd7) begin
            u_reg <= u_reg + 3'd1;
            current_node <= u_reg + 3'd1;
            current_distance <= 32'd0;
            descendant_found <= 1'b0;
            state <= COMP_DIST_1;
          end else begin
            u_reg <= 3'd0;
            if (v_reg < 3'd7) begin
              v_reg <= v_reg + 3'd1;
              current_node <= 3'd0;
              current_distance <= 32'd0;
              descendant_found <= 1'b0;
              state <= COMP_DIST_1;
            end else begin
              state <= DONE;
            end
          end
        end

        DONE: begin
          done <= 1'b1;
        end
      endcase
    end
  end
endmodule