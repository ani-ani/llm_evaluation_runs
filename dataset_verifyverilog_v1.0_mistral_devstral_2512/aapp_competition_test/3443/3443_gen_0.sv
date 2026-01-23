module symmetry_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] n,
    input wire [15:0] points [3:0],
    output reg [3:0] result,
    output reg done
);

    // State machine states
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [3:0] max_symmetric;
    reg [3:0] current_result;
    reg [15:0] stored_points [3:0];
    reg [2:0] stored_n;
    reg [1:0] i, j, k;
    reg [7:0] cx, cy;
    reg [3:0] symmetric_count;

    // Midpoint computation
    wire [7:0] mid_x = (stored_points[i][7:0] + stored_points[j][7:0]) >> 1;
    wire [7:0] mid_y = (stored_points[i][15:8] + stored_points[j][15:8]) >> 1;

    // Reflection check
    wire [7:0] refl_x = (cx << 1) - stored_points[k][7:0];
    wire [7:0] refl_y = (cy << 1) - stored_points[k][15:8];
    wire refl_match = (refl_x == stored_points[k][7:0]) && (refl_y == stored_points[k][15:8]);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_symmetric <= 0;
            current_result <= 4'd15;
            done <= 1'b0;
            i <= 0;
            j <= 0;
            k <= 0;
            cx <= 8'd0;
            cy <= 8'd0;
            symmetric_count <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start && n > 0) begin
                        stored_n <= n;
                        stored_points[0] <= points[0];
                        stored_points[1] <= points[1];
                        stored_points[2] <= points[2];
                        stored_points[3] <= points[3];
                        max_symmetric <= 0;
                        current_result <= 4'd15;
                        i <= 0;
                        j <= 1;
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    cx <= mid_x;
                    cy <= mid_y;
                    symmetric_count <= 0;
                    k <= 0;

                    if (k < stored_n) begin
                        if (refl_match || (k == i) || (k == j)) begin
                            symmetric_count <= symmetric_count + 1;
                        end
                        k <= k + 1;
                    end else begin
                        if (symmetric_count > max_symmetric) begin
                            max_symmetric <= symmetric_count;
                        end

                        if (j < stored_n - 1) begin
                            j <= j + 1;
                        end else if (i < stored_n - 2) begin
                            i <= i + 1;
                            j <= i + 2;
                        end else begin
                            current_result <= stored_n - max_symmetric;
                            state <= DONE;
                        end
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule