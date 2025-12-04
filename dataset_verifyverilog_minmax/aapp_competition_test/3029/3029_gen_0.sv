module tree_jumping_path(
  input clk, rst_n, start,
  input [15:0] u_1, u_2, u_3, u_4,
  input [1:0] p_2, p_3, p_4,
  output reg [2:0] L,
  output reg [15:0] M_mod,
  output reg done
);

  reg [3:0] state, cycle;
  reg [15:0] u [0:3];
  reg [1:0] p [0:3];
  reg [2:0] l [0:3];
  reg [15:0] c [0:3];
  reg [2:0] temp_max_l;
  reg [15:0] temp_max_c_sum;
  reg [1:0] temp_j;

  always @(posedge clk) begin
    if (rst_n == 0) begin
      state <= 4'b0;
      cycle <= 4'b0;
      L <= 3'b0;
      M_mod <= 16'b0;
      done <= 1'b0;
    end else begin
      cycle <= cycle + 1;

      case (state)
        4'b0000: begin
          if (start) begin
            state <= 4'b0001;
            cycle <= 4'b0;
          end
        end
        4'b0001: begin
          u[0] <= u_1;
          u[1] <= u_2;
          u[2] <= u_3;
          u[3] <= u_4;
          p[0] <= 2'b0; // unused
          p[1] <= p_2 - 1;
          p[2] <= p_3 - 1;
          p[3] <= p_4 - 1;
          l[0] <= 3'b1;
          c[0] <= 16'b1;
          if (cycle == 0) begin
            state <= 4'b0010;
          end
        end
        4'b0010: begin
          if (cycle == 1) begin
            temp_j <= p[1];
            temp_max_l <= 3'b0;
            temp_max_c_sum <= 16'b0;
            if (u[temp_j] <= u[1]) begin
              if (l[temp_j] > temp_max_l) begin
                temp_max_l <= l[temp_j];
                temp_max_c_sum <= c[temp_j];
              end else if (l[temp_j] == temp_max_l) begin
                temp_max_c_sum <= temp_max_c_sum + c[temp_j];
              end
            end
          end else if (cycle == 2) begin
            if (temp_max_l == 0) begin
              l[1] <= 3'b1;
              c[1] <= 16'b1;
            end else begin
              l[1] <= temp_max_l + 1;
              c[1] <= temp_max_c_sum;
            end
            state <= 4'b0011;
          end
        end
        4'b0011: begin
          if (cycle == 3) begin
            temp_j <= p[2];
            temp_max_l <= 3'b0;
            temp_max_c_sum <= 16'b0;
            if (u[temp_j] <= u[2]) begin
              if (l[temp_j] > temp_max_l) begin
                temp_max_l <= l[temp_j];
                temp_max_c_sum <= c[temp_j];
              end else if (l[temp_j] == temp_max_l) begin
                temp_max_c_sum <= temp_max_c_sum + c[temp_j];
              end
            end
          end else if (cycle == 4) begin
            temp_j <= p[temp_j];
            if (u[temp_j] <= u[2]) begin
              if (l[temp_j] > temp_max_l) begin
                temp_max_l <= l[temp_j];
                temp_max_c_sum <= c[temp_j];
              end else if (l[temp_j] == temp_max_l) begin
                temp_max_c_sum <= temp_max_c_sum + c[temp_j];
              end
            end
          end else if (cycle == 5) begin
            if (temp_max_l == 0) begin
              l[2] <= 3'b1;
              c[2] <= 16'b1;
            end else begin
              l[2] <= temp_max_l + 1;
              c[2] <= temp_max_c_sum;
            end
            state <= 4'b0100;
          end
        end
        4'b0100: begin
          if (cycle == 6) begin
            temp_j <= p[3];
            temp_max_l <= 3'b0;
            temp_max_c_sum <= 16'b0;
            if (u[temp_j] <= u[3]) begin
              if (l[temp_j] > temp_max_l) begin
                temp_max_l <= l[temp_j];
                temp_max_c_sum <= c[temp_j];
              end else if (l[temp_j] == temp_max_l) begin
                temp_max_c_sum <= temp_max_c_sum + c[temp_j];
              end
            end
          end else if (cycle == 7) begin
            temp_j <= p[temp_j];
            if (u[temp_j] <= u[3]) begin
              if (l[temp_j] > temp_max_l) begin
                temp_max_l <= l[temp_j];
                temp_max_c_sum <= c[temp_j];
              end else if (l[temp_j] == temp_max_l) begin
                temp_max_c_sum <= temp_max_c_sum + c[temp_j];
              end
            end
          end else if (cycle == 8) begin
            temp_j <= p[temp_j];
            if (u[temp_j] <= u[3]) begin
              if (l[temp_j] > temp_max_l) begin
                temp_max_l <= l[temp_j];
                temp_max_c_sum <= c[temp_j];
              end else if (l[temp_j] == temp_max_l) begin
                temp_max_c_sum <= temp_max_c_sum + c[temp_j];
              end
            end
          end else if (cycle == 9) begin
            if (temp_max_l == 0) begin
              l[3] <= 3'b1;
              c[3] <= 16'b1;
            end else begin
              l[3] <= temp_max_l + 1;
              c[3] <= temp_max_c_sum;
            end
            state <= 4'b0101;
          end
        end
        4'b0101: begin
          if (cycle == 10) begin
            L <= 3'b0;
            M_mod <= 16'b0;
            if (l[0] > L) begin
              L <= l[0];
              M_mod <= c[0];
            end else if (l[0] == L) begin
              M_mod <= M_mod + c[0];
            end
            if (l[1] > L) begin
              L <= l[1];
              M_mod <= c[1];
            end else if (l[1] == L) begin
              M_mod <= M_mod + c[1];
            end
            if (l[2] > L) begin
              L <= l[2];
              M_mod <= c[2];
            end else if (l[2] == L) begin
              M_mod <= M_mod + c[2];
            end
            if (l[3] > L) begin
              L <= l[3];
              M_mod <= c[3];
            end else if (l[3] == L) begin
              M_mod <= M_mod + c[3];
            end
            M_mod <= M_mod % 11092019;
            state <= 4'b0110;
            done <= 1'b1;
          end
        end
        4'b0110: begin
          done <= 1'b1;
        end
      endcase
    end
  end
endmodule
