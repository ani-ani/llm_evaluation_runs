module battery_allocator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] k,
    input wire [7:0] batteries [0:15],
    output reg [7:0] result,
    output reg done
);

    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COPY    = 3'd1;
    localparam [2:0] SORT    = 3'd2;
    localparam [2:0] COMPUTE = 3'd3;
    localparam [2:0] OUTPUT  = 3'd4;
    localparam [2:0] DONE    = 3'd5;

    reg [2:0] state, next_state;
    reg [7:0] mem [0:15];
    reg [3:0] copy_idx;
    reg [3:0] sort_outer, sort_inner;
    reg [3:0] compute_idx;
    reg [7:0] max_diff;
    reg [7:0] current_diff;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'd0;
            copy_idx <= 4'd0;
            sort_outer <= 4'd0;
            sort_inner <= 4'd0;
            compute_idx <= 4'd0;
            max_diff <= 8'd0;
            current_diff <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    next_state = COPY;
                    copy_idx = 4'd0;
                end
            end

            COPY: begin
                if (copy_idx < 16) begin
                    mem[copy_idx] = batteries[copy_idx];
                    if (copy_idx == 15) begin
                        next_state = SORT;
                        sort_outer = 4'd0;
                        sort_inner = 4'd0;
                    end else begin
                        copy_idx = copy_idx + 4'd1;
                    end
                end
            end

            SORT: begin
                if (sort_outer < 15) begin
                    if (sort_inner < 15 - sort_outer) begin
                        if (mem[sort_inner] > mem[sort_inner + 4'd1]) begin
                            mem[sort_inner] = mem[sort_inner + 4'd1];
                            mem[sort_inner + 4'd1] = mem[sort_inner];
                        end
                        sort_inner = sort_inner + 4'd1;
                    end else begin
                        sort_outer = sort_outer + 4'd1;
                        sort_inner = 4'd0;
                    end
                end else begin
                    next_state = COMPUTE;
                    compute_idx = 4'd0;
                    max_diff = 8'd0;
                end
            end

            COMPUTE: begin
                current_diff = mem[2 * compute_idx + 4'd1] - mem[2 * compute_idx];
                if (current_diff > max_diff) begin
                    max_diff = current_diff;
                end
                if (compute_idx < n - 4'd1) begin
                    compute_idx = compute_idx + 4'd1;
                end else begin
                    next_state = OUTPUT;
                end
            end

            OUTPUT: begin
                result = max_diff;
                done = 1'b1;
                next_state = DONE;
            end

            DONE: begin
                if (start) begin
                    next_state = COPY;
                    copy_idx = 4'd0;
                end
            end

            default: next_state = IDLE;
        endcase
    end

endmodule