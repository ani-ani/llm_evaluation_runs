module score_calculator (
  input clk,
  input rst_n,
  input start,
  input [7:0] data_in,
  input [2:0] index_in,
  input input_valid,
  output reg [31:0] result,
  output reg done
);

  parameter N = 8;
  parameter IDLE = 3'b000;
  parameter LOAD = 3'b001;
  parameter SORTING = 3'b010;
  parameter CALCULATING = 3'b011;
  parameter FINISHED = 3'b100;

  reg [2:0] state = IDLE;
  reg [7:0] array [0:N-1];
  reg [2:0] load_count = 0;
  reg [2:0] sort_i = 0;
  reg [2:0] sort_j = 0;
  reg [2:0] calc_i = 0;
  reg [31:0] sum = 0;
  reg [31:0] temp;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      load_count <= 0;
      sort_i <= 0;
      sort_j <= 0;
      calc_i <= 0;
      sum <= 0;
      done <= 0;
      result <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= LOAD;
            load_count <= 0;
          end
        end
        LOAD: begin
          if (input_valid) begin
            array[index_in] <= data_in;
            load_count <= load_count + 1;
            if (load_count == N-1) begin
              state <= SORTING;
              sort_i <= 0;
              sort_j <= 0;
            end
          end
        end
        SORTING: begin
          if (sort_j < N - sort_i - 1) begin
            if (array[sort_j] > array[sort_j + 1]) begin
              temp <= array[sort_j];
              array[sort_j] <= array[sort_j + 1];
              array[sort_j + 1] <= temp;
            end
            sort_j <= sort_j + 1;
          end else begin
            sort_j <= 0;
            if (sort_i < N - 1) begin
              sort_i <= sort_i + 1;
            end else begin
              state <= CALCULATING;
              calc_i <= 0;
              sum <= 0;
            end
          end
        end
        CALCULATING: begin
          if (calc_i < N) begin
            if (calc_i == N-1) begin
              sum <= sum + (array[calc_i] * (calc_i + 2)) - array[calc_i];
            end else begin
              sum <= sum + (array[calc_i] * (calc_i + 2));
            end
            calc_i <= calc_i + 1;
          end else begin
            state <= FINISHED;
            result <= sum;
            done <= 1;
          end
        end
        FINISHED: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule