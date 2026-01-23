module beautiful_rectangle (
  input clk,
  input rst_n,
  input start,
  input [7:0] data_in [0:31],
  input [5:0] n_valid,
  output reg done,
  output reg [5:0] rows,
  output reg [5:0] cols,
  output reg [7:0] matrix_out [0:15][0:15]
);

  parameter MAX_N = 32;
  parameter MAX_DIM = 16;

  typedef enum logic [2:0] {
    IDLE,
    SORT1,
    SORT2,
    SORT3,
    COUNT,
    DIM,
    FILL
  } state_t;

  state_t state;
  reg [7:0] sorted [0:31];
  reg [7:0] freq [0:255];
  reg [5:0] p, q;
  reg [5:0] i, j, k, m, n;
  reg [7:0] val;
  reg [5:0] count;
  reg [5:0] total_cells;
  reg [5:0] max_area;
  reg [5:0] best_p, best_q;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      rows <= 0;
      cols <= 0;
      for (i = 0; i < 16; i = i + 1) begin
        for (j = 0; j < 16; j = j + 1) begin
          matrix_out[i][j] <= 0;
        end
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= SORT1;
            for (i = 0; i < MAX_N; i = i + 1) begin
              sorted[i] <= data_in[i];
            end
          end
        end
        SORT1: begin
          for (i = 0; i < MAX_N - 1; i = i + 1) begin
            if (sorted[i] > sorted[i + 1]) begin
              val <= sorted[i];
              sorted[i] <= sorted[i + 1];
              sorted[i + 1] <= val;
            end
          end
          state <= SORT2;
        end
        SORT2: begin
          for (i = 0; i < MAX_N - 1; i = i + 1) begin
            if (sorted[i] > sorted[i + 1]) begin
              val <= sorted[i];
              sorted[i] <= sorted[i + 1];
              sorted[i + 1] <= val;
            end
          end
          state <= SORT3;
        end
        SORT3: begin
          for (i = 0; i < MAX_N - 1; i = i + 1) begin
            if (sorted[i] > sorted[i + 1]) begin
              val <= sorted[i];
              sorted[i] <= sorted[i + 1];
              sorted[i + 1] <= val;
            end
          end
          state <= COUNT;
        end
        COUNT: begin
          for (i = 0; i < 256; i = i + 1) begin
            freq[i] <= 0;
          end
          for (i = 0; i < n_valid; i = i + 1) begin
            freq[sorted[i]] <= freq[sorted[i]] + 1;
          end
          state <= DIM;
        end
        DIM: begin
          max_area <= 0;
          best_p <= 0;
          best_q <= 0;
          for (p = 8; p >= 1; p = p - 1) begin
            total_cells <= 0;
            for (i = 1; i < 256; i = i + 1) begin
              if (freq[i] > 0) begin
                total_cells <= total_cells + (freq[i] < p ? freq[i] : p);
              end
            end
            q <= total_cells / p;
            if (q >= p && p * q > max_area) begin
              max_area <= p * q;
              best_p <= p;
              best_q <= q;
            end
          end
          state <= FILL;
        end
        FILL: begin
          for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
              matrix_out[i][j] <= 0;
            end
          end
          k <= 0;
          for (i = 1; i < 256; i = i + 1) begin
            if (freq[i] > 0) begin
              for (j = 0; j < freq[i]; j = j + 1) begin
                if (k < best_p * best_q) begin
                  m <= k % best_p;
                  n <= (k + (k / best_p)) % best_q;
                  matrix_out[m][n] <= i;
                  k <= k + 1;
                end
              end
            end
          end
          rows <= best_p;
          cols <= best_q;
          done <= 1;
          state <= IDLE;
        end
        default: state <= IDLE;
      endcase
    end
  end

endmodule