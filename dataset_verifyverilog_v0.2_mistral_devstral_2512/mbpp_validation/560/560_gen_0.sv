module tuple_union_sort (
  input clk,
  input rst_n,
  input start,
  input [7:0] tuple1 [0:7],
  input [7:0] tuple2 [0:7],
  output reg [7:0] result [0:7],
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    MERGE,
    SORT_PASS,
    SORT_CHECK,
    PACK,
    DONE
  } state_t;

  state_t state;
  reg [7:0] temp [0:15];
  reg [3:0] merge_idx1;
  reg [3:0] merge_idx2;
  reg [3:0] sort_pass;
  reg [3:0] sort_idx;
  reg [3:0] pack_idx;
  reg [3:0] unique_count;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      merge_idx1 <= 0;
      merge_idx2 <= 0;
      sort_pass <= 0;
      sort_idx <= 0;
      pack_idx <= 0;
      unique_count <= 0;
      for (int i = 0; i < 16; i++) temp[i] <= 0;
      for (int i = 0; i < 8; i++) result[i] <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= MERGE;
            merge_idx1 <= 0;
            merge_idx2 <= 0;
            unique_count <= 0;
            for (int i = 0; i < 16; i++) temp[i] <= 0;
          end
        end

        MERGE: begin
          if (merge_idx1 < 8) begin
            temp[merge_idx1] <= tuple1[merge_idx1];
            merge_idx1 <= merge_idx1 + 1;
          end else if (merge_idx2 < 8) begin
            reg [7:0] current = tuple2[merge_idx2];
            reg duplicate = 0;
            for (int i = 0; i < merge_idx1; i++) begin
              if (temp[i] == current) duplicate = 1;
            end
            if (!duplicate) begin
              temp[merge_idx1] <= current;
              merge_idx1 <= merge_idx1 + 1;
            end
            merge_idx2 <= merge_idx2 + 1;
          end else begin
            state <= SORT_PASS;
            sort_pass <= 0;
            sort_idx <= 0;
          end
        end

        SORT_PASS: begin
          if (sort_idx < 15 - sort_pass) begin
            if (temp[sort_idx] > temp[sort_idx + 1]) begin
              reg [7:0] t = temp[sort_idx];
              temp[sort_idx] <= temp[sort_idx + 1];
              temp[sort_idx + 1] <= t;
            end
            sort_idx <= sort_idx + 1;
          end else begin
            sort_idx <= 0;
            if (sort_pass < 14) begin
              sort_pass <= sort_pass + 1;
            end else begin
              state <= SORT_CHECK;
            end
          end
        end

        SORT_CHECK: begin
          reg sorted = 1;
          for (int i = 0; i < 15; i++) begin
            if (temp[i] > temp[i + 1]) sorted = 0;
          end
          if (sorted) begin
            state <= PACK;
            pack_idx <= 0;
            unique_count <= 0;
            for (int i = 0; i < 16; i++) begin
              if (temp[i] != 0) unique_count <= unique_count + 1;
            end
          end else begin
            state <= SORT_PASS;
            sort_pass <= 0;
            sort_idx <= 0;
          end
        end

        PACK: begin
          if (pack_idx < 8) begin
            if (pack_idx < unique_count) begin
              result[pack_idx] <= temp[pack_idx];
            end else begin
              result[pack_idx] <= 8'hFF;
            end
            pack_idx <= pack_idx + 1;
          end else begin
            state <= DONE;
            done <= 1;
          end
        end

        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule