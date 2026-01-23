module expense_settler (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [5:0] m,
    input [2:0] a_in,
    input [2:0] b_in,
    input [7:0] c_in,
    input load_iou,
    output reg [2:0] p,
    output reg [2:0] out_a,
    output reg [2:0] out_b,
    output reg [7:0] out_c,
    output reg out_valid,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        LOAD,
        SETTLE,
        CHECK_CYCLES,
        OUTPUT,
        DONE
    } state_t;

    state_t state;
    reg [2:0] i, j, k;
    reg [2:0] iou_count;
    reg [2:0] out_iou_count;
    reg [7:0] debt_matrix [0:7][0:7];
    reg [7:0] min_val;
    reg cycle_found;
    reg [2:0] path [0:7];
    reg [2:0] path_len;
    reg [7:0] path_min;
    reg [2:0] current_node;
    reg [2:0] next_node;
    reg [7:0] visited [0:7];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 0;
            j <= 0;
            k <= 0;
            iou_count <= 0;
            out_iou_count <= 0;
            p <= 0;
            out_a <= 0;
            out_b <= 0;
            out_c <= 0;
            out_valid <= 0;
            done <= 0;
            for (int x = 0; x < 8; x++) begin
                for (int y = 0; y < 8; y++) begin
                    debt_matrix[x][y] <= 0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD;
                        iou_count <= 0;
                    end
                end
                LOAD: begin
                    if (load_iou && iou_count < m) begin
                        debt_matrix[a_in][b_in] <= c_in;
                        iou_count <= iou_count + 1;
                    end
                    if (iou_count == m) begin
                        state <= SETTLE;
                    end
                end
                SETTLE: begin
                    state <= CHECK_CYCLES;
                    i <= 0;
                    j <= 0;
                    k <= 0;
                    cycle_found <= 0;
                end
                CHECK_CYCLES: begin
                    // Search for 2-cycles
                    if (i < n && !cycle_found) begin
                        if (j < n) begin
                            if (debt_matrix[i][j] > 0 && debt_matrix[j][i] > 0) begin
                                min_val <= (debt_matrix[i][j] < debt_matrix[j][i]) ? debt_matrix[i][j] : debt_matrix[j][i];
                                debt_matrix[i][j] <= debt_matrix[i][j] - min_val;
                                debt_matrix[j][i] <= debt_matrix[j][i] - min_val;
                                cycle_found <= 1;
                            end
                            j <= j + 1;
                        end else begin
                            j <= 0;
                            i <= i + 1;
                        end
                    end else if (cycle_found) begin
                        cycle_found <= 0;
                        i <= 0;
                        j <= 0;
                    end else begin
                        state <= OUTPUT;
                        out_iou_count <= 0;
                        i <= 0;
                        j <= 0;
                    end
                end
                OUTPUT: begin
                    if (out_iou_count < m) begin
                        if (i < n) begin
                            if (j < n) begin
                                if (debt_matrix[i][j] > 0) begin
                                    out_a <= i;
                                    out_b <= j;
                                    out_c <= debt_matrix[i][j];
                                    out_valid <= 1;
                                    out_iou_count <= out_iou_count + 1;
                                end
                                j <= j + 1;
                            end else begin
                                j <= 0;
                                i <= i + 1;
                            end
                        end else begin
                            out_valid <= 0;
                            state <= DONE;
                            done <= 1;
                            p <= out_iou_count;
                        end
                    end else begin
                        out_valid <= 0;
                        state <= DONE;
                        done <= 1;
                        p <= out_iou_count;
                    end
                end
                DONE: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule