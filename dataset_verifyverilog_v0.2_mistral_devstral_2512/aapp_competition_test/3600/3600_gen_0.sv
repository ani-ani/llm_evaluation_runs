module basin_city_drones (
    input [7:0] k,
    input [7:0] n,
    input [7:0] adj_0,
    input [7:0] adj_1,
    input [7:0] adj_2,
    input [7:0] adj_3,
    input [7:0] adj_4,
    input [7:0] adj_5,
    input [7:0] adj_6,
    input [7:0] adj_7,
    output reg possible
);

    reg [7:0] adj [0:7];
    integer i, j;
    reg [7:0] placement;
    reg valid;
    reg [7:0] count;

    always @* begin
        possible = 1'b0;
        adj[0] = adj_0;
        adj[1] = adj_1;
        adj[2] = adj_2;
        adj[3] = adj_3;
        adj[4] = adj_4;
        adj[5] = adj_5;
        adj[6] = adj_6;
        adj[7] = adj_7;

        for (placement = 0; placement < 256; placement = placement + 1) begin
            valid = 1'b1;
            count = 0;

            for (i = 0; i < 8; i = i + 1) begin
                if (placement[i]) begin
                    count = count + 1;
                    if (placement & adj[i]) begin
                        valid = 1'b0;
                    end
                end
            end

            if (valid && (count == k) && (count <= n)) begin
                possible = 1'b1;
            end
        end
    end

endmodule