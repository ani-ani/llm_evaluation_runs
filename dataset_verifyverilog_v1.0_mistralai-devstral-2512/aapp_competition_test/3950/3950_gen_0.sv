module array_range_validator(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:15],
    input [4:0] n,
    input [7:0] q,
    output reg result_valid,
    output reg is_possible,
    output reg [7:0] restored_arr [0:15]
);

    // State declarations
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] SCAN_INPUT    = 4'd1;
    localparam [3:0] CHECK_CONDITION = 4'd2;
    localparam [3:0] UPDATE_STACK  = 4'd3;
    localparam [3:0] POP_STACK     = 4'd4;
    localparam [3:0] FINALIZE      = 4'd5;
    localparam [3:0] DONE          = 4'd6;
    localparam [3:0] ERROR         = 4'd7;

    // Registers
    reg [3:0] state;
    reg [4:0] index;
    reg [7:0] current_max;
    reg [7:0] max_val;
    reg [7:0] stack [0:7];
    reg [2:0] stack_ptr;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 5'd0;
            current_max <= 8'd0;
            max_val <= 8'd0;
            result_valid <= 1'b0;
            is_possible <= 1'b0;
            cycle_count <= 8'd0;
            stack_ptr <= 3'd0;
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                restored_arr[i] <= 8'd0;
            end
            for (i = 0; i < 8; i = i + 1) begin
                stack[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    is_possible <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= SCAN_INPUT;
                        index <= 5'd0;
                        current_max <= 8'd0;
                        max_val <= 8'd0;
                        stack_ptr <= 3'd0;
                    end
                end

                SCAN_INPUT: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (index < n) begin
                        state <= CHECK_CONDITION;
                    end else begin
                        state <= FINALIZE;
                    end
                end

                CHECK_CONDITION: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (arr[index] == 8'd0) begin
                        restored_arr[index] <= current_max > 8'd0 ? current_max : 8'd1;
                        state <= SCAN_INPUT;
                        index <= index + 5'd1;
                    end else if (arr[index] > current_max) begin
                        state <= UPDATE_STACK;
                    end else if (arr[index] == current_max) begin
                        state <= POP_STACK;
                    end else begin
                        state <= ERROR;
                    end
                end

                UPDATE_STACK: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (stack_ptr < 8'd7) begin
                        stack[stack_ptr] <= current_max;
                        stack_ptr <= stack_ptr + 3'd1;
                        current_max <= arr[index];
                        restored_arr[index] <= arr[index];
                        if (arr[index] > max_val) begin
                            max_val <= arr[index];
                        end
                        state <= SCAN_INPUT;
                        index <= index + 5'd1;
                    end else begin
                        state <= ERROR;
                    end
                end

                POP_STACK: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (stack_ptr > 3'd0) begin
                        stack_ptr <= stack_ptr - 3'd1;
                        current_max <= stack[stack_ptr];
                    end
                    restored_arr[index] <= arr[index];
                    state <= SCAN_INPUT;
                    index <= index + 5'd1;
                end

                FINALIZE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (q >= max_val && (q == max_val || (q > max_val && current_max == 8'd0))) begin
                        is_possible <= 1'b1;
                    end else begin
                        is_possible <= 1'b0;
                    end
                    state <= DONE;
                end

                DONE: begin
                    result_valid <= 1'b1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= IDLE;
                    end
                end

                ERROR: begin
                    is_possible <= 1'b0;
                    result_valid <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule