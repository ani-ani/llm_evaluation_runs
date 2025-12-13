module sequential_search (
  input              clk,
  input              rst_n,
  input              start,
  input      [7:0]   item,
  input      [7:0]   array [7:0],
  output reg         found,
  output reg [3:0]   index,
  output reg         done
);

  reg [2:0] current_idx;
  reg       searching;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      found       <= 1'b0;
      index       <= 4'b1111;
      done        <= 1'b0;
      searching   <= 1'b0;
      current_idx <= 3'd0;
    end else begin
      if (start && !searching) begin
        // Start a new search
        found       <= 1'b0;
        index       <= 4'b1111;
        done        <= 1'b0;
        searching   <= 1'b1;
        current_idx <= 3'd0;
      end else if (searching && !done) begin
        if (array[current_idx] == item) begin
          found     <= 1'b1;
          index     <= {1'b0, current_idx};
          done      <= 1'b1;
          searching <= 1'b0;
        end else if (current_idx == 3'd7) begin
          found     <= 1'b0;
          index     <= 4'b1111;
          done      <= 1'b1;
          searching <= 1'b0;
        end else begin
          current_idx <= current_idx + 3'd1;
        end
      end
      // When done is high and no new start, hold outputs as specified
    end
  end

endmodule