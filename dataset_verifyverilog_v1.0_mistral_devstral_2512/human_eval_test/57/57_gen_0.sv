module monotonic(
    input [7:0] numbers [0:7],
    output reg result
);
    reg [7:0] prev;
    reg increasing;
    reg decreasing;
    integer i;

    always @(*) begin
        increasing = 1'b1;
        decreasing = 1'b1;
        prev = numbers[0];
        for (i = 1; i < 8; i = i + 1) begin
            if ($signed(numbers[i]) < $signed(prev)) begin
                increasing = 1'b0;
            end
            if ($signed(numbers[i]) > $signed(prev)) begin
                decreasing = 1'b0;
            end
            prev = numbers[i];
        end
        result = increasing || decreasing;
    end
endmodule