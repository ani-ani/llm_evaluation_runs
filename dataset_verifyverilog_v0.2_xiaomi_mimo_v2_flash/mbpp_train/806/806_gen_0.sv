module max_run_uppercase (
    input [7:0] char0,
    input [7:0] char1,
    input [7:0] char2,
    input [7:0] char3,
    input [7:0] char4,
    input [7:0] char5,
    input [7:0] char6,
    input [7:0] char7,
    output reg [3:0] max_run
);

    // Step 1: Determine uppercase status for each character
    wire is_upper0 = (char0 >= 8'h41) && (char0 <= 8'h5A);
    wire is_upper1 = (char1 >= 8'h41) && (char1 <= 8'h5A);
    wire is_upper2 = (char2 >= 8'h41) && (char2 <= 8'h5A);
    wire is_upper3 = (char3 >= 8'h41) && (char3 <= 8'h5A);
    wire is_upper4 = (char4 >= 8'h41) && (char4 <= 8'h5A);
    wire is_upper5 = (char5 >= 8'h41) && (char5 <= 8'h5A);
    wire is_upper6 = (char6 >= 8'h41) && (char6 <= 8'h5A);
    wire is_upper7 = (char7 >= 8'h41) && (char7 <= 8'h5A);

    // Step 2: Calculate run lengths for all starting positions
    reg [3:0] run_len0;
    reg [3:0] run_len1;
    reg [3:0] run_len2;
    reg [3:0] run_len3;
    reg [3:0] run_len4;
    reg [3:0] run_len5;
    reg [3:0] run_len6;
    reg [3:0] run_len7;

    always @(*) begin
        // Run starting at position 0
        run_len0 = 0;
        if (is_upper0) begin
            run_len0 = 1;
            if (is_upper1) begin
                run_len0 = 2;
                if (is_upper2) begin
                    run_len0 = 3;
                    if (is_upper3) begin
                        run_len0 = 4;
                        if (is_upper4) begin
                            run_len0 = 5;
                            if (is_upper5) begin
                                run_len0 = 6;
                                if (is_upper6) begin
                                    run_len0 = 7;
                                    if (is_upper7) begin
                                        run_len0 = 8;
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        // Run starting at position 1
        run_len1 = 0;
        if (is_upper1) begin
            run_len1 = 1;
            if (is_upper2) begin
                run_len1 = 2;
                if (is_upper3) begin
                    run_len1 = 3;
                    if (is_upper4) begin
                        run_len1 = 4;
                        if (is_upper5) begin
                            run_len1 = 5;
                            if (is_upper6) begin
                                run_len1 = 6;
                                if (is_upper7) begin
                                    run_len1 = 7;
                                end
                            end
                        end
                    end
                end
            end
        end

        // Run starting at position 2
        run_len2 = 0;
        if (is_upper2) begin
            run_len2 = 1;
            if (is_upper3) begin
                run_len2 = 2;
                if (is_upper4) begin
                    run_len2 = 3;
                    if (is_upper5) begin
                        run_len2 = 4;
                        if (is_upper6) begin
                            run_len2 = 5;
                            if (is_upper7) begin
                                run_len2 = 6;
                            end
                        end
                    end
                end
            end
        end

        // Run starting at position 3
        run_len3 = 0;
        if (is_upper3) begin
            run_len3 = 1;
            if (is_upper4) begin
                run_len3 = 2;
                if (is_upper5) begin
                    run_len3 = 3;
                    if (is_upper6) begin
                        run_len3 = 4;
                        if (is_upper7) begin
                            run_len3 = 5;
                        end
                    end
                end
            end
        end

        // Run starting at position 4
        run_len4 = 0;
        if (is_upper4) begin
            run_len4 = 1;
            if (is_upper5) begin
                run_len4 = 2;
                if (is_upper6) begin
                    run_len4 = 3;
                    if (is_upper7) begin
                        run_len4 = 4;
                    end
                end
            end
        end

        // Run starting at position 5
        run_len5 = 0;
        if (is_upper5) begin
            run_len5 = 1;
            if (is_upper6) begin
                run_len5 = 2;
                if (is_upper7) begin
                    run_len5 = 3;
                end
            end
        end

        // Run starting at position 6
        run_len6 = 0;
        if (is_upper6) begin
            run_len6 = 1;
            if (is_upper7) begin
                run_len6 = 2;
            end
        end

        // Run starting at position 7
        run_len7 = 0;
        if (is_upper7) begin
            run_len7 = 1;
        end
    end

    // Step 3: Find maximum among all run lengths
    always @(*) begin
        max_run = 0;
        
        if (run_len0 > max_run) max_run = run_len0;
        if (run_len1 > max_run) max_run = run_len1;
        if (run_len2 > max_run) max_run = run_len2;
        if (run_len3 > max_run) max_run = run_len3;
        if (run_len4 > max_run) max_run = run_len4;
        if (run_len5 > max_run) max_run = run_len5;
        if (run_len6 > max_run) max_run = run_len6;
        if (run_len7 > max_run) max_run = run_len7;
    end

endmodule