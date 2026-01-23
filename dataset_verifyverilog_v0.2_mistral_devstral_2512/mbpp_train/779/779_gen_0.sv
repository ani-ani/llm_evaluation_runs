module unique_sublists_counter (
    input [7:0] sublists [0:7][0:3],
    input [2:0] valid_count,
    output [31:0] unique_ids [0:7],
    output [3:0] counts [0:7],
    output [2:0] unique_count
);

    wire [31:0] ids [0:7];
    integer i, j, k;
    reg [31:0] temp_unique_ids [0:7];
    reg [3:0] temp_counts [0:7];
    reg [2:0] temp_unique_count;
    reg [7:0] is_unique [0:7];

    // Generate 32-bit IDs for each sublist
    genvar g;
    generate
        for (g = 0; g < 8; g = g + 1) begin : gen_ids
            assign ids[g] = {sublists[g][0], sublists[g][1], sublists[g][2], sublists[g][3]};
        end
    endgenerate

    // Initialize temporary arrays
    always @* begin
        for (i = 0; i < 8; i = i + 1) begin
            temp_unique_ids[i] = 32'h0;
            temp_counts[i] = 4'h0;
            is_unique[i] = 1'h1;
        end
        temp_unique_count = 3'h0;

        // Process each sublist
        for (i = 0; i < valid_count; i = i + 1) begin
            // Check if this sublist is unique
            for (j = 0; j < i; j = j + 1) begin
                if (ids[i] == ids[j]) begin
                    is_unique[i] = 1'h0;
                    break;
                end
            end

            // If unique, add to unique_ids and increment count
            if (is_unique[i]) begin
                temp_unique_ids[temp_unique_count] = ids[i];
                temp_counts[temp_unique_count] = 1'h1;
                temp_unique_count = temp_unique_count + 1'h1;
            end else begin
                // Find the index of the first occurrence
                for (k = 0; k < i; k = k + 1) begin
                    if (ids[i] == ids[k] && is_unique[k]) begin
                        temp_counts[k] = temp_counts[k] + 1'h1;
                        break;
                    end
                end
            end
        end

        // Assign outputs
        for (i = 0; i < 8; i = i + 1) begin
            unique_ids[i] = temp_unique_ids[i];
            counts[i] = temp_counts[i];
        end
        unique_count = temp_unique_count;
    end

endmodule