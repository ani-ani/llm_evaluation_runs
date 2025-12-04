module list_filter (
    input [3:0] main_list [0:7],
    input [3:0] filter_list [0:7],
    input [2:0] main_len,
    input [2:0] filter_len,
    output reg [3:0] result [0:7],
    output reg [2:0] result_len
);

    logic [7:0] include;
    logic [2:0] prefix_count [0:8];

    always_comb begin
        // Compute include flags
        for (int i = 0; i < 8; i++) begin
            logic found;
            found = 1'b0;
            for (int j = 0; j < 8; j++) begin
                if (j < filter_len) begin
                    if (main_list[i] == filter_list[j]) found = 1'b1;
                }
            end
            include[i] = (i < main_len) ? !found : 1'b0;
        end

        // Compute prefix sums
        prefix_count[0] = '0;
        for (int i = 0; i < 8; i++) begin
            prefix_count[i+1] = prefix_count[i] + include[i];
        end
        result_len = prefix_count[8];

        // Initialize result to zero
        for (int k = 0; k < 8; k++) begin
            result[k] = '0;
        end

        // Place included elements
        for (int m = 0; m < 8; m++) begin
            if (include[m]) begin
                result[prefix_count[m]] = main_list[m];
            end
        end
    end

endmodule