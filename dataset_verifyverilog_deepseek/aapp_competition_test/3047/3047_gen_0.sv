module puzzle_solver (
  input clk,
  input rst_n,
  input start,
  input [7:0] burger [0:2],
  input [7:0] slop [0:2],
  input [7:0] sushi [0:2],
  input [7:0] drumstick [0:2],
  output reg [15:0] num_solutions,
  output reg many_flag,
  output reg done
);

  typedef enum logic [1:0] {IDLE, PROCESS, DONE_ST} state_t;
  state_t state;

  reg [7:0] m_burger [0:2];
  reg [7:0] m_slop [0:2];
  reg [7:0] m_sushi [0:2];
  reg [7:0] m_drumstick [0:2];
  reg [2:0] many_monster;
  reg [15:0] count_monster [0:2];

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      num_solutions <= 0;
      many_flag <= 0;
      foreach (m_burger[i]) m_burger[i] <= 0;
      foreach (m_slop[i]) m_slop[i] <= 0;
      foreach (m_sushi[i]) m_sushi[i] <= 0;
      foreach (m_drumstick[i]) m_drumstick[i] <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            state <= PROCESS;
            foreach (m_burger[i]) m_burger[i] <= burger[i];
            foreach (m_slop[i]) m_slop[i] <= slop[i];
            foreach (m_sushi[i]) m_sushi[i] <= sushi[i];
            foreach (m_drumstick[i]) m_drumstick[i] <= drumstick[i];
          end
        end

        PROCESS: begin
          for (int i=0; i<3; i=i+1) begin : monster_logic
            automatic bit missing_B = (m_burger[i] == 255);
            automatic bit missing_S = (m_slop[i] == 255);
            automatic bit missing_Su = (m_sushi[i] == 255);
            automatic bit missing_D = (m_drumstick[i] == 255);
            automatic logic [7:0] B_val = missing_B ? 0 : m_burger[i];
            automatic logic [7:0] S_val = missing_S ? 0 : m_slop[i];
            automatic logic [7:0] Su_val = missing_Su ? 0 : m_sushi[i];
            automatic logic [7:0] D_val = missing_D ? 0 : m_drumstick[i];
            automatic logic product_BD = B_val * D_val;
            automatic logic product_SSu = S_val * Su_val;

            many_monster[i] = (product_BD == 0) && (product_SSu == 0) &&
                              ((missing_B || missing_D) && (missing_S || missing_Su));

            count_monster[i] = 0;
            if (!many_monster[i]) begin
              if ({missing_B, missing_S, missing_Su, missing_D} == 0) begin
                count_monster[i] = (product_BD == product_SSu) ? 16'd1 : 16'd0;
              end else if ($countones({missing_B, missing_S, missing_Su, missing_D}) == 1) begin
                automatic logic [15:0] product, quot;
                if (missing_B) begin
                  product = S_val * Su_val;
                  quot = D_val;
                  if (quot != 0) begin
                    if (product % quot == 0 && (product/quot) <= 255 && (product/quot) > 0)
                      count_monster[i] = 1;
                  end else if (product_SSu == 0) begin
                    count_monster[i] = 255;
                  end
                end else if (missing_S) begin
                  product = B_val * D_val;
                  quot = Su_val;
                  if (quot != 0) begin
                    if (product % quot == 0 && (product/quot) <= 255 && (product/quot) > 0)
                      count_monster[i] = 1;
                  end else if (product_BD == 0) begin
                    count_monster[i] = 255;
                  end
                end else if (missing_Su) begin
                  product = B_val * D_val;
                  quot = S_val;
                  if (quot != 0) begin
                    if (product % quot == 0 && (product/quot) <= 255 && (product/quot) > 0)
                      count_monster[i] = 1;
                  end else if (product_BD == 0) begin
                    count_monster[i] = 255;
                  end
                end else if (missing_D) begin
                  product = S_val * Su_val;
                  quot = B_val;
                  if (quot != 0) begin
                    if (product % quot == 0 && (product/quot) <= 255 && (product/quot) > 0)
                      count_monster[i] = 1;
                  end else if (product_SSu == 0) begin
                    count_monster[i] = 255;
                  end
                end
              end else begin
                count_monster[i] = 0;
              end
            end
          end

          state <= DONE_ST;
        end

        DONE_ST: begin
          if (|many_monster) begin
            many_flag <= 1;
            num_solutions <= 0;
          end else begin
            many_flag <= 0;
            num_solutions <= (count_monster[0] * count_monster[1] * count_monster[2]);
          end
          done <= 1;
          if (!start) state <= IDLE;
        end
      endcase
    end
  end

endmodule