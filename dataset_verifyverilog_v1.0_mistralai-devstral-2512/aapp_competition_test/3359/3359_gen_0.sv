module stellar_counter(
    input clk,
    input rst_n,
    input start,
    input [7:0] img_in [0:255],
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT      = 3'd1;
    localparam [2:0] SCAN      = 3'd2;
    localparam [2:0] UNION     = 3'd3;
    localparam [2:0] COUNT     = 3'd4;
    localparam [2:0] FINISH    = 3'd5;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd10000;

    // Grid dimensions
    localparam [7:0] ROWS = 8'd16;
    localparam [7:0] COLS = 8'd16;
    localparam [7:0] SIZE = 8'd256;

    // Label and parent arrays
    reg [7:0] labels [0:255];
    reg [7:0] parents [0:255];

    // Scan counters
    reg [7:0] row, col, index;
    reg [7:0] current_label;
    reg [7:0] neighbor_labels [0:3];
    reg [7:0] min_label;

    // Union-find variables
    reg [7:0] i, j, root;

    // Threshold
    localparam [7:0] THRESHOLD = 8'd128;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            row <= 8'd0;
            col <= 8'd0;
            index <= 8'd0;
            current_label <= 8'd0;
            min_label <= 8'd0;
            i <= 8'd0;
            j <= 8'd0;
            root <= 8'd0;

            // Initialize arrays
            integer k;
            for (k = 0; k < 256; k = k + 1) begin
                labels[k] <= 8'd0;
                parents[k] <= 8'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    // Initialize labels and parents
                    integer k;
                    for (k = 0; k < 256; k = k + 1) begin
                        labels[k] <= 8'd0;
                        parents[k] <= 8'd0;
                    end
                    row <= 8'd0;
                    col <= 8'd0;
                    index <= 8'd0;
                    current_label <= 8'd0;
                    next_state <= SCAN;
                end

                SCAN: begin
                    // Calculate current index
                    index <= {row, col};

                    // Check if current pixel is above threshold
                    if (img_in[index] > THRESHOLD) begin
                        // Check neighbors (up, left)
                        neighbor_labels[0] <= (row > 8'd0) ? labels[{row - 8'd1, col}] : 8'd0;
                        neighbor_labels[1] <= (col > 8'd0) ? labels[{row, col - 8'd1}] : 8'd0;
                        neighbor_labels[2] <= 8'd0;
                        neighbor_labels[3] <= 8'd0;

                        // Find minimum non-zero label
                        min_label <= 8'd0;
                        if (neighbor_labels[0] > 8'd0 && (min_label == 8'd0 || neighbor_labels[0] < min_label)) begin
                            min_label <= neighbor_labels[0];
                        end
                        if (neighbor_labels[1] > 8'd0 && (min_label == 8'd0 || neighbor_labels[1] < min_label)) begin
                            min_label <= neighbor_labels[1];
                        end

                        // Assign label
                        if (min_label > 8'd0) begin
                            labels[index] <= min_label;
                        end else begin
                            current_label <= current_label + 8'd1;
                            labels[index] <= current_label;
                            parents[current_label] <= current_label;
                        end

                        // Union neighbors
                        if (neighbor_labels[0] > 8'd0 && neighbor_labels[1] > 8'd0 && neighbor_labels[0] != neighbor_labels[1]) begin
                            parents[neighbor_labels[1]] <= neighbor_labels[0];
                        end
                    end

                    // Move to next pixel
                    col <= col + 8'd1;
                    if (col == COLS) begin
                        col <= 8'd0;
                        row <= row + 8'd1;
                        if (row == ROWS) begin
                            row <= 8'd0;
                            next_state <= UNION;
                        end
                    end
                end

                UNION: begin
                    // Path compression for union-find
                    i <= 8'd0;
                    j <= 8'd0;
                    next_state <= COUNT;

                    // Simple union-find with path compression
                    for (i = 8'd1; i <= current_label; i = i + 8'd1) begin
                        root <= i;
                        while (parents[root] != root) begin
                            root <= parents[root];
                        end
                        parents[i] <= root;
                    end
                end

                COUNT: begin
                    // Count unique roots
                    reg [7:0] unique_count;
                    reg [7:0] roots [0:255];
                    integer k;

                    // Initialize roots array
                    for (k = 0; k < 256; k = k + 1) begin
                        roots[k] <= 8'd0;
                    end

                    unique_count <= 8'd0;
                    for (k = 1; k <= current_label; k = k + 1) begin
                        if (parents[k] == k) begin
                            unique_count <= unique_count + 8'd1;
                        end
                    end

                    result <= unique_count;
                    next_state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

    // Safety check for cycle limit
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES[7:0]) begin
            state <= IDLE;
            next_state <= IDLE;
            done <= 1'b1;
            result <= 8'd0;
        end
    end

endmodule