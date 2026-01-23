module bipartite_set_optimizer (
    input [15:0] valid_in,
    input [63:0] numbers_in [0:15],
    output [15:0] remove_mask,
    output [63:0] removed_values [0:15]
);

    // Step 1: Compute ctz for each valid input
    logic [5:0] ctz [0:15];
    integer i;
    always_comb begin
        for (i = 0; i < 16; i = i + 1) begin
            if (valid_in[i]) begin
                ctz[i] = 0;
                if (numbers_in[i] == 0) begin
                    ctz[i] = 64;
                end else begin
                    logic [63:0] temp = numbers_in[i];
                    logic [5:0] count = 0;
                    while (temp[0] == 0 && count < 64) begin
                        temp = temp >> 1;
                        count = count + 1;
                    end
                    ctz[i] = count;
                end
            end else begin
                ctz[i] = 0;
            end
        end
    end

    // Step 2: Count frequencies of each ctz value
    logic [5:0] ctz_counts [0:63];
    always_comb begin
        for (i = 0; i < 64; i = i + 1) begin
            ctz_counts[i] = 0;
        end
        for (i = 0; i < 16; i = i + 1) begin
            if (valid_in[i]) begin
                ctz_counts[ctz[i]] = ctz_counts[ctz[i]] + 1;
            end
        end
    end

    // Step 3: Find the ctz with maximum frequency
    logic [5:0] max_ctz = 0;
    logic [5:0] max_count = 0;
    always_comb begin
        max_ctz = 0;
        max_count = ctz_counts[0];
        for (i = 1; i < 64; i = i + 1) begin
            if (ctz_counts[i] > max_count) begin
                max_count = ctz_counts[i];
                max_ctz = i;
            end
        end
    end

    // Step 4: Generate remove_mask and removed_values
    always_comb begin
        for (i = 0; i < 16; i = i + 1) begin
            if (valid_in[i] && ctz[i] != max_ctz) begin
                remove_mask[i] = 1;
                removed_values[i] = numbers_in[i];
            end else begin
                remove_mask[i] = 0;
                removed_values[i] = 0;
            end
        end
    end

endmodule