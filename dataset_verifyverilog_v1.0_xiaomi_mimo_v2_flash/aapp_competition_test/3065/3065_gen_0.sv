module borg_sentry (
  input clk, rst_n, start,
  input [3:0] N,
  input [3:0] L,
  input [3:0] walk0, walk1, walk2, walk3, walk4, walk5, walk6, walk7,
  input [3:0] degree0, degree1, degree2, degree3, degree4, degree5, degree6, degree7,
  input [3:0] neighbors0_0, neighbors0_1, neighbors0_2, neighbors0_3, neighbors0_4, neighbors0_5, neighbors0_6, neighbors0_7,
  input [3:0] neighbors1_0, neighbors1_1, neighbors1_2, neighbors1_3, neighbors1_4, neighbors1_5, neighbors1_6, neighbors1_7,
  input [3:0] neighbors2_0, neighbors2_1, neighbors2_2, neighbors2_3, neighbors2_4, neighbors2_5, neighbors2_6, neighbors2_7,
  input [3:0] neighbors3_0, neighbors3_1, neighbors3_2, neighbors3_3, neighbors3_4, neighbors3_5, neighbors3_6, neighbors3_7,
  input [3:0] neighbors4_0, neighbors4_1, neighbors4_2, neighbors4_3, neighbors4_4, neighbors4_5, neighbors4_6, neighbors4_7,
  input [3:0] neighbors5_0, neighbors5_1, neighbors5_2, neighbors5_3, neighbors5_4, neighbors5_5, neighbors5_6, neighbors5_7,
  input [3:0] neighbors6_0, neighbors6_1, neighbors6_2, neighbors6_3, neighbors6_4, neighbors6_5, neighbors6_6, neighbors6_7,
  input [3:0] neighbors7_0, neighbors7_1, neighbors7_2, neighbors7_3, neighbors7_4, neighbors7_5, neighbors7_6, neighbors7_7,
  output reg [31:0] result,
  output reg done
);

  localparam [3:0] S_IDLE = 4'd0;
  localparam [3:0] S_LOAD = 4'd1;
  localparam [3:0] S_INIT = 4'd2;
  localparam [3:0] S_STEP_RESET = 4'd3;
  localparam [3:0] S_STEP_LOOP = 4'd4;
  localparam [3:0] S_FINAL_SUM = 4'd5;
  localparam [3:0] S_DONE = 4'd6;

  localparam [7:0] FIXED_SHIFT = 8'd24;
  localparam [31:0] ONE = 24'h01000000;

  reg [3:0] state;
  reg [3:0] t_count;
  reg [3:0] u_count;
  reg [3:0] deg_count;
  reg [31:0] dp_prev_0, dp_prev_1, dp_prev_2, dp_prev_3, dp_prev_4, dp_prev_5, dp_prev_6, dp_prev_7;
  reg [31:0] dp_curr_0, dp_curr_1, dp_curr_2, dp_curr_3, dp_curr_4, dp_curr_5, dp_curr_6, dp_curr_7;
  reg [3:0] walk_reg_0, walk_reg_1, walk_reg_2, walk_reg_3, walk_reg_4, walk_reg_5, walk_reg_6, walk_reg_7;
  reg [3:0] degree_reg_0, degree_reg_1, degree_reg_2, degree_reg_3, degree_reg_4, degree_reg_5, degree_reg_6, degree_reg_7;
  reg [3:0] neighbors_0_0, neighbors_0_1, neighbors_0_2, neighbors_0_3, neighbors_0_4, neighbors_0_5, neighbors_0_6, neighbors_0_7;
  reg [3:0] neighbors_1_0, neighbors_1_1, neighbors_1_2, neighbors_1_3, neighbors_1_4, neighbors_1_5, neighbors_1_6, neighbors_1_7;
  reg [3:0] neighbors_2_0, neighbors_2_1, neighbors_2_2, neighbors_2_3, neighbors_2_4, neighbors_2_5, neighbors_2_6, neighbors_2_7;
  reg [3:0] neighbors_3_0, neighbors_3_1, neighbors_3_2, neighbors_3_3, neighbors_3_4, neighbors_3_5, neighbors_3_6, neighbors_3_7;
  reg [3:0] neighbors_4_0, neighbors_4_1, neighbors_4_2, neighbors_4_3, neighbors_4_4, neighbors_4_5, neighbors_4_6, neighbors_4_7;
  reg [3:0] neighbors_5_0, neighbors_5_1, neighbors_5_2, neighbors_5_3, neighbors_5_4, neighbors_5_5, neighbors_5_6, neighbors_5_7;
  reg [3:0] neighbors_6_0, neighbors_6_1, neighbors_6_2, neighbors_6_3, neighbors_6_4, neighbors_6_5, neighbors_6_6, neighbors_6_7;
  reg [3:0] neighbors_7_0, neighbors_7_1, neighbors_7_2, neighbors_7_3, neighbors_7_4, neighbors_7_5, neighbors_7_6, neighbors_7_7;

  wire [31:0] reciprocal_1;
  wire [31:0] reciprocal_2;
  wire [31:0] reciprocal_3;
  wire [31:0] reciprocal_4;
  wire [31:0] reciprocal_5;
  wire [31:0] reciprocal_6;
  wire [31:0] reciprocal_7;
  wire [31:0] reciprocal_8;
  reg [31:0] current_reciprocal;
  reg [31:0] current_dp;
  wire [63:0] product;
  wire [63:0] product_rounded;
  reg [63:0] product_temp;

  assign reciprocal_1 = 32'h01000000;
  assign reciprocal_2 = 32'h00800000;
  assign reciprocal_3 = 32'h00555555;
  assign reciprocal_4 = 32'h00400000;
  assign reciprocal_5 = 32'h00333333;
  assign reciprocal_6 = 32'h002AAAAA;
  assign reciprocal_7 = 32'h00249249;
  assign reciprocal_8 = 32'h00200000;

  assign product = current_dp * current_reciprocal;
  assign product_rounded = product + 32'h00800000;

  function [31:0] get_dp_value;
    input [3:0] node;
    begin
      case (node)
        4'd0: get_dp_value = dp_prev_0;
        4'd1: get_dp_value = dp_prev_1;
        4'd2: get_dp_value = dp_prev_2;
        4'd3: get_dp_value = dp_prev_3;
        4'd4: get_dp_value = dp_prev_4;
        4'd5: get_dp_value = dp_prev_5;
        4'd6: get_dp_value = dp_prev_6;
        4'd7: get_dp_value = dp_prev_7;
        default: get_dp_value = 32'd0;
      endcase
    end
  endfunction

  function [31:0] get_degree;
    input [3:0] node;
    begin
      case (node)
        4'd0: get_degree = degree_reg_0;
        4'd1: get_degree = degree_reg_1;
        4'd2: get_degree = degree_reg_2;
        4'd3: get_degree = degree_reg_3;
        4'd4: get_degree = degree_reg_4;
        4'd5: get_degree = degree_reg_5;
        4'd6: get_degree = degree_reg_6;
        4'd7: get_degree = degree_reg_7;
        default: get_degree = 4'd0;
      endcase
    end
  endfunction

  function [3:0] get_neighbor;
    input [3:0] node;
    input [3:0] idx;
    begin
      case (node)
        4'd0: begin
          case (idx)
            4'd0: get_neighbor = neighbors_0_0;
            4'd1: get_neighbor = neighbors_0_1;
            4'd2: get_neighbor = neighbors_0_2;
            4'd3: get_neighbor = neighbors_0_3;
            4'd4: get_neighbor = neighbors_0_4;
            4'd5: get_neighbor = neighbors_0_5;
            4'd6: get_neighbor = neighbors_0_6;
            4'd7: get_neighbor = neighbors_0_7;
            default: get_neighbor = 4'd0;
          endcase
        end
        4'd1: begin
          case (idx)
            4'd0: get_neighbor = neighbors_1_0;
            4'd1: get_neighbor = neighbors_1_1;
            4'd2: get_neighbor = neighbors_1_2;
            4'd3: get_neighbor = neighbors_1_3;
            4'd4: get_neighbor = neighbors_1_4;
            4'd5: get_neighbor = neighbors_1_5;
            4'd6: get_neighbor = neighbors_1_6;
            4'd7: get_neighbor = neighbors_1_7;
            default: get_neighbor = 4'd0;
          endcase
        end
        4'd2: begin
          case (idx)
            4'd0: get_neighbor = neighbors_2_0;
            4'd1: get_neighbor = neighbors_2_1;
            4'd2: get_neighbor = neighbors_2_2;
            4'd3: get_neighbor = neighbors_2_3;
            4'd4: get_neighbor = neighbors_2_4;
            4'd5: get_neighbor = neighbors_2_5;
            4'd6: get_neighbor = neighbors_2_6;
            4'd7: get_neighbor = neighbors_2_7;
            default: get_neighbor = 4'd0;
          endcase
        end
        4'd3: begin
          case (idx)
            4'd0: get_neighbor = neighbors_3_0;
            4'd1: get_neighbor = neighbors_3_1;
            4'd2: get_neighbor = neighbors_3_2;
            4'd3: get_neighbor = neighbors_3_3;
            4'd4: get_neighbor = neighbors_3_4;
            4'd5: get_neighbor = neighbors_3_5;
            4'd6: get_neighbor = neighbors_3_6;
            4'd7: get_neighbor = neighbors_3_7;
            default: get_neighbor = 4'd0;
          endcase
        end
        4'd4: begin
          case (idx)
            4'd0: get_neighbor = neighbors_4_0;
            4'd1: get_neighbor = neighbors_4_1;
            4'd2: get_neighbor = neighbors_4_2;
            4'd3: get_neighbor = neighbors_4_3;
            4'd4: get_neighbor = neighbors_4_4;
            4'd5: get_neighbor = neighbors_4_5;
            4'd6: get_neighbor = neighbors_4_6;
            4'd7: get_neighbor = neighbors_4_7;
            default: get_neighbor = 4'd0;
          endcase
        end
        4'd5: begin
          case (idx)
            4'd0: get_neighbor = neighbors_5_0;
            4'd1: get_neighbor = neighbors_5_1;
            4'd2: get_neighbor = neighbors_5_2;
            4'd3: get_neighbor = neighbors_5_3;
            4'd4: get_neighbor = neighbors_5_4;
            4'd5: get_neighbor = neighbors_5_5;
            4'd6: get_neighbor = neighbors_5_6;
            4'd7: get_neighbor = neighbors_5_7;
            default: get_neighbor = 4'd0;
          endcase
        end
        4'd6: begin
          case (idx)
            4'd0: get_neighbor = neighbors_6_0;
            4'd1: get_neighbor = neighbors_6_1;
            4'd2: get_neighbor = neighbors_6_2;
            4'd3: get_neighbor = neighbors_6_3;
            4'd4: get_neighbor = neighbors_6_4;
            4'd5: get_neighbor = neighbors_6_5;
            4'd6: get_neighbor = neighbors_6_6;
            4'd7: get_neighbor = neighbors_6_7;
            default: get_neighbor = 4'd0;
          endcase
        end
        4'd7: begin
          case (idx)
            4'd0: get_neighbor = neighbors_7_0;
            4'd1: get_neighbor = neighbors_7_1;
            4'd2: get_neighbor = neighbors_7_2;
            4'd3: get_neighbor = neighbors_7_3;
            4'd4: get_neighbor = neighbors_7_4;
            4'd5: get_neighbor = neighbors_7_5;
            4'd6: get_neighbor = neighbors_7_6;
            4'd7: get_neighbor = neighbors_7_7;
            default: get_neighbor = 4'd0;
          endcase
        end
        default: get_neighbor = 4'd0;
      endcase
    end
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      done <= 0;
      result <= 0;
      t_count <= 0;
      u_count <= 0;
      deg_count <= 0;
      dp_prev_0 <= 0; dp_prev_1 <= 0; dp_prev_2 <= 0; dp_prev_3 <= 0;
      dp_prev_4 <= 0; dp_prev_5 <= 0; dp_prev_6 <= 0; dp_prev_7 <= 0;
      dp_curr_0 <= 0; dp_curr_1 <= 0; dp_curr_2 <= 0; dp_curr_3 <= 0;
      dp_curr_4 <= 0; dp_curr_5 <= 0; dp_curr_6 <= 0; dp_curr_7 <= 0;
      walk_reg_0 <= 0; walk_reg_1 <= 0; walk_reg_2 <= 0; walk_reg_3 <= 0;
      walk_reg_4 <= 0; walk_reg_5 <= 0; walk_reg_6 <= 0; walk_reg_7 <= 0;
      degree_reg_0 <= 0; degree_reg_1 <= 0; degree_reg_2 <= 0; degree_reg_3 <= 0;
      degree_reg_4 <= 0; degree_reg_5 <= 0; degree_reg_6 <= 0; degree_reg_7 <= 0;
      neighbors_0_0 <= 0; neighbors_0_1 <= 0; neighbors_0_2 <= 0; neighbors_0_3 <= 0;
      neighbors_0_4 <= 0; neighbors_0_5 <= 0; neighbors_0_6 <= 0; neighbors_0_7 <= 0;
      neighbors_1_0 <= 0; neighbors_1_1 <= 0; neighbors_1_2 <= 0; neighbors_1_3 <= 0;
      neighbors_1_4 <= 0; neighbors_1_5 <= 0; neighbors_1_6 <= 0; neighbors_1_7 <= 0;
      neighbors_2_0 <= 0; neighbors_2_1 <= 0; neighbors_2_2 <= 0; neighbors_2_3 <= 0;
      neighbors_2_4 <= 0; neighbors_2_5 <= 0; neighbors_2_6 <= 0; neighbors_2_7 <= 0;
      neighbors_3_0 <= 0; neighbors_3_1 <= 0; neighbors_3_2 <= 0; neighbors_3_3 <= 0;
      neighbors_3_4 <= 0; neighbors_3_5 <= 0; neighbors_3_6 <= 0; neighbors_3_7 <= 0;
      neighbors_4_0 <= 0; neighbors_4_1 <= 0; neighbors_4_2 <= 0; neighbors_4_3 <= 0;
      neighbors_4_4 <= 0; neighbors_4_5 <= 0; neighbors_4_6 <= 0; neighbors_4_7 <= 0;
      neighbors_5_0 <= 0; neighbors_5_1 <= 0; neighbors_5_2 <= 0; neighbors_5_3 <= 0;
      neighbors_5_4 <= 0; neighbors_5_5 <= 0; neighbors_5_6 <= 0; neighbors_5_7 <= 0;
      neighbors_6_0 <= 0; neighbors_6_1 <= 0; neighbors_6_2 <= 0; neighbors_6_3 <= 0;
      neighbors_6_4 <= 0; neighbors_6_5 <= 0; neighbors_6_6 <= 0; neighbors_6_7 <= 0;
      neighbors_7_0 <= 0; neighbors_7_1 <= 0; neighbors_7_2 <= 0; neighbors_7_3 <= 0;
      neighbors_7_4 <= 0; neighbors_7_5 <= 0; neighbors_7_6 <= 0; neighbors_7_7 <= 0;
      current_reciprocal <= 0;
      current_dp <= 0;
    end else begin
      case (state)
        S_IDLE: begin
          done <= 0;
          result <= 0;
          if (start) begin
            state <= S_LOAD;
            u_count <= 0;
          end
        end

        S_LOAD: begin
          if (u_count < N) begin
            case (u_count)
              4'd0: begin
                walk_reg_0 <= walk0;
                degree_reg_0 <= degree0;
                neighbors_0_0 <= neighbors0_0;
                neighbors_0_1 <= neighbors0_1;
                neighbors_0_2 <= neighbors0_2;
                neighbors_0_3 <= neighbors0_3;
                neighbors_0_4 <= neighbors0_4;
                neighbors_0_5 <= neighbors0_5;
                neighbors_0_6 <= neighbors0_6;
                neighbors_0_7 <= neighbors0_7;
              end
              4'd1: begin
                walk_reg_1 <= walk1;
                degree_reg_1 <= degree1;
                neighbors_1_0 <= neighbors1_0;
                neighbors_1_1 <= neighbors1_1;
                neighbors_1_2 <= neighbors1_2;
                neighbors_1_3 <= neighbors1_3;
                neighbors_1_4 <= neighbors1_4;
                neighbors_1_5 <= neighbors1_5;
                neighbors_1_6 <= neighbors1_6;
                neighbors_1_7 <= neighbors1_7;
              end
              4'd2: begin
                walk_reg_2 <= walk2;
                degree_reg_2 <= degree2;
                neighbors_2_0 <= neighbors2_0;
                neighbors_2_1 <= neighbors2_1;
                neighbors_2_2 <= neighbors2_2;
                neighbors_2_3 <= neighbors2_3;
                neighbors_2_4 <= neighbors2_4;
                neighbors_2_5 <= neighbors2_5;
                neighbors_2_6 <= neighbors2_6;
                neighbors_2_7 <= neighbors2_7;
              end
              4'd3: begin
                walk_reg_3 <= walk3;
                degree_reg_3 <= degree3;
                neighbors_3_0 <= neighbors3_0;
                neighbors_3_1 <= neighbors3_1;
                neighbors_3_2 <= neighbors3_2;
                neighbors_3_3 <= neighbors3_3;
                neighbors_3_4 <= neighbors3_4;
                neighbors_3_5 <= neighbors3_5;
                neighbors_3_6 <= neighbors3_6;
                neighbors_3_7 <= neighbors3_7;
              end
              4'd4: begin
                walk_reg_4 <= walk4;
                degree_reg_4 <= degree4;
                neighbors_4_0 <= neighbors4_0;
                neighbors_4_1 <= neighbors4_1;
                neighbors_4_2 <= neighbors4_2;
                neighbors_4_3 <= neighbors4_3;
                neighbors_4_4 <= neighbors4_4;
                neighbors_4_5 <= neighbors4_5;
                neighbors_4_6 <= neighbors4_6;
                neighbors_4_7 <= neighbors4_7;
              end
              4'd5: begin
                walk_reg_5 <= walk5;
                degree_reg_5 <= degree5;
                neighbors_5_0 <= neighbors5_0;
                neighbors_5_1 <= neighbors5_1;
                neighbors_5_2 <= neighbors5_2;
                neighbors_5_3 <= neighbors5_3;
                neighbors_5_4 <= neighbors5_4;
                neighbors_5_5 <= neighbors5_5;
                neighbors_5_6 <= neighbors5_6;
                neighbors_5_7 <= neighbors5_7;
              end
              4'd6: begin
                walk_reg_6 <= walk6;
                degree_reg_6 <= degree6;
                neighbors_6_0 <= neighbors6_0;
                neighbors_6_1 <= neighbors6_1;
                neighbors_6_2 <= neighbors6_2;
                neighbors_6_3 <= neighbors6_3;
                neighbors_6_4 <= neighbors6_4;
                neighbors_6_5 <= neighbors6_5;
                neighbors_6_6 <= neighbors6_6;
                neighbors_6_7 <= neighbors6_7;
              end
              4'd7: begin
                walk_reg_7 <= walk7;
                degree_reg_7 <= degree7;
                neighbors_7_0 <= neighbors7_0;
                neighbors_7_1 <= neighbors7_1;
                neighbors_7_2 <= neighbors7_2;
                neighbors_7_3 <= neighbors7_3;
                neighbors_7_4 <= neighbors7_4;
                neighbors_7_5 <= neighbors7_5;
                neighbors_7_6 <= neighbors7_6;
                neighbors_7_7 <= neighbors7_7;
              end
            endcase
            u_count <= u_count + 1;
          end else begin
            u_count <= 0;
            state <= S_INIT;
          end
        end

        S_INIT: begin
          if (u_count < N) begin
            if (u_count == walk_reg_0) begin
              case (u_count)
                4'd0: dp_prev_0 <= 0;
                4'd1: dp_prev_1 <= 0;
                4'd2: dp_prev_2 <= 0;
                4'd3: dp_prev_3 <= 0;
                4'd4: dp_prev_4 <= 0;
                4'd5: dp_prev_5 <= 0;
                4'd6: dp_prev_6 <= 0;
                4'd7: dp_prev_7 <= 0;
              endcase
            end else begin
              case (u_count)
                4'd0: dp_prev_0 <= 32'h00000000;
                4'd1: dp_prev_1 <= 32'h00000000;
                4'd2: dp_prev_2 <= 32'h00000000;
                4'd3: dp_prev_3 <= 32'h00000000;
                4'd4: dp_prev_4 <= 32'h00000000;
                4'd5: dp_prev_5 <= 32'h00000000;
                4'd6: dp_prev_6 <= 32'h00000000;
                4'd7: dp_prev_7 <= 32'h00000000;
              endcase
            end
            u_count <= u_count + 1;
          end else begin
            u_count <= 0;
            if (L > 4'd1) begin
              t_count <= 4'd1;
              state <= S_STEP_RESET;
            end else begin
              state <= S_FINAL_SUM;
            end
          end
        end

        S_STEP_RESET: begin
          if (u_count < N) begin
            case (u_count)
              4'd0: dp_curr_0 <= 0;
              4'd1: dp_curr_1 <= 0;
              4'd2: dp_curr_2 <= 0;
              4'd3: dp_curr_3 <= 0;
              4'd4: dp_curr_4 <= 0;
              4'd5: dp_curr_5 <= 0;
              4'd6: dp_curr_6 <= 0;
              4'd7: dp_curr_7 <= 0;
            endcase
            u_count <= u_count + 1;
          end else begin
            u_count <= 0;
            deg_count <= 0;
            state <= S_STEP_LOOP;
          end
        end

        S_STEP_LOOP: begin
          if (u_count < N) begin
            if (deg_count < get_degree(u_count)) begin
              if (get_neighbor(u_count, deg_count) != walk_reg[t_count]) begin
                if (!((u_count == walk_reg[t_count]) && (get_neighbor(u_count, deg_count) == walk_reg[t_count-1]))) begin
                  current_dp <= get_dp_value(u_count);
                  current_reciprocal <= get_degree(u_count) == 4'd1 ? reciprocal_1 :
                                       get_degree(u_count) == 4'd2 ? reciprocal_2 :
                                       get_degree(u_count) == 4'd3 ? reciprocal_3 :
                                       get_degree(u_count) == 4'd4 ? reciprocal_4 :
                                       get_degree(u_count) == 4'd5 ? reciprocal_5 :
                                       get_degree(u_count) == 4'd6 ? reciprocal_6 :
                                       get_degree(u_count) == 4'd7 ? reciprocal_7 :
                                       get_degree(u_count) == 4'd8 ? reciprocal_8 : 32'd0;
                  product_temp <= product_rounded;
                  state <= 4'd7;
                end else begin
                  deg_count <= deg_count + 1;
                end
              end else begin
                deg_count <= deg_count + 1;
              end
            end else begin
              u_count <= u_count + 1;
              deg_count <= 0;
            end
          end else begin
            if (t_count + 1 < L) begin
              u_count <= 0;
              state <= S_STEP_RESET;
              t_count <= t_count + 1;
            end else begin
              state <= S_FINAL_SUM;
            end
          end
        end

        4'd7: begin
          case (get_neighbor(u_count, deg_count))
            4'd0: dp_curr_0 <= dp_curr_0 + product_temp[55:24];
            4'd1: dp_curr_1 <= dp_curr_1 + product_temp[55:24];
            4'd2: dp_curr_2 <= dp_curr_2 + product_temp[55:24];
            4'd3: dp_curr_3 <= dp_curr_3 + product_temp[55:24];
            4'd4: dp_curr_4 <= dp_curr_4 + product_temp[55:24];
            4'd5: dp_curr_5 <= dp_curr_5 + product_temp[55:24];
            4'd6: dp_curr_6 <= dp_curr_6 + product_temp[55:24];
            4'd7: dp_curr_7 <= dp_curr_7 + product_temp[55:24];
          endcase
          deg_count <= deg_count + 1;
          state <= S_STEP_LOOP;
        end

        S_FINAL_SUM: begin
          if (u_count < N) begin
            case (u_count)
              4'd0: result <= result + dp_prev_0;
              4'd1: result <= result + dp_prev_1;
              4'd2: result <= result + dp_prev_2;
              4'd3: result <= result + dp_prev_3;
              4'd4: result <= result + dp_prev_4;
              4'd5: result <= result + dp_prev_5;
              4'd6: result <= result + dp_prev_6;
              4'd7: result <= result + dp_prev_7;
            endcase
            u_count <= u_count + 1;
          end else begin
            state <= S_DONE;
          end
        end

        S_DONE: begin
          done <= 1;
          if (!start) begin
            state <= S_IDLE;
            done <= 0;
          end
        end

        default: state <= S_IDLE;
      endcase
    end
  end
endmodule