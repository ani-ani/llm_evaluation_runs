module swap_generator (
    input clk,
    input rst_n,
    input start,
    input [9:0] n,
    output reg valid,
    output reg [9:0] a_out,
    output reg [9:0] b_out,
    output reg out_valid,
    output reg done
);

    typedef enum logic [2:0] {
        IDLE,
        CHECK,
        BLOCK,
        CROSS,
        DONE
    } state_t;

    state_t state = IDLE;
    reg [9:0] block_start = 0;
    reg [1:0] swap_index = 0;
    reg [9:0] swap_count = 0;
    reg [9:0] total_swaps = 0;
    reg [9:0] block_size = 4;
    reg [9:0] k = 0;
    reg [9:0] temp_a, temp_b;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 0;
            a_out <= 0;
            b_out <= 0;
            out_valid <= 0;
            done <= 0;
            block_start <= 0;
            swap_index <= 0;
            swap_count <= 0;
            total_swaps <= 0;
            k <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= CHECK;
                    end
                end
                CHECK: begin
                    if (n % 4 == 0 || n % 4 == 1) begin
                        valid <= 1;
                        total_swaps <= n * (n - 1) / 2;
                        state <= BLOCK;
                        block_start <= 0;
                        swap_index <= 0;
                        swap_count <= 0;
                    end else begin
                        valid <= 0;
                        done <= 1;
                        state <= IDLE;
                    end
                end
                BLOCK: begin
                    if (swap_index < 6) begin
                        case (swap_index)
                            0: begin temp_a = block_start; temp_b = block_start + 2; end
                            1: begin temp_a = block_start + 1; temp_b = block_start + 3; end
                            2: begin temp_a = block_start; temp_b = block_start + 1; end
                            3: begin temp_a = block_start + 2; temp_b = block_start + 3; end
                            4: begin temp_a = block_start; temp_b = block_start + 3; end
                            5: begin temp_a = block_start + 1; temp_b = block_start + 2; end
                        endcase
                        a_out <= temp_a;
                        b_out <= temp_b;
                        out_valid <= 1;
                        swap_index <= swap_index + 1;
                        swap_count <= swap_count + 1;
                    end else begin
                        out_valid <= 0;
                        if (n % 4 == 1 && block_start < n - 4) begin
                            state <= CROSS;
                            k <= block_start;
                            swap_index <= 0;
                        end else if (block_start + 4 < n) begin
                            block_start <= block_start + 4;
                            swap_index <= 0;
                        end else begin
                            state <= DONE;
                            done <= 1;
                        end
                    end
                end
                CROSS: begin
                    if (swap_index < 4) begin
                        case (swap_index)
                            0: begin temp_a = 0; temp_b = k; end
                            1: begin temp_a = 0; temp_b = k + 1; end
                            2: begin temp_a = 0; temp_b = k + 2; end
                            3: begin temp_a = 0; temp_b = k + 3; end
                        endcase
                        a_out <= temp_a;
                        b_out <= temp_b;
                        out_valid <= 1;
                        swap_index <= swap_index + 1;
                        swap_count <= swap_count + 1;
                    end else begin
                        out_valid <= 0;
                        if (k + 4 < n - 1) begin
                            block_start <= block_start + 4;
                            swap_index <= 0;
                            state <= BLOCK;
                        end else begin
                            state <= DONE;
                            done <= 1;
                        end
                    end
                end
                DONE: begin
                    if (swap_count == total_swaps) begin
                        done <= 1;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule