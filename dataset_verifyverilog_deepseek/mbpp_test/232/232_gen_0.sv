module top_n_finder (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [127:0] data,
  output reg [127:0] result,
  output reg done
);

  reg active;
  reg [3:0] counter;
  reg [7:0] top_list [0:15];
  reg [3:0] current_size;
  reg [7:0] next_top_list [0:15];
  reg [3:0] next_size;
  wire [7:0] current_elem;
  integer i, j;

  assign current_elem = data[(15 - counter)*8 +: 8];

  always_comb begin
    for (i=0; i<16; i=i+1) begin
      next_top_list[i] = top_list[i];
    end
    next_size = current_size;

    if (active && !done) begin
      automatic int insert_pos = current_size;
      for (j=0; j<current_size; j=j+1) begin
        if ($signed(current_elem) > $signed(top_list[j])) begin
          insert_pos = j;
          j = current_size;
        end
      end

      if (current_size < n) begin
        next_size = current_size + 1;
        for (i=15; i>=0; i=i-1) begin
          if (i > insert_pos && i < next_size) begin
            next_top_list[i] = top_list[i-1];
          end else if (i == insert_pos) begin
            next_top_list[i] = current_elem;
          end
        end
      end else if (current_size == n) begin
        if ($signed(current_elem) > $signed(top_list[n-1])) begin
          for (i=15; i>=0; i=i-1) begin
            if (i > insert_pos && i < n) begin
              next_top_list[i] = top_list[i-1];
            end else if (i == insert_pos) begin
              next_top_list[i] = current_elem;
            end
          end
        end
      end
    end
  end

  always_comb begin
    result = 128'b0;
    for (i=0; i<16; i=i+1) begin
      if (i < current_size) begin
        result[i*8 +: 8] = top_list[i];
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      active <= 1'b0;
      done <= 1'b0;
      counter <= 4'b0;
      current_size <= 4'b0;
      for (i=0; i<16; i=i+1) begin
        top_list[i] <= 8'b0;
      end
    end else begin
      if (start && !active) begin
        active <= 1'b1;
        done <= 1'b0;
        counter <= 4'b0;
        current_size <= 4'b0;
        for (i=0; i<16; i=i+1) begin
          top_list[i] <= 8'b0;
        end
      end else if (active) begin
        counter <= counter + 1;
        current_size <= next_size;
        for (i=0; i<16; i=i+1) begin
          top_list[i] <= next_top_list[i];
        end
        if (counter == 4'd15) begin
          active <= 1'b0;
          done <= 1'b1;
        end
      end else begin
        done <= 1'b0;
      end
    end
  end

endmodule