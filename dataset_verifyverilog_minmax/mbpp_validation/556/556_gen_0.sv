module xor_odd_pair_counter (
    input reg [3:0] A[0:7],
    output reg [4:0] odd_pair_count
);
    integer i;
    logic [3:0] num_odd;
    logic [3:0] num_even;

    always_comb begin
        num_odd = 4'b0;
        for (i = 0; i < 8; i = i + 1) begin
            if (A[i][0])
                num_odd = num_odd + 1;
        end
        num_even = 4'd8 - num_odd;
        odd_pair_count = num_odd * num_even;
    end
endmodule