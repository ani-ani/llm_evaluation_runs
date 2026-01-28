module fold_detector(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] m,
    input wire pixel_in,
    input wire pixel_valid,
    output reg [4:0] r1,
    output reg [4:0] c1,
    output reg [4:0] r2,
    output reg [4:0] c2,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] INPUT = 2'd1;
    localparam [1:0] FIND_FOLD = 2'd2;
    localparam [1:0] OUTPUT = 2'd3;

    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10000;

    // Image storage (25x25)
    reg [24:0][24:0] sram;
    reg [4:0] row_counter;
    reg [4:0] col_counter;
    reg [4:0] pixel_count;

    // Fold detection variables
    reg [1:0] fold_type; // 0: horizontal, 1: vertical, 2: diag45, 3: diag135
    reg [4:0] fold_pos; // position of fold (0-24)
    reg [4:0] best_r1, best_c1, best_r2, best_c2;
    reg found_fold;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            row_counter <= 5'd0;
            col_counter <= 5'd0;
            pixel_count <= 5'd0;
            fold_type <= 2'd0;
            fold_pos <= 5'd0;
            best_r1 <= 5'd0;
            best_c1 <= 5'd0;
            best_r2 <= 5'd0;
            best_c2 <= 5'd0;
            found_fold <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;

            // Initialize SRAM
            integer i, j;
            for (i = 0; i < 25; i = i + 1) begin
                for (j = 0; j < 25; j = j + 1) begin
                    sram[i][j] <= 1'b0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INPUT;
                        row_counter <= 5'd0;
                        col_counter <= 5'd0;
                        pixel_count <= 5'd0;
                    end
                end

                INPUT: begin
                    if (pixel_valid) begin
                        sram[row_counter][col_counter] <= pixel_in;
                        col_counter <= col_counter + 5'd1;
                        pixel_count <= pixel_count + 5'd1;

                        if (col_counter == m) begin
                            col_counter <= 5'd0;
                            row_counter <= row_counter + 5'd1;
                        end

                        if (pixel_count == (n * m) - 5'd1) begin
                            state <= FIND_FOLD;
                            fold_type <= 2'd0;
                            fold_pos <= 5'd0;
                            found_fold <= 1'b0;
                        end
                    end
                end

                FIND_FOLD: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Check if we've found a fold or exceeded max cycles
                    if (found_fold || cycle_count >= MAX_CYCLES) begin
                        state <= OUTPUT;
                    end else begin
                        // Check current fold candidate
                        if (check_fold(fold_type, fold_pos, n, m)) begin
                            found_fold <= 1'b1;
                            // Store coordinates based on fold type
                            case (fold_type)
                                2'd0: begin // Horizontal
                                    best_r1 <= fold_pos + 5'd1;
                                    best_c1 <= 5'd1;
                                    best_r2 <= fold_pos + 5'd1;
                                    best_c2 <= m;
                                end
                                2'd1: begin // Vertical
                                    best_r1 <= 5'd1;
                                    best_c1 <= fold_pos + 5'd1;
                                    best_r2 <= n;
                                    best_c2 <= fold_pos + 5'd1;
                                end
                                2'd2: begin // Diagonal 45°
                                    // Calculate edge points
                                    if (fold_pos < n && fold_pos < m) begin
                                        best_r1 <= fold_pos + 5'd1;
                                        best_c1 <= 5'd1;
                                        best_r2 <= 5'd1;
                                        best_c2 <= fold_pos + 5'd1;
                                    end else if (fold_pos < n) begin
                                        best_r1 <= fold_pos + 5'd1;
                                        best_c1 <= 5'd1;
                                        best_r2 <= (fold_pos - m + 5'd1) + 5'd1;
                                        best_c2 <= m;
                                    end else begin
                                        best_r1 <= n;
                                        best_c1 <= (fold_pos - n + 5'd1) + 5'd1;
                                        best_r2 <= 5'd1;
                                        best_c2 <= fold_pos + 5'd1;
                                    end
                                end
                                2'd3: begin // Diagonal 135°
                                    // Calculate edge points
                                    if (fold_pos < n && fold_pos < m) begin
                                        best_r1 <= 5'd1;
                                        best_c1 <= (m - fold_pos);
                                        best_r2 <= fold_pos + 5'd1;
                                        best_c2 <= m;
                                    end else if (fold_pos < n) begin
                                        best_r1 <= 5'd1;
                                        best_c1 <= (m - fold_pos);
                                        best_r2 <= n;
                                        best_c2 <= (m - (fold_pos - n + 5'd1));
                                    end else begin
                                        best_r1 <= (fold_pos - m + 5'd1) + 5'd1;
                                        best_c1 <= 5'd1;
                                        best_r2 <= n;
                                        best_c2 <= (m - (fold_pos - n + 5'd1));
                                    end
                                end
                            endcase
                        end

                        // Move to next candidate
                        fold_pos <= fold_pos + 5'd1;
                        if (fold_pos == 5'd25) begin
                            fold_pos <= 5'd0;
                            fold_type <= fold_type + 2'd1;
                            if (fold_type == 2'd4) begin
                                fold_type <= 2'd0;
                            end
                        end
                    end
                end

                OUTPUT: begin
                    done <= 1'b1;
                    r1 <= best_r1;
                    c1 <= best_c1;
                    r2 <= best_r2;
                    c2 <= best_c2;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Function to check if a fold is valid
    function check_fold;
        input [1:0] ft;
        input [4:0] fp;
        input [3:0] rows, cols;
        integer i, j, mapped_i, mapped_j;
        reg valid;

        begin
            valid = 1'b1;

            // Check all pixels
            for (i = 0; i < 25; i = i + 1) begin
                for (j = 0; j < 25; j = j + 1) begin
                    if (i < rows && j < cols) begin
                        case (ft)
                            2'd0: begin // Horizontal fold
                                if (i < fp) begin
                                    mapped_i = fp + (fp - i);
                                    mapped_j = j;
                                end else if (i > fp) begin
                                    mapped_i = fp - (i - fp);
                                    mapped_j = j;
                                end else begin
                                    mapped_i = i;
                                    mapped_j = j;
                                end
                            end
                            2'd1: begin // Vertical fold
                                if (j < fp) begin
                                    mapped_i = i;
                                    mapped_j = fp + (fp - j);
                                end else if (j > fp) begin
                                    mapped_i = i;
                                    mapped_j = fp - (j - fp);
                                end else begin
                                    mapped_i = i;
                                    mapped_j = j;
                                end
                            end
                            2'd2: begin // Diagonal 45°
                                if (i + j < fp) begin
                                    mapped_i = fp - j;
                                    mapped_j = fp - i;
                                end else if (i + j > fp) begin
                                    mapped_i = j - (fp - i);
                                    mapped_j = i - (fp - j);
                                end else begin
                                    mapped_i = i;
                                    mapped_j = j;
                                end
                            end
                            2'd3: begin // Diagonal 135°
                                if (i + (cols - 1 - j) < fp) begin
                                    mapped_i = fp - (cols - 1 - j);
                                    mapped_j = cols - 1 - (fp - i);
                                end else if (i + (cols - 1 - j) > fp) begin
                                    mapped_i = (cols - 1 - j) - (fp - i);
                                    mapped_j = cols - 1 - (i - (fp - (cols - 1 - j)));
                                end else begin
                                    mapped_i = i;
                                    mapped_j = j;
                                end
                            end
                        endcase

                        // Check if mapped position is valid
                        if (mapped_i < rows && mapped_j < cols) begin
                            if (sram[i][j] != sram[mapped_i][mapped_j]) begin
                                if (sram[i][j] != 1'b1) begin
                                    valid = 1'b0;
                                end
                            end
                        end else begin
                            if (sram[i][j] != 1'b1) begin
                                valid = 1'b0;
                            end
                        end
                    end
                end
            end

            check_fold = valid;
        end
    endfunction

endmodule