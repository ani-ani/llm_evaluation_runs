module max_polygon_area #(
    parameter N = 8,
    parameter DATA_WIDTH = 8,
    parameter RESULT_WIDTH = 32,
    parameter CLK_PERIOD = 10
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] lengths [N-1:0],
    input wire [3:0] valid_length,
    output reg [RESULT_WIDTH-1:0] area,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECK = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] DONE = 2'd3;

    reg [1:0] state, next_state;

    reg [2:0] i, j, k, l;
    reg [1:0] comb_type;
    reg [6:0] comb_count;

    reg [DATA_WIDTH-1:0] a, b, c, d;

    reg polygon_possible;
    reg [DATA_WIDTH:0] P;
    reg [DATA_WIDTH:0] max_side;

    reg [63:0] product;
    reg [63:0] sqrt_input;
    reg sqrt_start;
    wire sqrt_done;
    wire [31:0] sqrt_result;

    reg [31:0] max_area;

    sqrt_int sqrt_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(sqrt_start),
        .value_in(sqrt_input),
        .result(sqrt_result),
        .done(sqrt_done)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 0;
            j <= 0;
            k <= 0;
            l <= 0;
            comb_type <= 0;
            comb_count <= 0;
            max_area <= 0;
            done <= 0;
            sqrt_start <= 0;
            area <= 0;
            polygon_possible <= 0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = CHECK;
            CHECK: if (polygon_possible) next_state = COMPUTE; else next_state = CHECK;
            COMPUTE: if (sqrt_done) next_state = CHECK; else next_state = COMPUTE;
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i <= 0;
            j <= 0;
            k <= 0;
            l <= 0;
            comb_type <= 0;
            comb_count <= 0;
            max_area <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    i <= 0;
                    j <= 0;
                    k <= 0;
                    l <= 0;
                    comb_type <= 0;
                    comb_count <= 0;
                    max_area <= 0;
                    done <= 0;
                end

                CHECK: begin
                    if (comb_count >= 126) begin
                        next_state <= DONE;
                    end else begin
                        if (comb_type == 0) begin
                            if (i < valid_length && j < valid_length && k < valid_length && i < j && j < k) begin
                                a <= lengths[i];
                                b <= lengths[j];
                                c <= lengths[k];
                                if (a + b > c && a + c > b && b + c > a) begin
                                    polygon_possible <= 1;
                                end else begin
                                    polygon_possible <= 0;
                                    if (k < valid_length - 1) k <= k + 1;
                                    else if (j < valid_length - 2) begin
                                        j <= j + 1;
                                        k <= j + 2;
                                    end else if (i < valid_length - 3) begin
                                        i <= i + 1;
                                        j <= i + 2;
                                        k <= i + 3;
                                    end else begin
                                        comb_type <= 1;
                                        i <= 0;
                                        j <= 1;
                                        k <= 2;
                                        l <= 3;
                                    end
                                    comb_count <= comb_count + 1;
                                end
                            end else begin
                                if (k < valid_length - 1) k <= k + 1;
                                else if (j < valid_length - 2) begin
                                    j <= j + 1;
                                    k <= j + 2;
                                end else if (i < valid_length - 3) begin
                                    i <= i + 1;
                                    j <= i + 2;
                                    k <= i + 3;
                                end else begin
                                    comb_type <= 1;
                                    i <= 0;
                                    j <= 1;
                                    k <= 2;
                                    l <= 3;
                                end
                                comb_count <= comb_count + 1;
                            end
                        end else begin
                            if (i < valid_length && j < valid_length && k < valid_length && l < valid_length && i < j && j < k && k < l) begin
                                a <= lengths[i];
                                b <= lengths[j];
                                c <= lengths[k];
                                d <= lengths[l];
                                P = a + b + c + d;
                                max_side = max4(a, b, c, d);
                                if (max_side < P - max_side) begin
                                    polygon_possible <= 1;
                                end else begin
                                    polygon_possible <= 0;
                                    if (l < valid_length - 1) l <= l + 1;
                                    else if (k < valid_length - 2) begin
                                        k <= k + 1;
                                        l <= k + 2;
                                    end else if (j < valid_length - 3) begin
                                        j <= j + 1;
                                        k <= j + 2;
                                        l <= j + 3;
                                    end else if (i < valid_length - 4) begin
                                        i <= i + 1;
                                        j <= i + 2;
                                        k <= i + 3;
                                        l <= i + 4;
                                    end else begin
                                        next_state <= DONE;
                                    end
                                    comb_count <= comb_count + 1;
                                end
                            end else begin
                                if (l < valid_length - 1) l <= l + 1;
                                else if (k < valid_length - 2) begin
                                    k <= k + 1;
                                    l <= k + 2;
                                end else if (j < valid_length - 3) begin
                                    j <= j + 1;
                                    k <= j + 2;
                                    l <= j + 3;
                                end else if (i < valid_length - 4) begin
                                    i <= i + 1;
                                    j <= i + 2;
                                    k <= i + 3;
                                    l <= i + 4;
                                end else begin
                                    next_state <= DONE;
                                end
                                comb_count <= comb_count + 1;
                            end
                        end
                    end
                end

                COMPUTE: begin
                    if (polygon_possible && !sqrt_start) begin
                        if (comb_type == 0) begin
                            P = a + b + c;
                            product = P * (P - 2*a) * (P - 2*b) * (P - 2*c);
                        end else begin
                            P = a + b + c + d;
                            product = (P - 2*a) * (P - 2*b) * (P - 2*c) * (P - 2*d);
                        end
                        sqrt_input = product * 6250000;
                        sqrt_start <= 1;
                    end else if (sqrt_done) begin
                        sqrt_start <= 0;
                        if (sqrt_result > max_area) max_area <= sqrt_result;
                        polygon_possible <= 0;
                        if (comb_count >= 126) begin
                            next_state <= DONE;
                        end else begin
                            if (comb_type == 0) begin
                                if (k < valid_length - 1) k <= k + 1;
                                else if (j < valid_length - 2) begin
                                    j <= j + 1;
                                    k <= j + 2;
                                end else if (i < valid_length - 3) begin
                                    i <= i + 1;
                                    j <= i + 2;
                                    k <= i + 3;
                                end else begin
                                    comb_type <= 1;
                                    i <= 0;
                                    j <= 1;
                                    k <= 2;
                                    l <= 3;
                                end
                            end else begin
                                if (l < valid_length - 1) l <= l + 1;
                                else if (k < valid_length - 2) begin
                                    k <= k + 1;
                                    l <= k + 2;
                                end else if (j < valid_length - 3) begin
                                    j <= j + 1;
                                    k <= j + 2;
                                    l <= j + 3;
                                end else if (i < valid_length - 4) begin
                                    i <= i + 1;
                                    j <= i + 2;
                                    k <= i + 3;
                                    l <= i + 4;
                                end else begin
                                    next_state <= DONE;
                                end
                            end
                            comb_count <= comb_count + 1;
                        end
                    end
                end

                DONE: begin
                    area <= max_area;
                    done <= 1;
                end
            endcase
        end
    end

    function [DATA_WIDTH:0] max4;
        input [DATA_WIDTH:0] a, b, c, d;
        reg [DATA_WIDTH:0] m1, m2;
        begin
            m1 = (a > b) ? a : b;
            m2 = (c > d) ? c : d;
            max4 = (m1 > m2) ? m1 : m2;
        end
    endfunction

endmodule

module sqrt_int (
    input clk,
    input rst_n,
    input start,
    input [63:0] value_in,
    output reg [31:0] result,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE = 2'd2;

    reg [1:0] state, next_state;

    reg [31:0] remainder;
    reg [31:0] root;
    reg [1:0] bit_pos;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            remainder <= 0;
            root <= 0;
            bit_pos <= 0;
            result <= 0;
            done <= 0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = COMPUTE;
            COMPUTE: if (bit_pos == 32) next_state = DONE; else next_state = COMPUTE;
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            remainder <= 0;
            root <= 0;
            bit_pos <= 0;
            result <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    remainder <= 0;
                    root <= 0;
                    bit_pos <= 0;
                    result <= 0;
                    done <= 0;
                end

                COMPUTE: begin
                    if (bit_pos == 0) begin
                        remainder <= {value_in[63:32], 32'd0};
                        root <= 0;
                    end else begin
                        remainder <= {remainder[61:0], value_in[31 - bit_pos + 1:30 - bit_pos]};
                    end

                    if (bit_pos < 32) begin
                        reg [31:0] temp_remainder;
                        reg [31:0] temp_root;
                        temp_root = root << 1;
                        temp_remainder = remainder - {temp_root, 32'd0} - {temp_root + 1'b1, 31'd0};
                        if (temp_remainder[31]) begin
                            root <= temp_root + 1'b1;
                            remainder <= temp_remainder;
                        end else begin
                            root <= temp_root;
                            remainder <= remainder;
                        end
                        bit_pos <= bit_pos + 1;
                    end

                    if (bit_pos == 32) begin
                        result <= root;
                        done <= 1;
                    end
                end

                DONE: begin
                    result <= root;
                    done <= 1;
                end
            endcase
        end
    end

endmodule