module string_equivalence (
    input clk,
    input rst_n,
    input start,
    input [127:0] string_a,
    input [127:0] string_b,
    output reg equivalent,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        INIT,
        PROCESS,
        NEXT_PASS,
        COMPARE,
        DONE
    } state_t;

    // Internal registers
    reg [127:0] reg_a;
    reg [127:0] reg_b;
    reg [3:0] block_size;
    reg [3:0] chunk_idx;
    reg [3:0] pass_count;
    state_t state, next_state;

    // Default assignments
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            equivalent <= 0;
            done <= 0;
            block_size <= 0;
            chunk_idx <= 0;
            pass_count <= 0;
            reg_a <= 0;
            reg_b <= 0;
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = INIT;
            end
            INIT: begin
                next_state = PROCESS;
            end
            PROCESS: begin
                if (chunk_idx == 8 - 1) begin
                    next_state = NEXT_PASS;
                end
            end
            NEXT_PASS: begin
                if (block_size == 8) begin
                    next_state = COMPARE;
                end else begin
                    next_state = PROCESS;
                end
            end
            COMPARE: begin
                next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_a <= 0;
            reg_b <= 0;
        end else begin
            case (state)
                INIT: begin
                    reg_a <= string_a;
                    reg_b <= string_b;
                    block_size <= 1;
                    chunk_idx <= 0;
                    pass_count <= 0;
                    done <= 0;
                end
                PROCESS: begin
                    // Process current chunk
                    if (chunk_idx < 8) begin
                        // Compare and swap logic
                        reg [7:0] left_a = reg_a[(chunk_idx * 16 + 7):(chunk_idx * 16)];
                        reg [7:0] right_a = reg_a[(chunk_idx * 16 + 8 + 7):(chunk_idx * 16 + 8)];
                        reg [7:0] left_b = reg_b[(chunk_idx * 16 + 7):(chunk_idx * 16)];
                        reg [7:0] right_b = reg_b[(chunk_idx * 16 + 8 + 7):(chunk_idx * 16 + 8)];

                        if (left_a > right_a) begin
                            reg_a[(chunk_idx * 16 + 7):(chunk_idx * 16)] <= right_a;
                            reg_a[(chunk_idx * 16 + 8 + 7):(chunk_idx * 16 + 8)] <= left_a;
                        end
                        if (left_b > right_b) begin
                            reg_b[(chunk_idx * 16 + 7):(chunk_idx * 16)] <= right_b;
                            reg_b[(chunk_idx * 16 + 8 + 7):(chunk_idx * 16 + 8)] <= left_b;
                        end
                        chunk_idx <= chunk_idx + 1;
                    end
                end
                NEXT_PASS: begin
                    block_size <= block_size << 1;
                    chunk_idx <= 0;
                    pass_count <= pass_count + 1;
                end
                COMPARE: begin
                    equivalent <= (reg_a == reg_b);
                end
                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

endmodule