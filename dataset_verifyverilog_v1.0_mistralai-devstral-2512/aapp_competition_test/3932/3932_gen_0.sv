module TreeValidator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] c_in [0:15],
    input wire [4:0] n_in,
    output reg result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] SORT = 4'd1;
    localparam [3:0] CHECK_ROOT = 4'd2;
    localparam [3:0] CHECK_TWOS = 4'd3;
    localparam [3:0] SEARCH_PLACEMENT = 4'd4;
    localparam [3:0] VALIDATE = 4'd5;
    localparam [3:0] FINISH = 4'd6;

    reg [3:0] state;
    reg [4:0] n;
    reg [4:0] c [0:15];
    reg [4:0] sorted_c [0:15];
    reg [4:0] rem [0:15];
    reg [15:0] mask [0:15];
    reg [3:0] child_count [0:15];
    reg [4:0] current_node;
    reg [4:0] parent_node;
    reg [4:0] depth;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd5000;

    // Sorting network (combinational)
    wire [4:0] sorted_c_comb [0:15];
    integer i, j;

    always @(*) begin
        // Initialize sorted array
        for (i = 0; i < 16; i = i + 1) begin
            sorted_c_comb[i] = c[i];
        end

        // Bubble sort (simplified for synthesis)
        for (i = 0; i < 15; i = i + 1) begin
            for (j = 0; j < 15 - i; j = j + 1) begin
                if (sorted_c_comb[j] < sorted_c_comb[j + 1]) begin
                    sorted_c_comb[j] = c[j + 1];
                    sorted_c_comb[j + 1] = c[j];
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 16'd0;
            n <= 5'd0;
            for (i = 0; i < 16; i = i + 1) begin
                c[i] <= 5'd0;
                sorted_c[i] <= 5'd0;
                rem[i] <= 5'd0;
                mask[i] <= 16'd0;
                child_count[i] <= 4'd0;
            end
            current_node <= 5'd0;
            parent_node <= 5'd0;
            depth <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        state <= SORT;
                        n <= n_in;
                        for (i = 0; i < 16; i = i + 1) begin
                            c[i] <= c_in[i];
                        end
                    end
                end

                SORT: begin
                    // Copy sorted values
                    for (i = 0; i < 16; i = i + 1) begin
                        sorted_c[i] <= sorted_c_comb[i];
                    end
                    state <= CHECK_ROOT;
                end

                CHECK_ROOT: begin
                    if (sorted_c[0] != n) begin
                        result <= 1'b0;
                        state <= FINISH;
                    end else begin
                        state <= CHECK_TWOS;
                    end
                end

                CHECK_TWOS: begin
                    reg has_two;
                    has_two = 1'b0;
                    for (i = 0; i < n; i = i + 1) begin
                        if (sorted_c[i] == 5'd2) begin
                            has_two = 1'b1;
                        end
                    end
                    if (has_two) begin
                        result <= 1'b0;
                        state <= FINISH;
                    end else begin
                        // Initialize for search
                        for (i = 0; i < 16; i = i + 1) begin
                            rem[i] <= sorted_c[i] - 5'd1;
                            mask[i] <= 16'd0;
                            child_count[i] <= 4'd0;
                        end
                        current_node <= 5'd0;
                        parent_node <= 5'd0;
                        depth <= 4'd0;
                        state <= SEARCH_PLACEMENT;
                    end
                end

                SEARCH_PLACEMENT: begin
                    cycle_count <= cycle_count + 16'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        result <= 1'b0;
                        state <= FINISH;
                    end else begin
                        // Try to place current_node
                        reg placed;
                        placed = 1'b0;
                        for (i = 0; i < n; i = i + 1) begin
                            if (i != current_node && rem[i] >= sorted_c[current_node] &&
                                !(rem[i] == sorted_c[current_node] && child_count[i] == 4'd0)) begin
                                // Attach current_node to i
                                rem[i] <= rem[i] - sorted_c[current_node];
                                child_count[i] <= child_count[i] + 4'd1;
                                mask[i] <= mask[i] | (1 << current_node);
                                placed = 1'b1;
                                parent_node <= i;
                                break;
                            end
                        end
                        if (placed) begin
                            current_node <= current_node + 5'd1;
                            depth <= depth + 4'd1;
                            if (current_node == n) begin
                                state <= VALIDATE;
                            end
                        end else begin
                            // Backtrack
                            if (depth == 4'd0) begin
                                result <= 1'b0;
                                state <= FINISH;
                            end else begin
                                current_node <= current_node - 5'd1;
                                depth <= depth - 4'd1;
                                // Undo previous placement
                                i = parent_node;
                                rem[i] <= rem[i] + sorted_c[current_node];
                                child_count[i] <= child_count[i] - 4'd1;
                                mask[i] <= mask[i] & ~(1 << current_node);
                            end
                        end
                    end
                end

                VALIDATE: begin
                    reg valid;
                    valid = 1'b1;
                    for (i = 0; i < n; i = i + 1) begin
                        if (rem[i] != 5'd0 && sorted_c[i] != 5'd1) begin
                            valid = 1'b0;
                        end
                        if (child_count[i] > 4'd0 && child_count[i] < 4'd2) begin
                            valid = 1'b0;
                        end
                    end
                    result <= valid;
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule