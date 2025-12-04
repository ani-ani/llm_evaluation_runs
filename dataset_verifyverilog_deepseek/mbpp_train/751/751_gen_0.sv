module min_heap_checker(input [2:0] size, input [4:0] arr [0:7], output logic is_min_heap);
  always_comb begin
    is_min_heap = 1'b1;
    for (int i=0; i<4; i++) begin
      if (2*i+1 < size) begin
        if (arr[i] > arr[2*i+1]) is_min_heap = 1'b0;
      end
      if (2*i+2 < size) begin
        if (arr[i] > arr[2*i+2]) is_min_heap = 1'b0;
      end
    end
  end
endmodule