module list_filter(
  input  [3:0] main_list   [0:7],
  input  [3:0] filter_list [0:7],
  input  [2:0] main_len,
  input  [2:0] filter_len,
  output reg [3:0] result  [0:7],
  output reg [2:0] result_len
);

  integer i, j;
  reg match;
  reg [2:0] count;

  always @* begin
    // Initialize
    count = 3'd0;

    // Default result to zero
    for (i = 0; i < 8; i = i + 1) begin
      result[i] = 4'd0;
    end

    // Filter logic
    for (i = 0; i < 8; i = i + 1) begin
      if (i < main_len) begin
        match = 1'b0;
        for (j = 0; j < 8; j = j + 1) begin
          if (j < filter_len) begin
            if (main_list[i] == filter_list[j]) begin
              match = 1'b1;
            end
          end
        end
        if (!match) begin
          result[count] = main_list[i];
          count = count + 1'b1;
        end
      end
    end

    result_len = count;
  end

endmodule