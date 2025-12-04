module min_heap_checker (
    input [2:0] size,
    input [4:0] arr [0:7],
    output reg is_min_heap
);

    wire [3:0] num_elements = (size == 3'b000) ? 4'd8 : {1'b0, size};
    wire [3:0] num_parents = num_elements >> 1;
    integer i;

    always @(*) begin
        is_min_heap = 1;
        for (i = 0; i < num_parents; i = i+1) begin
            if (2*i+1 < num_elements) begin
                if (arr[i] > arr[2*i+1]) begin
                    is_min_heap = 0;
                end
            end
            if (2*i+2 < num_elements) begin
                if (arr[i] > arr[2*i+2]) begin
                    is_min_heap = 0;
                end
            end
        end
    end

endmodule