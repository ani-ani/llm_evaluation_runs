module bipartite_remover #(
    parameter N = 4,
    parameter W = 16
)(
    input wire [W-1:0] arr [0:N-1],
    output wire [N-1:0] remove_mask
);

    function automatic [3:0] trailing_zeros;
        input [W-1:0] val;
        integer i;
        reg found;
        begin
            found = 1'b0;
            trailing_zeros = 4'd0;
            for (i = 0; i < W; i = i + 1) begin
                if (val[i] && !found) begin
                    trailing_zeros = i[3:0];
                    found = 1'b1;
                end
            end
        end
    endfunction

    wire [3:0] tz [0:N-1];
    genvar g;
    generate
        for (g = 0; g < N; g = g + 1) begin : tz_gen
            assign tz[g] = trailing_zeros(arr[g]);
        end
    endgenerate

    reg [3:0] mode;
    integer i, j;
    reg [3:0] max_count;
    reg [3:0] count_i;

    always @(*) begin
        max_count = 4'd0;
        mode = tz[0];
        for (i = 0; i < N; i = i + 1) begin
            count_i = 4'd0;
            for (j = 0; j < N; j = j + 1) begin
                if (tz[j] == tz[i]) begin
                    count_i = count_i + 4'd1;
                end
            end
            if (count_i > max_count) begin
                max_count = count_i;
                mode = tz[i];
            end
        end
    end

    reg [N-1:0] mask;
    always @(*) begin
        mask = {N{1'b0}};
        for (i = 0; i < N; i = i + 1) begin
            if (tz[i] != mode) begin
                mask[i] = 1'b1;
            end
        end
    end

    assign remove_mask = mask;

endmodule