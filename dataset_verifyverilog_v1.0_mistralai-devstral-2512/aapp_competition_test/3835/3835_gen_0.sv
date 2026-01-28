module matrix_restore(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] matrix_0_0,
    input wire [31:0] matrix_0_1,
    input wire [31:0] matrix_0_2,
    input wire [31:0] matrix_0_3,
    input wire [31:0] matrix_0_4,
    input wire [31:0] matrix_0_5,
    input wire [31:0] matrix_0_6,
    input wire [31:0] matrix_0_7,
    input wire [31:0] matrix_1_0,
    input wire [31:0] matrix_1_1,
    input wire [31:0] matrix_1_2,
    input wire [31:0] matrix_1_3,
    input wire [31:0] matrix_1_4,
    input wire [31:0] matrix_1_5,
    input wire [31:0] matrix_1_6,
    input wire [31:0] matrix_1_7,
    input wire [31:0] matrix_2_0,
    input wire [31:0] matrix_2_1,
    input wire [31:0] matrix_2_2,
    input wire [31:0] matrix_2_3,
    input wire [31:0] matrix_2_4,
    input wire [31:0] matrix_2_5,
    input wire [31:0] matrix_2_6,
    input wire [31:0] matrix_2_7,
    input wire [31:0] matrix_3_0,
    input wire [31:0] matrix_3_1,
    input wire [31:0] matrix_3_2,
    input wire [31:0] matrix_3_3,
    input wire [31:0] matrix_3_4,
    input wire [31:0] matrix_3_5,
    input wire [31:0] matrix_3_6,
    input wire [31:0] matrix_3_7,
    input wire [31:0] matrix_4_0,
    input wire [31:0] matrix_4_1,
    input wire [31:0] matrix_4_2,
    input wire [31:0] matrix_4_3,
    input wire [31:0] matrix_4_4,
    input wire [31:0] matrix_4_5,
    input wire [31:0] matrix_4_6,
    input wire [31:0] matrix_4_7,
    input wire [31:0] matrix_5_0,
    input wire [31:0] matrix_5_1,
    input wire [31:0] matrix_5_2,
    input wire [31:0] matrix_5_3,
    input wire [31:0] matrix_5_4,
    input wire [31:0] matrix_5_5,
    input wire [31:0] matrix_5_6,
    input wire [31:0] matrix_5_7,
    input wire [31:0] matrix_6_0,
    input wire [31:0] matrix_6_1,
    input wire [31:0] matrix_6_2,
    input wire [31:0] matrix_6_3,
    input wire [31:0] matrix_6_4,
    input wire [31:0] matrix_6_5,
    input wire [31:0] matrix_6_6,
    input wire [31:0] matrix_6_7,
    input wire [31:0] matrix_7_0,
    input wire [31:0] matrix_7_1,
    input wire [31:0] matrix_7_2,
    input wire [31:0] matrix_7_3,
    input wire [31:0] matrix_7_4,
    input wire [31:0] matrix_7_5,
    input wire [31:0] matrix_7_6,
    input wire [31:0] matrix_7_7,
    input wire [2:0] n,
    output reg [31:0] result_0,
    output reg [31:0] result_1,
    output reg [31:0] result_2,
    output reg [31:0] result_3,
    output reg [31:0] result_4,
    output reg [31:0] result_5,
    output reg [31:0] result_6,
    output reg [31:0] result_7,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] OUTPUT  = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state;
    reg [2:0] i;
    reg [31:0] x, y, z;
    reg [63:0] temp;
    reg [31:0] sqrt_result;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Matrix array for easier access
    reg [31:0] matrix [0:7][0:7];

    // Assign matrix inputs to array
    always @(*) begin
        matrix[0][0] = matrix_0_0; matrix[0][1] = matrix_0_1; matrix[0][2] = matrix_0_2; matrix[0][3] = matrix_0_3;
        matrix[0][4] = matrix_0_4; matrix[0][5] = matrix_0_5; matrix[0][6] = matrix_0_6; matrix[0][7] = matrix_0_7;
        matrix[1][0] = matrix_1_0; matrix[1][1] = matrix_1_1; matrix[1][2] = matrix_1_2; matrix[1][3] = matrix_1_3;
        matrix[1][4] = matrix_1_4; matrix[1][5] = matrix_1_5; matrix[1][6] = matrix_1_6; matrix[1][7] = matrix_1_7;
        matrix[2][0] = matrix_2_0; matrix[2][1] = matrix_2_1; matrix[2][2] = matrix_2_2; matrix[2][3] = matrix_2_3;
        matrix[2][4] = matrix_2_4; matrix[2][5] = matrix_2_5; matrix[2][6] = matrix_2_6; matrix[2][7] = matrix_2_7;
        matrix[3][0] = matrix_3_0; matrix[3][1] = matrix_3_1; matrix[3][2] = matrix_3_2; matrix[3][3] = matrix_3_3;
        matrix[3][4] = matrix_3_4; matrix[3][5] = matrix_3_5; matrix[3][6] = matrix_3_6; matrix[3][7] = matrix_3_7;
        matrix[4][0] = matrix_4_0; matrix[4][1] = matrix_4_1; matrix[4][2] = matrix_4_2; matrix[4][3] = matrix_4_3;
        matrix[4][4] = matrix_4_4; matrix[4][5] = matrix_4_5; matrix[4][6] = matrix_4_6; matrix[4][7] = matrix_4_7;
        matrix[5][0] = matrix_5_0; matrix[5][1] = matrix_5_1; matrix[5][2] = matrix_5_2; matrix[5][3] = matrix_5_3;
        matrix[5][4] = matrix_5_4; matrix[5][5] = matrix_5_5; matrix[5][6] = matrix_5_6; matrix[5][7] = matrix_5_7;
        matrix[6][0] = matrix_6_0; matrix[6][1] = matrix_6_1; matrix[6][2] = matrix_6_2; matrix[6][3] = matrix_6_3;
        matrix[6][4] = matrix_6_4; matrix[6][5] = matrix_6_5; matrix[6][6] = matrix_6_6; matrix[6][7] = matrix_6_7;
        matrix[7][0] = matrix_7_0; matrix[7][1] = matrix_7_1; matrix[7][2] = matrix_7_2; matrix[7][3] = matrix_7_3;
        matrix[7][4] = matrix_7_4; matrix[7][5] = matrix_7_5; matrix[7][6] = matrix_7_6; matrix[7][7] = matrix_7_7;
    end

    // Integer square root function (non-restoring algorithm)
    function [31:0] isqrt;
        input [63:0] val;
        reg [31:0] root;
        reg [31:0] rem;
        integer i;
        begin
            root = 32'd0;
            rem = 32'd0;
            for (i = 30; i >= 0; i = i - 1) begin
                rem = {rem[30:0], val[63:62]};
                val = val << 2;
                root = {root[30:0], 1'b0};
                if (rem >= root + 1'b1) begin
                    rem = rem - (root + 1'b1);
                    root = root + 1'b1;
                end
            end
            isqrt = root;
        end
    endfunction

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 3'd0;
            x <= 32'd0;
            y <= 32'd0;
            z <= 32'd0;
            temp <= 64'd0;
            sqrt_result <= 32'd0;
            cycle_count <= 8'd0;
            result_0 <= 32'd0;
            result_1 <= 32'd0;
            result_2 <= 32'd0;
            result_3 <= 32'd0;
            result_4 <= 32'd0;
            result_5 <= 32'd0;
            result_6 <= 32'd0;
            result_7 <= 32'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        i <= 3'd0;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    x <= matrix[i][(i + 1) % n];
                    y <= matrix[i][(i + 2) % n];
                    z <= matrix[(i + 1) % n][(i + 2) % n];
                    temp <= $signed(x) * $signed(y);
                    temp <= temp / $signed(z);
                    sqrt_result <= isqrt(temp);
                    state <= OUTPUT;
                end

                OUTPUT: begin
                    cycle_count <= cycle_count + 8'd1;
                    case (i)
                        3'd0: result_0 <= sqrt_result;
                        3'd1: result_1 <= sqrt_result;
                        3'd2: result_2 <= sqrt_result;
                        3'd3: result_3 <= sqrt_result;
                        3'd4: result_4 <= sqrt_result;
                        3'd5: result_5 <= sqrt_result;
                        3'd6: result_6 <= sqrt_result;
                        3'd7: result_7 <= sqrt_result;
                        default: ;
                    endcase
                    i <= i + 3'd1;
                    if (i >= n || cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end else begin
                        state <= COMPUTE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule