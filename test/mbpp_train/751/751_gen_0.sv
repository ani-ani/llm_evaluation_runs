module min_heap_checker(
  input  [2:0] size,
  input  [4:0] arr [0:7],
  output       is_min_heap
);

  reg ok;
  integer i;

  always @* begin
    ok = 1'b1;
    for (i = 0; i < (size >> 1); i = i + 1) begin
      // Check left child if it exists
      if ((2*i + 1) < size) begin
        if (arr[i] > arr[2*i + 1]) begin
          ok = 1'b0;
        end
      end
      // Check right child if it exists
      if ((2*i + 2) < size) begin
        if (arr[i] > arr[2*i + 2]) begin
          ok = 1'b0;
        end
      end
    end
  end

  assign is_min_heap = ok;

endmodule