module wireless_coverage (
    input [5:0] router_mask,
    input [5:0] router_costs,
    input [7:0] K,
    output [15:0] min_cost
);

    reg [15:0] min_cost_reg = 16'hFFFF;
    integer i;
    reg [5:0] config;
    reg [15:0] current_cost;
    reg [15:0] router_sum;
    reg [3:0] bad_corridors;

    always @* begin
        min_cost_reg = 16'hFFFF;
        for (i = 0; i < 64; i = i + 1) begin
            config = i;
            router_sum = 0;
            bad_corridors = 0;

            // Sum router costs
            if (config[0]) router_sum = router_sum + router_costs[0];
            if (config[1]) router_sum = router_sum + router_costs[1];
            if (config[2]) router_sum = router_sum + router_costs[2];
            if (config[3]) router_sum = router_sum + router_costs[3];
            if (config[4]) router_sum = router_sum + router_costs[4];
            if (config[5]) router_sum = router_sum + router_costs[5];

            // Check horizontal corridors
            // (0,0)-(0,1)
            if ((config[0] + config[1]) != 1) bad_corridors = bad_corridors + 1;
            // (0,1)-(0,2)
            if ((config[1] + config[2]) != 1) bad_corridors = bad_corridors + 1;
            // (1,0)-(1,1)
            if ((config[3] + config[4]) != 1) bad_corridors = bad_corridors + 1;
            // (1,1)-(1,2)
            if ((config[4] + config[5]) != 1) bad_corridors = bad_corridors + 1;

            // Check vertical corridors
            // (0,0)-(1,0)
            if ((config[0] + config[3]) != 1) bad_corridors = bad_corridors + 1;
            // (0,1)-(1,1)
            if ((config[1] + config[4]) != 1) bad_corridors = bad_corridors + 1;
            // (0,2)-(1,2)
            if ((config[2] + config[5]) != 1) bad_corridors = bad_corridors + 1;

            // Total cost
            current_cost = router_sum + (K * bad_corridors);

            // Update minimum
            if (current_cost < min_cost_reg) begin
                min_cost_reg = current_cost;
            end
        end
    end

    assign min_cost = min_cost_reg;

endmodule