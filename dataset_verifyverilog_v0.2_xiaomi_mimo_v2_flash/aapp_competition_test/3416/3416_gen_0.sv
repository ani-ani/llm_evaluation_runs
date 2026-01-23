module traveling_salesman(
    input [3:0] n,
    input [3:0] m,
    input [5:0][5:0] edges,
    output reg [1:0] min_flights,
    output reg [3:0] airports
);

    integer i, j, k;
    reg [5:0] valid_mask;
    reg valid_edge[5:0];
    reg [1:0] src[5:0];
    reg [1:0] dst[5:0];
    
    reg [5:0] subset;
    reg is_valid_matching;
    reg left_used[3:0];
    reg right_used[3:0];
    reg [1:0] size;
    
    reg [1:0] max_size;
    reg can_be_unmatched_left[3:0];
    reg can_be_unmatched_right[3:0];
    
    reg [1:0] current_size;
    reg subset_has_left[3:0];
    reg subset_has_right[3:0];
    
    always @(*) begin
        // Initialize
        for (i = 0; i < 6; i = i + 1) begin
            valid_edge[i] = 0;
            src[i] = 0;
            dst[i] = 0;
        end
        
        // Parse edges
        valid_mask = (1 << m) - 1;
        for (i = 0; i < 6; i = i + 1) begin
            if (i < m && edges[i][1:0] == 2'b00) begin
                valid_edge[i] = 1;
                src[i] = edges[i][5:4];
                dst[i] = edges[i][3:2];
            end
        end
        
        // Initialize matching tracking
        max_size = 0;
        for (i = 0; i < 4; i = i + 1) begin
            can_be_unmatched_left[i] = 0;
            can_be_unmatched_right[i] = 0;
        end
        
        // Enumerate all 64 subsets
        for (subset = 0; subset < 64; subset = subset + 1) begin
            // Check if subset is valid matching
            is_valid_matching = 1;
            for (i = 0; i < 4; i = i + 1) begin
                left_used[i] = 0;
                right_used[i] = 0;
                subset_has_left[i] = 0;
                subset_has_right[i] = 0;
            end
            
            size = 0;
            for (i = 0; i < 6; i = i + 1) begin
                if (subset[i] && valid_edge[i]) begin
                    if (left_used[src[i]] || right_used[dst[i]]) begin
                        is_valid_matching = 0;
                    end else begin
                        left_used[src[i]] = 1;
                        right_used[dst[i]] = 1;
                        subset_has_left[src[i]] = 1;
                        subset_has_right[dst[i]] = 1;
                        size = size + 1;
                    end
                end
            end
            
            if (is_valid_matching && size >= max_size && size > 0) begin
                // Check if this subset only uses valid cities (ignores unused cities)
                // Valid if all used cities are < n
                reg cities_valid;
                cities_valid = 1;
                for (i = 0; i < 4; i = i + 1) begin
                    if (subset_has_left[i] && i >= n) cities_valid = 0;
                    if (subset_has_right[i] && i >= n) cities_valid = 0;
                end
                
                if (cities_valid) begin
                    if (size > max_size) begin
                        max_size = size;
                        for (i = 0; i < 4; i = i + 1) begin
                            can_be_unmatched_left[i] = 0;
                            can_be_unmatched_right[i] = 0;
                        end
                    end
                    
                    // Mark cities that can be unmatched in this matching
                    for (i = 0; i < 4; i = i + 1) begin
                        if (i < n) begin
                            if (!subset_has_left[i]) can_be_unmatched_left[i] = 1;
                            if (!subset_has_right[i]) can_be_unmatched_right[i] = 1;
                        end
                    end
                end
            end
        end
        
        // Handle case when no edges exist or m=0
        if (m == 0) begin
            max_size = 0;
            for (i = 0; i < 4; i = i + 1) begin
                if (i < n) begin
                    can_be_unmatched_left[i] = 1;
                    can_be_unmatched_right[i] = 1;
                end else begin
                    can_be_unmatched_left[i] = 0;
                    can_be_unmatched_right[i] = 0;
                end
            end
        end
        
        // Calculate min_flights
        if (n == 0 || n == 1) min_flights = 0;
        else if (max_size >= (n - 1)) min_flights = 0;
        else min_flights = (n - 1) - max_size;
        
        // Calculate airports
        if (min_flights == 0) begin
            airports = 0;
        end else begin
            airports = 0;
            for (i = 0; i < 4; i = i + 1) begin
                if (i < n && (can_be_unmatched_left[i] || can_be_unmatched_right[i])) begin
                    airports[i] = 1;
                end
            end
        end
    end

endmodule
