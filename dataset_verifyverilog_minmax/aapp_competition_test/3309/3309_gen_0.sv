module media_companies_counter(
        input [2:0] k, 
        input [2:0] c, 
        input [7:0] sectors [0:7], 
        output reg [3:0] company_count
    );

        reg [3:0] distinct_count [0:7][0:7];

        always_comb begin
            // Precompute distinct_count for every interval [i][j] (i<=j)
            for (int i=0; i<8; i++) begin
                for (int j=0; j<8; j++) begin
                    distinct_count[i][j] = 0;
                end
            end

            for (int i=0; i<8; i++) begin
                distinct_count[i][i] = 1;
                for (int j=i+1; j<8; j++) begin
                    distinct_count[i][j] = distinct_count[i][j-1];
                    int m;
                    for (m=i; m<j; m++) begin
                        if (sectors[j] == sectors[m])
                            break;
                    end
                    if (m == j) begin
                        distinct_count[i][j] = distinct_count[i][j-1] + 1;
                    end
                end
            end

            // Step 0: start at index 0
            int cur0 = 0;
            int found0 = 0;
            int j0 = 8; // if not found, set to 8 (beyond the last index)
            for (int j=0; j<8; j++) begin
                if (!found0) begin
                    if ( (j - cur0 + 1) >= k && distinct_count[cur0][j] >= c ) begin
                        j0 = j;
                        found0 = 1;
                    end
                end
            end

            int cur1 = (found0) ? (j0+1) : 8;
            int found1 = 0;
            int j1 = 8;
            if (found0) begin
                for (int j=cur1; j<8; j++) begin
                    if (!found1) begin
                        if ( (j - cur1 + 1) >= k && distinct_count[cur1][j] >= c ) begin
                            j1 = j;
                            found1 = 1;
                        end
                    end
                end
            end

            int cur2 = (found1) ? (j1+1) : 8;
            int found2 = 0;
            int j2 = 8;
            if (found1) begin
                for (int j=cur2; j<8; j++) begin
                    if (!found2) begin
                        if ( (j - cur2 + 1) >= k && distinct_count[cur2][j] >= c ) begin
                            j2 = j;
                            found2 = 1;
                        end
                    end
                end
            end

            int cur3 = (found2) ? (j2+1) : 8;
            int found3 = 0;
            int j3 = 8;
            if (found2) begin
                for (int j=cur3; j<8; j++) begin
                    if (!found3) begin
                        if ( (j - cur3 + 1) >= k && distinct_count[cur3][j] >= c ) begin
                            j3 = j;
                            found3 = 1;
                        end
                    end
                end
            end

            if (!found0)
                company_count = 0;
            else if (!found1)
                company_count = 1;
            else if (!found2)
                company_count = 2;
            else if (!found3)
                company_count = 3;
            else
                company_count = 4;
        end

   endmodule