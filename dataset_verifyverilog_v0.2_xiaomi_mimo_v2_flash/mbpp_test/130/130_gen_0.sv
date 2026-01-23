module max_frequency (
    input [7:0] data_in [0:15],
    output [7:0] max_value,
    output [3:0] max_count
);

    // Internal storage for unique values and their counters
    reg [7:0] V [0:15];
    reg [3:0] C [0:15];

    integer i, j, k;
    reg [3:0] max_cnt;
    reg [7:0] max_val;

    always @(*) begin
        // Initialize storage
        for (k = 0; k < 16; k = k + 1) begin
            V[k] = 8'b0;
            C[k] = 4'b0;
        end

        // Process each input element
        for (i = 0; i < 16; i = i + 1) begin
            reg found;
            reg [3:0] match_idx;
            reg [3:0] empty_idx;
            
            found = 1'b0;
            match_idx = 4'b0;
            empty_idx = 4'b0;

            // Priority lookup: Check existing unique values
            // We need to find if data_in[i] matches any V[j]
            // Also find the first empty slot if needed
            
            // Check for match first (priority to lower indices)
            for (j = 0; j < 16; j = j + 1) begin
                if (C[j] != 4'b0 && data_in[i] == V[j]) begin
                    found = 1'b1;
                    match_idx = j[3:0];
                end
            end

            if (found) begin
                // Increment the matching counter
                C[match_idx] = C[match_idx] + 1;
            end else begin
                // Find first empty slot
                reg slot_found;
                slot_found = 1'b0;
                for (j = 0; j < 16; j = j + 1) begin
                    if (C[j] == 4'b0 && !slot_found) begin
                        empty_idx = j[3:0];
                        slot_found = 1'b1;
                    end
                end
                
                // If slot found, add new value
                if (slot_found) begin
                    V[empty_idx] = data_in[i];
                    C[empty_idx] = 4'b1;
                end
            end
        end

        // Find maximum count and corresponding value
        max_cnt = 4'b0;
        max_val = 8'b0;
        
        for (i = 0; i < 16; i = i + 1) begin
            if (C[i] > max_cnt) begin
                max_cnt = C[i];
                max_val = V[i];
            end
        end
    end

    assign max_value = max_val;
    assign max_count = max_cnt;

endmodule