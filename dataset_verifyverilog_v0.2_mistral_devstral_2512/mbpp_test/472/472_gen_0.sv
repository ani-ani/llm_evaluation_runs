module check_consecutive (
  input [7:0] data [0:7],
  output reg result
);

  parameter N = 8;
  integer i, j;
  reg [7:0] min_val;
  reg [7:0] max_val;
  reg no_duplicates;
  reg [7:0] temp_min;
  reg [7:0] temp_max;

  always @(*) begin
    // Initialize min and max to first element
    temp_min = data[0];
    temp_max = data[0];

    // Find min and max values
    for (i = 1; i < N; i = i + 1) begin
      if (data[i] < temp_min) begin
        temp_min = data[i];
      end
      if (data[i] > temp_max) begin
        temp_max = data[i];
      end
    end

    min_val = temp_min;
    max_val = temp_max;

    // Check for duplicates
    no_duplicates = 1'b1;
    for (i = 0; i < N; i = i + 1) begin
      for (j = i + 1; j < N; j = j + 1) begin
        if (data[i] == data[j]) begin
          no_duplicates = 1'b0;
        end
      end
    end

    // Check if max = min + N - 1 and no duplicates
    if (no_duplicates && (max_val == (min_val + N - 1))) begin
      result = 1'b1;
    end else begin
      result = 1'b0;
    end
  end

endmodule