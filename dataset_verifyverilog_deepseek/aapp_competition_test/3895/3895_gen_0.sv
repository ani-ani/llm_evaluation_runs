module function_decomposition(
  input clk,
  input rst_n,
  input start,
  input [2:0] f [0:7],
  output reg [2:0] m,
  output reg [2:0] g [0:7],
  output reg [2:0] h [0:7],
  output reg valid_out
);

  typedef enum logic [2:0] {
    IDLE = 3'b000,
    CHECK1 = 3'b001,
    CHECK2 = 3'b010,
    COLLECT = 3'b011,
    CONSTRUCT = 3'b100,
    DONE = 3'b101
  } state_t;

  state_t state_reg, state_next;
  reg error_flag;
  reg [2:0] m_temp;
  reg [2:0] h_temp [0:7];
  reg [2:0] h_index [0:7];
  reg [2:0] g_temp [0:7];

  reg [2:0] m_temp_comb;
  reg [2:0] h_temp_comb [0:7];
  reg [2:0] h_index_comb [0:7];

  always_comb begin
    m_temp_comb = 0;
    for (int i=0; i<8; i=i+1) begin
      h_temp_comb[i] = 3'b0;
      h_index_comb[i] = 3'b0;
    end
    if (!error_flag) begin
      for (int j=0; j<8; j=j+1) begin
        if (f[j] == j) begin
          h_temp_comb[m_temp_comb] = j;
          h_index_comb[j] = m_temp_comb;
          m_temp_comb = m_temp_comb + 1;
        end
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_reg <= IDLE;
      valid_out <= 0;
      m <= 0;
      g <= '{default:3'b0};
      h <= '{default:3'b0};
      error_flag <= 0;
      m_temp <= 0;
      h_temp <= '{default:3'b0};
      h_index <= '{default:3'b0};
      g_temp <= '{default:3'b0};
    end else begin
      state_reg <= state_next;

      case (state_reg)
        IDLE: begin
          valid_out <= 0;
          if (start) begin
            state_next <= CHECK1;
            error_flag <= 0;
          end else begin
            state_next <= IDLE;
          end
          m_temp <= 0;
          h_temp <= '{default:3'b0};
          g_temp <= '{default:3'b0};
          h_index <= '{default:3'b0};
        end

        CHECK1: begin
          error_flag <= error_flag |
                       (f[f[0]] != f[0]) |
                       (f[f[1]] != f[1]) |
                       (f[f[2]] != f[2]) |
                       (f[f[3]] != f[3]);
          state_next <= CHECK2;
        end

        CHECK2: begin
          error_flag <= error_flag |
                       (f[f[4]] != f[4]) |
                       (f[f[5]] != f[5]) |
                       (f[f[6]] != f[6]) |
                       (f[f[7]] != f[7]);
          if (error_flag) begin
            state_next <= DONE;
          end else begin
            state_next <= COLLECT;
          end
        end

        COLLECT: begin
          h_temp <= h_temp_comb;
          h_index <= h_index_comb;
          m_temp <= m_temp_comb;
          state_next <= CONSTRUCT;
        end

        CONSTRUCT: begin
          for (int i=0; i<8; i=i+1) begin
            g_temp[i] <= h_index[f[i]] + 1'b1;
          end
          state_next <= DONE;
        end

        DONE: begin
          if (error_flag) begin
            valid_out <= 1'b0;
            m <= 3'b0;
            g <= '{default:3'b0};
            h <= '{default:3'b0};
          end else begin
            valid_out <= 1'b1;
            m <= m_temp;
            g <= g_temp;
            h <= h_temp;
          end
          state_next <= IDLE;
        end

        default: state_next <= IDLE;
      endcase
    end
  end

endmodule