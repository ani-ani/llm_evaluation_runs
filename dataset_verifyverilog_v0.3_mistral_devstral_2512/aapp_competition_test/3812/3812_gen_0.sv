module StringProcessor(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] s_len,
    input wire [3:0] t_len,
    input wire [15:0] s_data,
    input wire [15:0] t_data,
    output reg done,
    output reg [3:0] op_count,
    output reg [15:0] operations
);

    // State declarations
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] SCAN     = 2'd1;
    localparam [1:0] SWAP     = 2'd2;
    localparam [1:0] COMPLETE = 2'd3;

    reg [1:0] state, next_state;
    reg [3:0] s_ptr, t_ptr;
    reg [3:0] op_index;
    reg [1:0] current_op;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            s_ptr <= 4'd0;
            t_ptr <= 4'd0;
            op_index <= 4'd0;
            current_op <= 2'd0;
            op_count <= 4'd0;
            operations <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    s_ptr = 4'd0;
                    t_ptr = 4'd0;
                    op_index = 4'd0;
                    op_count = 4'd0;
                    operations = 16'd0;
                    next_state = SCAN;
                end
            end

            SCAN: begin
                if (s_ptr < s_len && t_ptr < t_len) begin
                    if (s_data[s_ptr] != t_data[t_ptr]) begin
                        current_op = {s_data[s_ptr], t_data[t_ptr]};
                        next_state = SWAP;
                    end else begin
                        s_ptr = s_ptr + 4'd1;
                        t_ptr = t_ptr + 4'd1;
                    end
                end else begin
                    next_state = COMPLETE;
                end
            end

            SWAP: begin
                operations[op_index*2 +: 2] = current_op;
                op_index = op_index + 4'd1;
                op_count = op_index;
                s_ptr = s_ptr + 4'd1;
                t_ptr = t_ptr + 4'd1;
                next_state = SCAN;
            end

            COMPLETE: begin
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Prevent infinite loops
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES) begin
            state <= IDLE;
            done <= 1'b1;
        end
    end

endmodule