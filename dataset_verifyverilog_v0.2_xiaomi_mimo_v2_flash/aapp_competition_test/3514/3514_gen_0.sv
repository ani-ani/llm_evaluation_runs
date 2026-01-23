module bomb_disarm(
    input [7:0] grid [0:7][0:7],
    output reg [6:0] max_disarmed
);
    integer i, j;
    reg [3:0] row_count [0:7];
    reg [3:0] col_count [0:7];
    reg [6:0] count;

    always @(*) begin
        // Initialize row and column counters
        for (i = 0; i < 8; i = i + 1) begin
            row_count[i] = 4'b0;
            col_count[i] = 4'b0;
        end

        // Count bombs per row and per column
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                if (grid[i][j]) begin
                    row_count[i] = row_count[i] + 1;
                    col_count[j] = col_count[j] + 1;
                end
            end
        end

        // Count disarmable buildings
        count = 0;
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                if (grid[i][j]) begin
                    if (row_count[i] > 1 || col_count[j] > 1) begin
                        count = count + 1;
                    end
                end
            end
        end

        max_disarmed = count;
    end
endmodule