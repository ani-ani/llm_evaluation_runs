module tree_jumping_path(input clk, input rst_n, input start, input [15:0] u_1, u_2, u_3, u_4, input [1:0] p_2, p_3, p_4, output reg [2:0] L, output reg [15:0] M_mod, output reg done);

  reg [15:0] u_reg[1:4];
  reg [1:0] p_2_reg, p_3_reg, p_4_reg;
  reg [2:0] l_reg[1:4];
  reg [15:0] c_reg[1:4];
  reg [2:0] state, next_state;
  reg [2:0] current_node;
  reg [1:0] step_count;
  reg [2:0] current_ancestor;
  reg [2:0] current_max_l;
  reg [15:0] current_sum_c;
  reg [1:0] next_ancestor;
  
  localparam IDLE = 3'b000;
  localparam NODE1 = 3'b001;
  localparam PROC_NODE = 3'b010;
  localparam NEXT_ANC = 3'b011;
  localparam UPDATE_NODE = 3'b100;
  localparam COMPLETE = 3'b101;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      L <= 0;
      M_mod <= 0;
      u_reg[1] <= 0; u_reg[2] <= 0; u_reg[3] <= 0; u_reg[4] <= 0;
      p_2_reg <= 0; p_3_reg <= 0; p_4_reg <= 0;
      current_node <= 0;
      current_ancestor <= 0;
      current_max_l <= 0;
      current_sum_c <= 0;
      step_count <= 0;
      l_reg[1] <= 0; l_reg[2] <= 0; l_reg[3] <= 0; l_reg[4] <= 0;
      c_reg[1] <= 0; c_reg[2] <= 0; c_reg[3] <= 0; c_reg[4] <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            u_reg[1] <= u_1;
            u_reg[2] <= u_2;
            u_reg[3] <= u_3;
            u_reg[4] <= u_4;
            p_2_reg <= p_2;
            p_3_reg <= p_3;
            p_4_reg <= p_4;
            state <= NODE1;
            done <= 0;
          end
        end

        NODE1: begin
          l_reg[1] <= 3'd1;
          c_reg[1] <= 16'd1;
          current_node <= 2;
          state <= PROC_NODE;
        end

        PROC_NODE: begin
          current_max_l <= 0;
          current_sum_c <= 0;
          step_count <= 0;
          case (current_node)
            2: current_ancestor <= p_2_reg;
            3: current_ancestor <= p_3_reg;
            4: current_ancestor <= p_4_reg;
            default: current_ancestor <= 0;
          endcase
          state <= NEXT_ANC;
        end

        NEXT_ANC: begin
          if (current_ancestor >= 1 && current_ancestor <= 4) begin
            if (u_reg[current_ancestor] <= u_reg[current_node]) begin
              if (l_reg[current_ancestor] > current_max_l) begin
                current_max_l <= l_reg[current_ancestor];
                current_sum_c <= c_reg[current_ancestor];
              end else if (l_reg[current_ancestor] == current_max_l) begin
                current_sum_c <= current_sum_c + c_reg[current_ancestor];
              end
            end
          end

          if (current_ancestor > 1) begin
            case (current_ancestor)
              2: next_ancestor = p_2_reg;
              3: next_ancestor = p_3_reg;
              4: next_ancestor = p_4_reg;
              default: next_ancestor = 0;
            endcase
            current_ancestor <= next_ancestor;
          end else current_ancestor <= 0;

          step_count <= step_count + 1;
          if (next_ancestor != 0 && step_count < 2) state <= NEXT_ANC;
          else state <= UPDATE_NODE;
        end

        UPDATE_NODE: begin
          if (current_max_l > 0) begin
            l_reg[current_node] <= current_max_l + 3'd1;
            c_reg[current_node] <= current_sum_c;
          end else begin
            l_reg[current_node] <= 3'd1;
            c_reg[current_node] <= 16'd1;
          end

          if (current_node < 4) begin
            current_node <= current_node + 1;
            state <= PROC_NODE;
          end else state <= COMPLETE;
        end

        COMPLETE: begin
          if (~done) begin
            reg [2:0] max_L_temp;
            max_L_temp = l_reg[1];
            if (l_reg[2] > max_L_temp) max_L_temp = l_reg[2];
            if (l_reg[3] > max_L_temp) max_L_temp = l_reg[3];
            if (l_reg[4] > max_L_temp) max_L_temp = l_reg[4];
            L <= max_L_temp;

            reg [25:0] sum_temp;
            sum_temp = 0;
            if (l_reg[1] == max_L_temp) sum_temp = sum_temp + c_reg[1];
            if (l_reg[2] == max_L_temp) sum_temp = sum_temp + c_reg[2];
            if (l_reg[3] == max_L_temp) sum_temp = sum_temp + c_reg[3];
            if (l_reg[4] == max_L_temp) sum_temp = sum_temp + c_reg[4];
            M_mod <= sum_temp % 26'd11092019;
          end

          done <= 1'b1;
          if (start) begin
            done <= 1'b0;
            state <= IDLE;
          end
        end
      endcase
    end
  end
endmodule